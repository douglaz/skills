# Troubleshooting a converted book

Each entry: what the reader sees, why it happens, what fixes it. Symptoms are
written the way a person actually reports them, because that is how the problem
arrives.

## Contents

- [Text breaks mid-sentence](#text-breaks-mid-sentence)
- [Words split in half](#words-split-in-half)
- [A block of text is smaller than the rest](#a-block-of-text-is-smaller-than-the-rest)
- [A footnote interrupts a sentence](#a-footnote-interrupts-a-sentence)
- [Grey background](#grey-background)
- [Table of contents is wrong or starts partway in](#table-of-contents-is-wrong-or-starts-partway-in)
- [Headings mashed together or full of page numbers](#headings-mashed-together-or-full-of-page-numbers)
- [A table came out as gibberish](#a-table-came-out-as-gibberish)
- [Font size won't change on the Kindle](#font-size-wont-change-on-the-kindle)
- [File too large to email](#file-too-large-to-email)
- [Stray PNGs appeared next to the PDF](#stray-pngs-appeared-next-to-the-pdf)
- [A word looks hyphenated on the device](#a-word-looks-hyphenated-on-the-device)

---

## Text breaks mid-sentence

> "after 'melhorar' there is a line break"
> "I see 'Na verdade,' then 'a' alone on a line then 'melhora foi tão grande'"

Every visual line became its own paragraph. This is what `ebook-convert
book.pdf book.epub` and the pdftohtml-into-calibre route both produce, and it is
the reason this skill exists.

Verify by looking at the markup, not the text — tag-stripped text looks fine
because the tags are where the damage is:

```python
# one <p> per line = broken
'<p class="calibre19">sua cabeça automaticamente e costumam ter um enorme</p>\n<p class="calibre19">impacto no modo como</p>'
```

**Fix:** use `pdf2epub.py`, which rebuilds paragraphs from line geometry. If it
is still happening *through* the script, the page's margins are being misread —
check the sample paragraphs in `analyze`, then try adjusting `--short` (how far
short of the right margin ends a paragraph, default 18px) or `--indent`.

A caution learned the hard way: when checking output, strip tags with a
*space* replacement and it will look correct whether or not it is broken. Look
at the raw markup.

## Words split in half

> "É pos sível", "impor tante", "tam bém"

A soft hyphen (U+00AD) at the line end was turned into a space. Converters do
this silently. `pdftotext` gets it right, which is why it is used as the
verification oracle.

Real hyphen-minus breaks (`produc-` / `tive`) are the other half of this, and
they are ambiguous: `self-` / `interest` must *keep* its hyphen. The script
resolves it by asking whether `pdftotext` -- which dehyphenates correctly --
knows the joined word.

**Fix:** handled automatically, both kinds. If it persists, check the
vocabulary figure the conversion prints; a book whose `pdftotext` output is
itself poor (unusual encoding, ligature problems) weakens the oracle. Compare
a sample page of `plain.txt` in the work directory against the PDF.

**Do not** fix this by rejoining word pairs after the fact. Without the hyphen
you cannot tell `de pressão` (two words) from `de-pressão` (one), and a
global rejoin corrupts real text. Join at the hyphen, while it still exists.

## A block of text is smaller than the rest

> "the quote beginning in 'Toda vez' is a bit small"

A block quote was classified as a footnote. Most books set both at the same
smaller size, so only indentation separates them.

**Fix:** check `analyze` for the indent split, then adjust `--quote-indent`
(default 40px). In a typical book, quotes sit ~50px in and footnotes ~0-30px.
Lower the threshold if quotes are being missed, raise it if footnotes are
being promoted to full size.

## A footnote interrupts a sentence

> "after 'melhorar' many lines are smaller until '...visitar o meu site'"

The note sits at the page bottom in the PDF, so raw page order drops it into
the middle of the sentence it annotates.

**Fix:** handled automatically — notes accumulate separately and are emitted
after the interrupted paragraph closes. A note split across two pages is also
rejoined by this, which the page-order approach mangles.

## Grey background

`pdftohtml` writes `<body bgcolor="#A0A0A0">`, which becomes
`background-color: #A0A0A0` in the stylesheet and a grey page on the device.

**Fix:** the script writes its own stylesheet. If adapting another pipeline,
strip that rule.

## Table of contents is wrong or starts partway in

> "the table of contents is starting in part two"

Calibre's heuristic chapter detection guessed. Never rely on it for a book with
real structure.

**Fix:** pick heading sizes explicitly from `analyze` output and pass
`--h1-sizes` / `--h2-sizes`. The script wires them to `--level1-toc` /
`--level2-toc`. Remember front matter (preface, introduction, index) is often
at a smaller size than part numerals but still belongs in `--h1-sizes`.

## Headings mashed together or full of page numbers

> `PARTE III DEPRESSÕES "REALISTAS"201`
> `CAPÍTULOV COMO VENCER...`
> `··············· ···············`

Three distinct causes:

1. **Page numbers in headings** — those pages are the book's *printed* contents
   page. Drop them: `--drop-pages 9-12`. Dot leaders (`······`) are the same
   thing.
2. **`CAPÍTULOV`** — the numeral is set so large it shares a visual line with
   its label, so joining whole lines concatenates them. Headings must be split
   at the *run* level, which the script does; the result is
   `CAPÍTULO V — TITLE`.
3. **Unrelated headings merged** — grouping reached too far. Groups break at a
   body-text line or a 150px vertical gap.

A related trap: a chapter opener line reads `CAPÍTULO` at body size beside a
numeral at 138pt, so by character volume its *modal* size is body size and it
is not recognized as a heading at all. Judge by the largest type on the line,
guarded so a drop cap in a long paragraph is not mistaken for a heading.

## A table came out as gibberish

> `1. Todo mundo sabe o quanto Tirar conclusões precipitadas 1. Sou desorganizada`

Columns were reflowed into a single stream and interleaved.

**Fix:** the script renders table regions as cropped images. If a table was
missed, `analyze` shows small font sizes with a "% tabular" figure — add the
size with `--table-sizes 11`. If something that is *not* a table got imaged,
raise `--table-gap` or set `--table-gap 0` to disable gap detection.

Rendered tables will not reflow with font size. That is the correct trade: a
legible fixed table beats a reflowable scrambled one. Say so when reporting the
result, since it is a real limitation the reader will notice.

## Font size won't change on the Kindle

Absolute units, or absolutely positioned text. Check the EPUB's stylesheet for
`font-size:...px` and `position:absolute` — there should be none of either.

Note that calibre's font rescaling rewrites relative sizes too, and can shrink
a deliberate `0.85em` to `0.75em`. The script passes
`--disable-font-rescaling` and pins sizes in its own stylesheet.

## File too large to email

Almost always images at print resolution — one 3719x5394 page scan was 12 MB on
its own, roughly four times the pixels a Kindle Scribe can display.

**Fix:** lower `--max-image-px` (default 1400). Beyond that, prefer [Send to
Kindle on the web](https://www.amazon.com/sendtokindle) (200 MB) over degrading
the images; Gmail's 25 MB limit is the tightest link in the chain, not Amazon's.

For reference on one 556-page book: 36 MB of images became 5.1 MB by capping
dimensions, quantizing line art to a 32-colour palette, sending photos to JPEG
q82, and dropping the page-1 scan that duplicated the cover — with no visible
quality loss.

## A word looks hyphenated on the device

> "I see 'É pos-sível'"

If the text in the EPUB is correct, this is the Kindle's own hyphenation at a
line break, not a conversion defect. Check the file before chasing it:

```python
'possível' in text   # True -> it's the device, nothing to fix
```
