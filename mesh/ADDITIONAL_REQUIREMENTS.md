
## 10. Ollama (Local LLM — $0 UNLIMITED)

### Status
- Ollama v0.18.3 running at localhost:11434
- Installed models: llama3.1:8b (4.9GB), nomic-embed-text (274MB)
- OpenAI-compatible API at http://localhost:11434/v1
- Already configured in OpenClaw as provider "ollama"

### Config needed: mesh/config/ollama.yaml
- Models: llama3.1:8b (currently), can pull more
- Cost: $0 (local, unlimited)
- Context: 131K tokens
- Speed: depends on hardware (Mac Apple Silicon)
- Capabilities: text generation, embeddings, code
- Limitations: no web search, no tools, quality < cloud models

### Routing rules for Ollama
Ollama should be HIGHEST priority for:
1. **Embeddings** — nomic-embed-text is free and fast (already used by intelligence pipeline)
2. **Simple text tasks** — summaries, rewrites, classifications
3. **Privacy-sensitive tasks** — data never leaves the machine
4. **Bulk/batch operations** — no rate limits, no cost
5. **Testing/prototyping** — iterate fast without burning tokens

Ollama should NOT be used for:
- Complex reasoning (use Codex/Claude Code instead)
- Web research (use Perplexity)
- Code generation (use Claude Code/Gemini/Codex)
- Tasks requiring >8B model quality

### Updated full priority order (10 systems):
$0 tier:
1. Claude Code CLI (subscription)
2. Codex CLI (subscription)
3. Gemini CLI (free tier, 500/day)
4. Perplexity browser (free, unlimited)
5. **Ollama (local, unlimited, $0)**
6. OpenRouter free models

Cheap tier:
7. Grok API
8. Gemini API
9. Perplexity MCP via CC/Codex

Expensive tier:
10. OpenAI API
11. Anthropic API
12. Perplexity API direct
13. o3-pro / o1-pro
