---
name: document-extraction
description: Extract text, tables, and metadata from PDFs, DOCX, XLSX, images, and 60+ formats
read_when: "user wants to extract text from a document, parse a PDF, read a DOCX, extract tables, or OCR an image"
---

# Document Extraction

Extract text, tables, and metadata from documents in 60+ formats.

## By Format

### PDF
```bash
# Using pdftotext (poppler)
brew install poppler
pdftotext input.pdf output.txt
pdftotext -layout input.pdf output.txt  # Preserve layout

# Extract specific pages
pdftotext -f 3 -l 5 input.pdf output.txt

# Using Python
pip install PyPDF2 pdfplumber
```

```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    for page in pdf.pages:
        print(page.extract_text())
        tables = page.extract_tables()
        for table in tables:
            print(table)  # List of lists
```

### DOCX
```python
pip install python-docx
from docx import Document
doc = Document("file.docx")
for para in doc.paragraphs:
    print(para.text)
for table in doc.tables:
    for row in table.rows:
        print([cell.text for cell in row.cells])
```

### XLSX / CSV
```python
import openpyxl
wb = openpyxl.load_workbook("file.xlsx")
for sheet in wb.sheetnames:
    ws = wb[sheet]
    for row in ws.iter_rows(values_only=True):
        print(row)
```

Or use DuckDB (see duckdb-query skill):
```bash
duckdb -c "SELECT * FROM read_xlsx('file.xlsx')"
```

### Images (OCR)
```bash
# Tesseract OCR
brew install tesseract
tesseract image.png output -l eng

# For better results on complex layouts
tesseract image.png output --oem 1 --psm 6
```

### HTML
```bash
# Convert HTML to clean text
pip install trafilatura
trafilatura --input-file page.html
```

### Email (.eml, .msg)
```python
import email
with open("message.eml") as f:
    msg = email.message_from_file(f)
    print(msg["subject"], msg["from"])
    for part in msg.walk():
        if part.get_content_type() == "text/plain":
            print(part.get_payload(decode=True).decode())
```

## Universal Approach (kreuzberg)
```bash
pip install kreuzberg
```
```python
import kreuzberg
result = kreuzberg.extract("any-file.pdf")  # Works with 62+ formats
print(result.content)  # Extracted text
print(result.metadata)  # Document metadata
```

## Tips
- For scanned PDFs, always use OCR (Tesseract or cloud APIs)
- For tables, pdfplumber and Camelot give better results than raw text extraction
- For large batches, use async processing with a queue
- Validate extraction quality by spot-checking against original
