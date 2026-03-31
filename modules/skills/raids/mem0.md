# Repo Raid: mem0ai/mem0
- **URL**: https://github.com/mem0ai/mem0
- **Stars**: ~51,575
- **Language**: Python
- **Last updated**: 2026-03-31

## Architecture Overview

mem0 is a memory layer for LLM applications. It provides a dual-storage architecture: a **vector store** for semantic memory (embeddings-based retrieval) and an optional **graph store** (Neo4j/Apache AGE/Kuzu/Memgraph) for relational/entity memory. A **SQLite history database** tracks all mutations (add/update/delete) for full auditability. The core design is:

1. **Conversations go in** -- the LLM extracts discrete facts from messages
2. **Facts are deduplicated** -- existing memories are searched by embedding similarity, and an LLM decides whether to ADD, UPDATE, DELETE, or NONE for each fact
3. **Memories are stored** -- as vectors with rich metadata payloads (user_id, agent_id, run_id, actor_id, role, timestamps, content hash)
4. **Graph entities extracted in parallel** -- entities and relationships are extracted via tool-calling LLMs and stored in a knowledge graph
5. **Retrieval combines both** -- vector similarity search + optional BM25 reranking over graph triples

The system supports three memory types via an enum: `SEMANTIC`, `EPISODIC`, and `PROCEDURAL` -- though the primary implementation focuses on semantic (factual) memories, with procedural memory as a specialized summarization flow for agent execution histories.

## Key Patterns Found

### Pattern 1: LLM-as-Memory-Manager (Two-Phase Extraction)

The most important architectural pattern. Memory creation is a **two-LLM-call pipeline**:

**Phase 1 -- Fact Extraction**: An LLM extracts discrete facts from conversation messages as a JSON array.

```python
# From mem0/memory/main.py lines 498-530
system_prompt, user_prompt = get_fact_retrieval_messages(parsed_messages, is_agent_memory)
response = self.llm.generate_response(
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ],
    response_format={"type": "json_object"},
)
new_retrieved_facts = json.loads(cleaned_response, strict=False)["facts"]
```

The extraction prompt (from `configs/prompts.py`) classifies 7 information types: personal preferences, personal details, plans/intentions, activity preferences, health/wellness, professional details, and miscellaneous. It uses few-shot examples to demonstrate the expected output format.

There are separate prompts for **user memory extraction** (facts from user messages only) vs **agent memory extraction** (facts about the assistant from assistant messages). The system auto-selects based on whether `agent_id` is present and assistant messages exist.

**Phase 2 -- Memory Reconciliation**: For each extracted fact, existing memories are searched by embedding similarity (top 5). Then a second LLM call decides what to do:

```python
# From configs/prompts.py -- the UPDATE_MEMORY_PROMPT
# The LLM receives:
# 1. All existing similar memories (with integer IDs to prevent UUID hallucination)
# 2. All newly extracted facts
# And returns a JSON with actions: ADD, UPDATE, DELETE, or NONE for each
function_calling_prompt = get_update_memory_messages(
    retrieved_old_memory, new_retrieved_facts, self.config.custom_update_memory_prompt
)
```

**Key insight**: Integer ID mapping prevents UUID hallucination -- real UUIDs are mapped to simple integers (0, 1, 2...) before sending to the LLM, then mapped back after.

```python
# Lines 568-571
temp_uuid_mapping = {}
for idx, item in enumerate(retrieved_old_memory):
    temp_uuid_mapping[str(idx)] = item["id"]
    retrieved_old_memory[idx]["id"] = str(idx)
```

### Pattern 2: Vector + Graph Dual Storage with Parallel Execution

All major operations (add, search, get_all) execute vector store and graph store operations **in parallel** using `concurrent.futures.ThreadPoolExecutor`:

```python
# From mem0/memory/main.py lines 441-448
with concurrent.futures.ThreadPoolExecutor() as executor:
    future1 = executor.submit(self._add_to_vector_store, messages, processed_metadata, effective_filters, infer)
    future2 = executor.submit(self._add_to_graph, messages, effective_filters)
    concurrent.futures.wait([future1, future2])
    vector_store_result = future1.result()
    graph_result = future2.result()
```

The graph store (Neo4j-backed `MemoryGraph`) uses:
- **Entity extraction** via LLM tool-calling (extract_entities tool)
- **Relationship extraction** via a second LLM tool call (establish_relationships tool)
- **Cosine similarity search** on node embeddings stored directly in Neo4j
- **Soft deletion** of relationships (marking `r.valid = false` rather than removing)
- **BM25 reranking** over graph search results for final ranking

```python
# From graph_memory.py -- graph search with cosine similarity
cypher_query = f"""
MATCH (n {self.node_label} {{{node_props_str}}})
WHERE n.embedding IS NOT NULL
WITH n, round(2 * vector.similarity.cosine(n.embedding, $n_embedding) - 1, 4) AS similarity
WHERE similarity >= $threshold
...
"""
```

### Pattern 3: Content-Addressed Memory with Hash Deduplication

Each memory stores an MD5 hash of its content for change detection:

```python
# From mem0/memory/main.py lines 1201-1205
new_metadata["data"] = data
new_metadata["hash"] = hashlib.md5(data.encode()).hexdigest()
if "created_at" not in new_metadata:
    new_metadata["created_at"] = datetime.now(timezone.utc).isoformat()
new_metadata["updated_at"] = new_metadata["created_at"]
```

The vector store payload structure for each memory:
```
{
    "data": "User likes playing tennis on weekends",
    "hash": "a1b2c3...",  # MD5 of data
    "user_id": "user_123",
    "agent_id": "agent_456",  # optional
    "run_id": "run_789",      # optional
    "actor_id": "john",       # optional, from message "name" field
    "role": "user",           # message role
    "created_at": "2026-03-31T12:00:00+00:00",
    "updated_at": "2026-03-31T12:00:00+00:00"
}
```

### Pattern 4: Full Mutation History via SQLite

Every memory operation is recorded in a SQLite history table, creating a complete audit trail:

```python
# From storage.py -- history table schema
"""
CREATE TABLE IF NOT EXISTS history (
    id           TEXT PRIMARY KEY,   -- UUID for the history entry
    memory_id    TEXT,               -- UUID of the memory
    old_memory   TEXT,               -- previous content (NULL for ADD)
    new_memory   TEXT,               -- new content (NULL for DELETE)
    event        TEXT,               -- ADD, UPDATE, DELETE
    created_at   DATETIME,
    updated_at   DATETIME,
    is_deleted   INTEGER,            -- soft delete flag
    actor_id     TEXT,
    role         TEXT
)
"""
```

This enables `memory.history(memory_id)` to return the full change log for any memory. The history is ordered by `created_at ASC, updated_at ASC`.

### Pattern 5: Multi-Tenant Session Scoping

All operations are scoped by a combination of `user_id`, `agent_id`, and `run_id`. At least one must be provided. These act as mandatory metadata filters:

```python
# From mem0/memory/main.py lines 159-237
def _build_filters_and_metadata(*, user_id, agent_id, run_id, actor_id, input_metadata, input_filters):
    # Constructs two dicts:
    # 1. base_metadata_template -- for storage
    # 2. effective_query_filters -- for retrieval
    # Both include all provided session IDs
    if not session_ids_provided:
        raise Mem0ValidationError("At least one of 'user_id', 'agent_id', or 'run_id' must be provided.")
```

The Qdrant implementation creates payload indexes on these fields for efficient filtering:
```python
common_fields = ["user_id", "agent_id", "run_id", "actor_id"]
for field in common_fields:
    self.client.create_payload_index(
        collection_name=self.collection_name,
        field_name=field,
        field_schema="keyword"
    )
```

### Pattern 6: Pluggable Everything via Factory Pattern

Every major component uses a factory with provider mappings:

| Component | Default | Alternatives |
|-----------|---------|-------------|
| **Vector Store** | Qdrant | Pinecone, Chroma, PGVector, Milvus, MongoDB, Redis, FAISS, Elasticsearch, Weaviate, Supabase, OpenSearch, S3, Turbopuffer + 10 more |
| **Embeddings** | OpenAI (`text-embedding-3-small`, 1536d) | Ollama, HuggingFace, Azure OpenAI, Gemini, VertexAI, Together, LMStudio, AWS Bedrock, FastEmbed |
| **LLM** | OpenAI | Anthropic, Groq, Together, AWS Bedrock, Azure OpenAI, Gemini, DeepSeek, Ollama, LiteLLM, vLLM, xAI, Sarvam, MiniMax, LMStudio |
| **Graph Store** | Neo4j | Apache AGE, Kuzu, Memgraph |
| **Reranker** | None (optional) | Cohere, HuggingFace, SentenceTransformer, LLM-based, ZeroEntropy |

### Pattern 7: Enhanced Metadata Filtering

The search API supports rich filter operators beyond simple equality:

```python
# Supported filter operators
filters = {
    "key": "value",                    # exact match
    "key": {"eq": "value"},            # equals
    "key": {"ne": "value"},            # not equals
    "key": {"in": ["val1", "val2"]},   # in list
    "key": {"nin": ["val1", "val2"]},  # not in list
    "key": {"gt": 10},                 # greater than
    "key": {"gte": 10},               # greater than or equal
    "key": {"lt": 10},                # less than
    "key": {"lte": 10},               # less than or equal
    "key": {"contains": "text"},       # text contains
    "key": {"icontains": "text"},      # case-insensitive contains
    "key": "*",                        # wildcard (any value)
    "AND": [filter1, filter2],         # logical AND
    "OR": [filter1, filter2],          # logical OR
    "NOT": [filter1],                  # logical NOT
}
```

These are translated to each vector store's native filter format (e.g., Qdrant's `FieldCondition`, `Filter`, `Range`).

### Pattern 8: Optional Reranking Pipeline

Search results can be reranked after initial vector retrieval:

```python
# From mem0/memory/main.py lines 937-943
if rerank and self.reranker and original_memories:
    try:
        reranked_memories = self.reranker.rerank(query, original_memories, limit)
        original_memories = reranked_memories
    except Exception as e:
        logger.warning(f"Reranking failed, using original results: {e}")
```

Five reranker implementations: Cohere API, HuggingFace models, SentenceTransformers, LLM-based (using the configured LLM), and ZeroEntropy.

### Pattern 9: Embedding Caching Within Operations

Embeddings are cached in a dict during the add operation to avoid redundant API calls when the same text appears in both fact extraction and memory creation:

```python
# Lines 549-551
new_message_embeddings = {}
for new_mem in new_retrieved_facts:
    messages_embeddings = self.embedding_model.embed(new_mem, "add")
    new_message_embeddings[new_mem] = messages_embeddings
```

The cache dict is passed through `_create_memory` and `_update_memory` so embeddings are reused rather than recomputed.

### Pattern 10: Procedural Memory for Agent Workflows

A specialized memory type for recording agent execution histories as structured summaries:

```python
# The procedural memory system prompt instructs the LLM to produce:
# - Task Objective
# - Progress Status (completion %)
# - Sequential numbered steps with:
#   - Agent Action (what was done)
#   - Action Result (verbatim output)
#   - Key Findings, Navigation History, Errors, Current Context
```

This is triggered when `agent_id` is provided and `memory_type="procedural_memory"`. The LLM summarizes the conversation into a structured execution log that is stored as a single memory entry.

### Pattern 11: Proxy/Drop-in Replacement for OpenAI

The `Mem0` proxy class wraps LiteLLM to provide a drop-in replacement for OpenAI's chat completions API with automatic memory injection:

```python
# From proxy/main.py
class Mem0:
    def __init__(self, config=None, api_key=None, host=None):
        if api_key:
            self.mem0_client = MemoryClient(api_key, host)
        else:
            self.mem0_client = Memory.from_config(config) if config else Memory()
        self.chat = Chat(self.mem0_client)

# Usage: client = Mem0(); client.chat.completions.create(model="gpt-4", messages=[...], user_id="u1")
```

This searches for relevant memories, injects them as system context, calls the LLM, and stores the conversation as new memories -- all in one API call.

## What mem0 Does NOT Do

- **No memory decay/TTL**: Memories persist indefinitely. No aging, relevance decay, or automatic pruning.
- **No memory importance scoring**: All memories are treated equally. No priority/weight system.
- **No cross-user memory sharing**: Memories are strictly scoped to session IDs.
- **No batch operations**: Each memory is processed individually (no bulk embedding or bulk insert).
- **No streaming memory**: The add operation is synchronous (waits for both LLM calls to complete).
- **No conflict resolution beyond LLM judgment**: The UPDATE/DELETE decisions are entirely LLM-driven with no deterministic fallback.

## Actionable Takeaways for AI Agent Mesh

1. **Adopt the two-phase LLM extraction pattern**: The fact-extraction-then-reconciliation pipeline is the core innovation. Phase 1 extracts atomic facts; Phase 2 decides ADD/UPDATE/DELETE against existing memories. This prevents duplicate accumulation and keeps memory clean.

2. **Use integer ID mapping for LLM memory operations**: When asking an LLM to reference existing items by ID, map UUIDs to simple integers first. This prevents hallucinated IDs and makes the LLM's job easier.

3. **Implement dual storage (vector + graph)**: Vector similarity alone misses relational structure. The graph store captures entity relationships (e.g., "Alice works_at Acme") that vector search cannot represent. Running both in parallel with ThreadPoolExecutor is efficient.

4. **SQLite history table is cheap and powerful**: Full mutation tracking with old_value/new_value/event/timestamp costs almost nothing but enables debugging, rollback, and audit trails. The schema is minimal and battle-tested.

5. **Content hashing for deduplication**: MD5 hashing of memory content is a simple way to detect duplicates and track changes without expensive embedding comparisons.

6. **Session scoping as mandatory metadata**: Requiring at least one of user_id/agent_id/run_id prevents accidental cross-contamination. These should be indexed as keyword fields in the vector store.

7. **Custom prompt injection points**: mem0 exposes `custom_fact_extraction_prompt` and `custom_update_memory_prompt` for domain-specific tuning. This is a good pattern -- provide sensible defaults but allow override.

8. **Separate user vs agent memory extraction**: Different prompts for extracting facts about the user (from user messages) vs facts about the assistant (from assistant messages). The mesh should distinguish memory ownership similarly.

9. **Reranking as optional post-processing**: Vector similarity is a coarse first pass. Optional reranking (Cohere, cross-encoder, LLM-based) improves precision significantly. The graceful fallback on reranker failure is good defensive design.

10. **Consider adding what mem0 lacks**: Memory decay/TTL, importance scoring, and cross-entity memory sharing are gaps that a mesh memory system could exploit as differentiators. A time-weighted relevance score combining recency + access frequency + embedding similarity would outperform mem0's flat model.

11. **The proxy pattern is powerful for adoption**: Wrapping the memory layer as a drop-in replacement for the LLM API (same interface, automatic memory injection) lowers adoption friction to near zero. The mesh should offer a similar pass-through interface.

12. **Embedding caching within operations**: Pass a dict of `{text: embedding}` through the pipeline to avoid redundant embedding API calls during a single add operation. Simple but eliminates wasted tokens.
