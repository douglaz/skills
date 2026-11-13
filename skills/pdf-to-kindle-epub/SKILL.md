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

**Read the sample paragraphs.** If they are chopped up, stop and fix that
first — nothing else matters. If they read as continuous prose, that is a good
sign but not proof: two samples read fine on a book that still had hundreds of
paragraphs cut mid-sentence elsewhere. The convert step's mid-sentence count is
the real check.

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
- **A printed contents page** can show up as headings or `···········` dot
  leaders. Digit runs in the page's rightmost quarter, separated from the
  preceding run by at least 30px on the same visual line, are filtered from
  headings. Chapter numbers next to their labels and number-only headings
  are kept. Drop printed contents pages with `--drop-pages 9-12`. The EPUB
  gets a real navigable contents, so the printed one is dead weight.

### 3. Convert

```bash
python3 scripts/pdf2epub.py convert "book.pdf" -o "Title - Author.epub" \
  --work /tmp/bookbuild \
  --h1-sizes 240,39 --h2-sizes 138 \
  --drop-pages 9-12 \
  --title "Real Title" --author "Author Name" --lang pt
```

Reuse the same `--work` directory for the same PDF. Extraction is bound to the
input's SHA-256 content: a different PDF, including one OCR'd in place, is
refused with a message to use a fresh `--work` directory. Table crops are keyed
by page, crop region and DPI, so changed flags render any newly needed crops.

Set `--title`/`--author` from the book itself, not the filename — pirate-library
filenames like `Some Book (z-library.sk, 1lib.sk).pdf` make an ugly library
entry. The `analyze` output's first headings usually show the real title.

### 4. Check what it reports

The convert step prints a self-check and a hyphen-decision report:

- **Paragraphs ending mid-sentence.** Paragraphs of ten or more words that stop
  without closing punctuation while another paragraph follows — one paragraph
  cut in two, the failure a reader hits first. Under ~4% is healthy (one book
  read 3.4%, 105 of 3124 paragraphs, with `--indent 18`); the rest are usually
  captions or table text. A spike means lines are still being cut: see "Text
  breaks mid-sentence" in the troubleshooting reference.
- **Words not in the PDF's vocabulary.** The script compares against
  `pdftotext` output. In measured poppler 26.10 output, that tool drops every
  line-end hyphen, including compounds, so this comparison cannot certify
  hyphen decisions. Under ~1% is a useful screening threshold; a spike can
  expose split or unknown words. It cannot detect omitted text or a paragraph
  cut in two — every word in the latter is intact.
- **No-evidence hyphen decisions.** The count and first eight decisions show
  the page, both fragments and whether the hyphen was kept or the word joined.
  Review these against the PDF; the standalone-word fallback is a heuristic.
- **File size.** Over 25 MB cannot be emailed through Gmail. Lower
  `--max-image-px` (default 1400, already well past what e-ink can show), or
  use a delivery route without the limit.

Then open the result and read a page or two of actual prose. The numbers can
expose some broken words; only reading catches a book whose quotes all came out as
footnotes.

### 5. Deliver

Amazon's own limits are the thing to plan around:

| Route | Limit |
|---|---|
| [Send to Kindle on the web](https://www.amazon.com/sendtokindle) | 200 MB |
| Email to `@kindle.com` | 50 MB |
| Gmail attachment | 25 MB |

The web uploader is the path of least resistance and sidesteps the size problem
entirely. Mention it when a file is anywhere near 25 MB, rather than shrinking
images until quality suffers.

USB also works, but not with the EPUB itself: a Kindle does not open an EPUB
copied over USB — only Send to Kindle converts one. Convert to AZW3 first
(`ebook-convert book.epub book.azw3`) and copy that into `documents/`, then
eject before unplugging.

## What the script handles, and the reasoning

Knowing *why* each rule exists makes it much easier to tell when a book needs
a different setting.

**Running heads and footers** — only page-top heads use the low-repetition
rule: the text, with digits removed, must occur as a detached first line above
the text block on at least two pages. The block's top is the outer decile of
each page's first line with a normally spaced neighbour, falling back to
interior text on sparse pages. Detached one-off heads and copyright lines do
not anchor it just by sharing a height. The extent allows at least 12px of
vertical page offset, so captions above tables and spaced subheads inside it
survive regardless of repetition. Heads may repeat within just one chapter
and may carry a changing folio, including one set larger than the title.

Page-bottom lines are handled as before: a last line is stripped only when
its digit-stripped text occurs among first or last lines at least
`max(8, 15% of pages)` times. No position or low-repetition rule applies there,
so citations repeated on only two or three pages and infrequent note bands
survive. The same book-wide threshold also strips first lines above the text
block. Both rules require modal size at most body; the digits/roman-only folio
rule is unchanged.

**Paragraphs** — a line starts a new paragraph if it is indented, or if the
previous line stopped short of the right margin. In justified text those two
signals are reliable; the short line is the stronger of the two. Once a
paragraph has a continuation line on the page, an indent is measured against
the leftmost such line rather than the page margin: list items wrap at a
hanging indent, and the minimum absorbs PDFs that start each line a few px
off. That reference resets on every page, so a page whose margin was misjudged
cannot carry a wrong one onward. A bullet or list number set as its own run
always opens a paragraph. Raise `--indent` above any line-start jitter but
below the real paragraph indent.

Two overrides, both from the text rather than the geometry. A line ending in a
soft hyphen never ends a paragraph: the word runs on. And when the previous
line has no closing punctuation and the next starts in lower case, the sentence
is still going, so they join — this keeps dialogue with a hanging speaker name
("David: …" wrapping under the text) in one piece, which geometry alone
splits. It applies only after a prose line: 35+ characters *and* ending near
the page's body measure. An inset poem or a column of index entries sets its
own right edge well short of the body's, so its lines stay line by line.
Lettered list items ("b. ") are exempt.

A ragged-right prose box — a worksheet, a boxed dialogue — looks exactly like
that inset poem, so by default its lines stay apart too. For a book full of
such boxes and without poetry, `--ragged-prose` drops the margin condition for
35+ character lines. It merges free verse, so leave it off for books with
poems.

**Hyphenation** — PDFs break words across lines two ways, and both need
handling. A soft hyphen (U+00AD) gets silently turned into a space by every
converter, giving `impor tante`, `tam bém`. A real hyphen-minus is worse,
because `produc-` + `tive` has to become `productive` while `self-` +
`interest` must stay `self-interest`. Measured poppler 26.10 `pdftotext` output
drops every line-end hyphen, so it cannot decide this or reliably detect
compound damage in the vocabulary check. The script instead counts words in
the XML's visual lines, case-insensitively, excluding every line's first and
last token so neither break fragment supplies evidence. Hyphenated compounds
are whole tokens; their halves do not count as standalone words.

If only one form (`self-interest` or `selfinterest`) occurs mid-line, that form
wins. If both occur, the more frequent wins, and a tie keeps the hyphen. With
neither form present, keep the hyphen only if both halves occur mid-line as
standalone words; otherwise join. Conversion reports the number of these
no-evidence decisions and the first eight with page, fragments and action.
If either fragment touching a hyphen-minus is not a word, the hyphen stays
and the break is excluded from the no-evidence count.

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
that is largely tabular, add it with `--table-sizes 11`. A row with a single
cell has no column gap, so lines lying between a table's rows are folded into
its picture too — otherwise they print a second time, out of order, as text
after it.

**Code listings** — detected by monospace font family and kept preformatted.
Reflowing code destroys it.

**Images** — figures follow their page position and wait until an open paragraph
closes, including one continuing from the previous page. Book scans arrive at
print resolution, far beyond any e-ink screen.
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
