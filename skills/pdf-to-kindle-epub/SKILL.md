---
name: pdf-to-kindle-epub
description: >-
  Convert a book PDF into a properly reflowable EPUB for Kindle or any
  e-reader, with real paragraphs, a working table of contents, and adjustable
  font size. Use this whenever someone wants to read a PDF book on a Kindle,
  e-reader, Kobo, or phone; asks to convert a PDF to EPUB or MOBI; asks to
  "send this book to my Kindle"; complains that a converted book has broken
  line breaks, a stray word on its own line, text that won't reflow, fonts
  that can't be resized, a missing or wrong table of contents, or a file too
  large to email; or asks to shrink an ebook under an attachment limit. Also
  use it proactively when someone mentions reading a long PDF on a device with
  a small screen, since a raw PDF is close to unreadable there. Do NOT use it
  for filling forms, extracting tables as data, or reading a PDF's contents to
  answer a question.
---

# PDF to Kindle-ready EPUB

## Why the obvious approach fails

`ebook-convert book.pdf book.epub` looks like it works and does not. Neither
does `pdftohtml` into calibre. Both emit **one block per visual line of the
PDF**, and an e-reader renders each block as its own paragraph. The reader gets
text shattered mid-sentence:

```
É possível melhorar
isso, dar uma pequena
a
melhora foi tão grande
```

This is a markup problem, not a text problem, so cleaning up the text afterward
cannot fix it. The line structure has to be discarded and paragraphs rebuilt
from the page geometry. That is what `scripts/pdf2epub.py` does, using
`pdftohtml -xml`, which reports each line's position, width, font size and font
family.

Read `references/troubleshooting.md` when a conversion comes out wrong — it
lists each failure mode, what it looks like to a reader, and which knob fixes
it.

## Requirements

Needs `pdftohtml`, `pdftoppm`, `pdftotext` (poppler), `ebook-convert` (calibre),
and ideally `magick` (ImageMagick, for shrinking images). The script names what
is missing and how to install it. On NixOS nothing needs installing — wrap the
call:

```bash
nix shell nixpkgs#poppler-utils nixpkgs#calibre nixpkgs#imagemagick -c \
  python3 scripts/pdf2epub.py ...
```

## Workflow

### 1. Analyze first — always

```bash
python3 scripts/pdf2epub.py analyze "book.pdf" --work /tmp/bookbuild
```

This is not optional ceremony. Every book sets its structure in different font
sizes, and the report is how you learn this book's. It prints the font-size
histogram, which sizes form headings and how often, the actual heading text it
would produce, a breakdown of small type, and two reconstructed paragraphs.

**Read the sample paragraphs.** If they read as continuous prose, the
reconstruction is working and the rest is tuning. If they are chopped up, stop
and fix that first — nothing else matters.

### 2. Decide the structure

The report ends with a suggested `--h1-sizes` / `--h2-sizes`. Treat it as a
starting guess, not an answer, and check it against the heading list above it.

- **Parts and chapters** are usually the two largest sizes used only a handful
  of times. Those are your h1 and h2.
- **Front and back matter** (a preface, an index) often sit at a *smaller* size
  than the part numerals but still belong at the top level. Add that size to
  `--h1-sizes` — the flag takes a comma-separated list.
- **A size used hundreds of times is a subhead**, not a chapter. Leave it out;
  it becomes an h3 and stays out of the table of contents, which is what you
  want.
- **A printed contents page** shows up as headings full of page numbers or
  `···········` dot leaders. Drop those pages with `--drop-pages 9-12`. The
  EPUB gets a real navigable contents, so the printed one is dead weight.

### 3. Convert

```bash
python3 scripts/pdf2epub.py convert "book.pdf" -o "Title - Author.epub" \
  --work /tmp/bookbuild \
  --h1-sizes 240,39 --h2-sizes 138 \
  --drop-pages 9-12 \
  --title "Real Title" --author "Author Name" --lang pt
```

Reuse the same `--work` directory across runs. Extraction and table crops are
cached there, so re-converting with different flags takes seconds rather than
minutes.

Set `--title`/`--author` from the book itself, not the filename — pirate-library
filenames like `Some Book (z-library.sk, 1lib.sk).pdf` make an ugly library
entry. The `analyze` output's first headings usually show the real title.

### 4. Check what it reports

The convert step prints a self-check. Two numbers matter:

- **Words not in the PDF's vocabulary.** The script compares against
  `pdftotext` output, which dehyphenates correctly, so it is a good oracle.
  Under ~1% is healthy. A spike means words are still being split — usually
  hyphen joining, covered in the troubleshooting reference.
- **File size.** Over 25 MB cannot be emailed through Gmail. Lower
  `--max-image-px` (default 1400, already well past what e-ink can show), or
  use a delivery route without the limit.

Then open the result and read a page or two of actual prose. The numbers catch
broken words; only reading catches a book whose quotes all came out as
footnotes.

### 5. Deliver

Amazon's own limits are the thing to plan around:

| Route | Limit |
|---|---|
| [Send to Kindle on the web](https://www.amazon.com/sendtokindle) | 200 MB |
| Email to `@kindle.com` | 50 MB |
| Gmail attachment | 25 MB |

The web uploader is the path of least resistance and sidesteps the size problem
entirely. USB also works — a Kindle mounts as a drive and converts EPUBs dropped
into `documents/`. Mention the web uploader when a file is anywhere near 25 MB,
rather than shrinking images until quality suffers.

## What the script handles, and the reasoning

Knowing *why* each rule exists makes it much easier to tell when a book needs
a different setting.

**Paragraphs** — a line starts a new paragraph if it is indented past the body
margin, or if the previous line stopped short of the right margin. In justified
text those two signals are reliable; the short line is the stronger of the two.

**Hyphenation** — PDFs break words across lines two ways, and both need
handling. A soft hyphen (U+00AD) gets silently turned into a space by every
converter, giving `impor tante`, `tam bém`. A real hyphen-minus is worse,
because `produc-` + `tive` has to become `productive` while `self-` +
`interest` must stay `self-interest`. The script decides using `pdftotext`
output as an oracle — it dehyphenates correctly, so if it knows the joined
word, the hyphen goes. This is the most common way a converted book is quietly
ruined, because it looks fine until you read closely; the vocabulary check at
the end of a conversion is what catches it.

**Block quotes vs footnotes** — most books set both in the same smaller type,
so size alone cannot separate them. Indentation can: a quote is inset as a whole
block, a footnote starts at the body margin with a hanging indent on its
continuation lines. `--quote-indent` is the threshold. Getting this wrong makes
every long quotation render in tiny footnote type.

**Footnote placement** — a note sits at the bottom of the page, so in raw page
order it lands in the middle of the sentence it annotates. Notes are held back
and emitted after the paragraph they interrupted finishes.

**Tables and worksheets** — multi-column layouts cannot survive linear reflow;
the columns interleave into nonsense. Any line whose runs are separated by a
wide horizontal gap is treated as tabular, and the region is rendered as a
cropped image. These stay readable and zoomable but will not reflow with font
size, which is the right trade for a table. If `analyze` shows a small font size
that is largely tabular, add it with `--table-sizes 11`.

**Code listings** — detected by monospace font family and kept preformatted.
Reflowing code destroys it.

**Images** — book scans arrive at print resolution, far beyond any e-ink screen.
Everything is capped at 1400px; line art is quantized to a small palette, photos
go to JPEG. Page 1 art is dropped because it duplicates the cover.

## Scope

This handles text-based book PDFs — the overwhelming majority. Two things it
does not do:

- **Scanned books with no text layer.** If `analyze` reports almost no text,
  the pages are images and need OCR (`ocrmypdf`) before any of this applies.
  Say so rather than producing an empty EPUB.
- **Heavily designed layouts** — magazines, cookbooks, textbooks with sidebars
  woven through the text. Reading order itself is ambiguous there. A
  fixed-layout format or the original PDF may genuinely be the better answer,
  and it is worth saying so.
