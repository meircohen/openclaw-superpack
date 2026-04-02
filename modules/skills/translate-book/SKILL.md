---
name: translate-book
description: Translate books and long documents via parallel sub-agents with resume capability
read_when: "user wants to translate a book, long document, PDF, DOCX, or EPUB into another language"
---

# Book Translation

Translate books and long documents (PDF, DOCX, EPUB) using parallel sub-agents with resume support.

## Strategy

### 1. Prepare the Source
```bash
# Extract text from PDF
pdftotext -layout source.pdf source.txt

# Or from EPUB
# pip install ebooklib beautifulsoup4
python3 -c "
import ebooklib
from ebooklib import epub
from bs4 import BeautifulSoup

book = epub.read_epub('source.epub')
for item in book.get_items_of_type(ebooklib.ITEM_DOCUMENT):
    soup = BeautifulSoup(item.get_body_content(), 'html.parser')
    print(soup.get_text())
" > source.txt
```

### 2. Chunk the Document
Split into translation-sized chunks (1000-2000 words each):
- Respect paragraph boundaries
- Keep chapter context together
- Number each chunk for tracking

```python
import re
text = open("source.txt").read()
chunks = re.split(r'\n\n+', text)
# Group into ~1500 word blocks
blocks = []
current = []
word_count = 0
for chunk in chunks:
    words = len(chunk.split())
    if word_count + words > 1500 and current:
        blocks.append('\n\n'.join(current))
        current = [chunk]
        word_count = words
    else:
        current.append(chunk)
        word_count += words
if current:
    blocks.append('\n\n'.join(current))
```

### 3. Translation Prompt Per Chunk

```
Translate the following text from [SOURCE_LANG] to [TARGET_LANG].

Rules:
- Preserve paragraph structure and formatting
- Maintain the author's voice and tone
- Translate idioms to equivalent expressions (don't translate literally)
- Keep proper nouns in original form unless there's a standard translation
- Preserve any technical terms with the translation in parentheses on first use
- Do not add, remove, or summarize content

Glossary (consistent terms):
[term1] -> [translation1]
[term2] -> [translation2]

Context: This is chunk [N] of [TOTAL] from chapter [X], "[Chapter Title]".
Previous chunk ended with: "[last 2 sentences of previous chunk]"

Text to translate:
---
[CHUNK CONTENT]
---
```

### 4. Parallel Execution
- Dispatch 3-5 sub-agents simultaneously
- Each agent translates a chunk
- Track completion in a manifest file

### 5. Resume Support
```
translation_manifest.json:
{
  "source": "source.txt",
  "target_lang": "Hebrew",
  "total_chunks": 45,
  "completed": [1,2,3,5,6,7],
  "pending": [4,8,9,...,45],
  "glossary": {"term": "translation"}
}
```

### 6. Quality Review
After all chunks translated:
- Check consistency of key terms across chapters
- Verify no chunks were skipped
- Review chapter transitions for flow
- Spot-check 10% against source

### 7. Assemble Output
Concatenate translated chunks in order, preserving chapter structure.
Export to desired format (DOCX, PDF, EPUB).
