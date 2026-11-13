#!/usr/bin/env python3
"""Rebuild a book PDF into a reflowable EPUB, using line geometry.

Why this exists: every off-the-shelf PDF->EPUB path (calibre's PDF input,
pdftohtml's HTML mode) emits one block per *visual line* of the PDF. An
e-reader then treats each line as its own paragraph, so the text arrives
shattered -- a stray "a" alone on a line, a break mid-sentence. No amount of
text cleanup fixes that, because the damage is in the markup.

`pdftohtml -xml` gives per-line coordinates, font ids and sizes. From those we
can recover what the layout actually meant:

    indented line / previous line ended short  -> paragraph boundary
    dominant font size                         -> body text
    larger sizes                               -> headings, by rank
    smaller + inset                            -> block quote
    smaller + at the body margin               -> footnote
    monospace family                           -> code listing
    big horizontal gaps between runs           -> table (rendered as an image)

Two modes:
    analyze   print what was detected; always do this first
    convert   build the EPUB
"""
import argparse, collections, hashlib, html, os, re, shutil, subprocess, sys, zipfile
from xml.etree import ElementTree as ET

ZOOM = 1.5          # pdftohtml -xml renders coordinates at 1.5x PDF points
NEEDED = ['pdftohtml', 'pdftoppm', 'pdftotext', 'ebook-convert']
WORD = r"[^\W\d_]+(?:['’-][^\W\d_]+)*"
MONO = re.compile(r'mono|courier|consol|menlo|inconsolata|typewriter', re.I)


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


def need_tools():
    missing = [t for t in NEEDED if not shutil.which(t)]
    if missing:
        sys.exit(
            f"missing tools: {', '.join(missing)}\n"
            "NixOS:  nix shell nixpkgs#poppler-utils nixpkgs#calibre nixpkgs#imagemagick "
            "-c python3 <this script> ...\n"
            "Debian: apt install poppler-utils calibre imagemagick\n"
            "macOS:  brew install poppler imagemagick && brew install --cask calibre")


def txt_of(s):
    return re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', '', s)).strip()


# --------------------------------------------------------------- extraction
def extract(pdf, work):
    """Run pdftohtml inside `work`.

    pdftohtml writes extracted images next to its output, so it gets a copy of
    the PDF in a scratch directory -- otherwise it litters the user's folder
    with dozens of PNGs.
    """
    os.makedirs(work, exist_ok=True)
    src = os.path.join(work, 'src.pdf')
    if os.path.exists(src):
        def digest(path):
            h = hashlib.sha256()
            with open(path, 'rb') as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b''):
                    h.update(chunk)
            return h.digest()
        if digest(pdf) != digest(src):
            sys.exit('input PDF differs from cached src.pdf; use a fresh --work directory '
                     'to extract this PDF (including after OCR).')
    if not os.path.exists(src):
        shutil.copy(pdf, src)
    xml = os.path.join(work, 'book.xml')
    if not os.path.exists(xml):
        run(['pdftohtml', '-xml', '-enc', 'UTF-8', '-nodrm', 'src.pdf', 'book'], cwd=work)
    txt = os.path.join(work, 'plain.txt')
    if not os.path.exists(txt):
        # In measured poppler 26.10 output, pdftotext drops every line-end
        # hyphen, including compounds. Useful for comparison, not an oracle.
        run(['pdftotext', 'src.pdf', 'plain.txt'], cwd=work)
    return xml


def inner(el):
    """Serialize an element's children, keeping only <b>/<i>."""
    out = []
    if el.text:
        out.append(html.escape(el.text))
    for c in el:
        s = inner(c)
        out.append(f'<{c.tag}>{s}</{c.tag}>' if c.tag in ('b', 'i') else s)
        if c.tail:
            out.append(html.escape(c.tail))
    return ''.join(out)


def lines_of(runs):
    """Cluster text runs into visual lines by vertical centre.

    Oversized single letters whose topmost covered line starts with lowercase
    text within one body em to their right are removed first. Candidate runs
    use the same centre clustering as ordinary lines; groups centred above
    the letter's top edge or with text running through its box are not covered.
    The latter check includes every run on the visual line except oversized
    single letters, with 2px slack for touching or kerned quotes. Adjacency or
    lowercase failure on the first covered line rejects the cap. Caps are
    restored among the runs of the line reached by following their neighbours
    to a surviving run, in left-to-right order, retaining their own trailing
    word space. Cyclic chains stay in the clustering. Initial lines carry the caps'
    right/bottom extent so paragraph
    assembly can account for the inset of covered lines. Their height must not
    merge the body lines they cover. All other runs use the original centre
    clustering, which keeps small caps and raised runs with their text.
    """
    sizes = collections.Counter()
    for _, _, _, _, size, _, txt in runs:
        if size:
            sizes[size] += max(len(txt_of(txt)), 1)
    reference = sizes.most_common(1)[0][0] if sizes else 12
    oversized = {}
    for i, (top, height, left, width, size, fam, txt) in enumerate(runs):
        letter = html.unescape(txt_of(txt))
        # 1.5 times the page's character-weighted dominant size is clearly
        # oversized; ordinary capitals and modest font variations stay put.
        if len(letter) != 1 or not letter.isalpha() or size < 1.5 * reference:
            continue
        oversized[i] = letter
    caps = {}
    for i, letter in oversized.items():
        top, height, left, width, size, fam, txt = runs[i]
        neighbours = [j for j, r in enumerate(runs)
                      if j != i and r[2] >= left + width - 2
                      and r[0] < top + height / 2 and r[0] + r[1] > top]
        if not neighbours:
            continue
        # Find the first visual line before choosing its leftmost run. Use
        # the ordinary centre/height rule so small caps and raised runs stay
        # with their text rather than becoming a separate opening line.
        # A previous line may overlap the box without being covered by it:
        # check all runs in the group's band for text crossing the cap, not
        # just the candidates to its right. Ignore oversized letters so the
        # cap's own box and chained initials cannot exclude their first line.
        def covered(c, h):
            return c >= top and not any(
                j not in oversized
                and abs(r[0] + r[1] / 2 - c) <= max(r[1], h) * 0.45
                and r[2] < left + width - 2 and r[2] + r[3] > left + 2
                for j, r in enumerate(runs))

        first_line = []
        c, h = 0, 0
        for j in sorted(neighbours, key=runs.__getitem__):
            r = runs[j]
            centre = r[0] + r[1] / 2
            if first_line and abs(centre - c) > max(r[1], h) * 0.45:
                if covered(c, h):
                    break
                first_line = []
                c, h = 0, 0
            c = (c * len(first_line) + centre) / (len(first_line) + 1)
            h = max(h, r[1])
            first_line.append(j)
        if not covered(c, h):
            continue
        j = min(first_line, key=lambda j: (runs[j][2], runs[j][0]))
        # One body em allows a word space after the initial (and overlaps),
        # without borrowing lowercase text from a distant column.
        if runs[j][2] - (left + width) > reference:
            continue
        following = html.unescape(txt_of(runs[j][6]))
        if following and following[0].islower():
            caps[i] = (j, letter)
    targets = {}
    for start in caps:
        path, seen = [], set()
        j = start
        while j in caps and j not in targets and j not in seen:
            path.append(j)
            seen.add(j)
            j = caps[j][0]
        target = None if j in seen else targets.get(j, j)
        for i in path:
            targets[i] = target
    # No letter in a chain that loops can be removed safely. Retain those
    # runs, including their size and geometry, for normal clustering.
    caps = {i: cap for i, cap in caps.items() if targets[i] is not None}
    out = []
    line_for = {}
    for i in sorted((i for i in range(len(runs)) if i not in caps), key=runs.__getitem__):
        top, height, left, width, size, fam, txt = runs[i]
        c = top + height / 2
        if out and abs(c - out[-1]['c']) <= max(height, out[-1]['h']) * 0.45:
            ln = out[-1]
            ln['runs'].append((left, width, size, fam, txt))
            ln['c'] = (ln['c'] * ln['n'] + c) / (ln['n'] + 1)
            ln['n'] += 1
            ln['h'] = max(ln['h'], height)
        else:
            out.append({'c': c, 'h': height, 'n': 1,
                        'runs': [(left, width, size, fam, txt)]})
        line_for[i] = len(out) - 1
    res = []
    for ln in out:
        line_runs = sorted(ln['runs'])
        sizes = collections.Counter()
        for left, w, sz, fam, t in line_runs:
            sizes[sz] += max(len(txt_of(t)), 1)
        gaps = [line_runs[i + 1][0] - (line_runs[i][0] + line_runs[i][1])
                for i in range(len(line_runs) - 1)]
        res.append({
            'left': line_runs[0][0],
            'right': max(r[0] + r[1] for r in line_runs),
            'size': sizes.most_common(1)[0][0],
            'max': max(r[2] for r in line_runs),
            'mono': all(MONO.search(r[3] or '') for r in line_runs),
            'gap': max(gaps) if gaps else 0,          # widest internal gap = column split
            'html': ''.join(r[4] for r in line_runs),
            'runs': line_runs,
            'c': ln['c'], 'h': ln['h'],
        })
    initials = collections.defaultdict(list)
    for i in caps:
        initials[line_for[targets[i]]].append(i)
    for line_index, indices in initials.items():
        ln = res[line_index]
        # Flatten the decorative initial to the line's normal type and keep
        # the body's centre/height, maximum size and gaps. Even a short opening
        # stays prose, and subsequent covered lines retain their usual spacing.
        letters = []
        for i in sorted(indices, key=lambda i: (runs[i][2], i)):
            initial = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', '', runs[i][6]))).lstrip()
            j = caps[i][0]
            following = caps[j][1] if j in caps else html.unescape(re.sub(r'<[^>]+>', '', runs[j][6]))
            # A space on either side is enough, including through markup.
            if following[:1].isspace():
                initial = initial.rstrip()
            letters.append((runs[i][2], runs[i][3], ln['size'], runs[i][5], html.escape(initial)))
        ln['runs'] = sorted(ln['runs'] + letters, key=lambda r: r[0])
        ln['left'] = ln['runs'][0][0]
        ln['html'] = ''.join(r[4] for r in ln['runs'])
        ln['dropcap'] = (max(runs[i][2] + runs[i][3] for i in indices),
                         max(runs[i][0] + runs[i][1] for i in indices))
    return res


def parse(xml):
    root = ET.parse(xml).getroot()
    fonts, pages = {}, []
    for pg in root.findall('page'):
        for f in pg.findall('fontspec'):          # ids persist across pages
            fonts[f.get('id')] = (int(f.get('size')), f.get('family') or '')
        runs, imgs, positioned_images = [], [], []
        for el in pg:
            if el.tag == 'text':
                sz, fam = fonts.get(el.get('font'), (0, ''))
                runs.append((int(el.get('top')), int(el.get('height')),
                             int(el.get('left')), int(el.get('width')),
                             sz, fam, inner(el)))
            elif el.tag == 'image':
                src = el.get('src').split('/')[-1]
                imgs.append(src)
                positioned_images.append((int(el.get('top', '0')), src))
        pages.append({'n': int(pg.get('number')),
                      'w': int(pg.get('width')), 'h': int(pg.get('height')),
                      'lines': lines_of(runs), 'imgs': imgs,
                      'positioned_images': positioned_images})
    # a size of 0 means the fontspec was missing; fall back to the common size
    vol = collections.Counter()
    for p in pages:
        for l in p['lines']:
            if l['size']:
                vol[l['size']] += len(txt_of(l['html']))
    body = vol.most_common(1)[0][0] if vol else 12
    for p in pages:
        for l in p['lines']:
            if not l['size']:
                l['size'] = l['max'] = body
    return pages, body


# ------------------------------------------------- running heads and folios
def strip_furniture(pages, body):
    """Drop page numbers and running heads.

    A folio is a line that is just a number. Page-top heads can repeat within
    one chapter, but must sit above the book's text block. Bottom lines keep
    the original book-wide repetition rule, so rare notes are not furniture.
    """
    leading = collections.Counter()
    for p in pages:
        body_lines = [l for l in p['lines'] if l['size'] == body and txt_of(l['html'])]
        leading.update(b['c'] - a['c'] for a, b in zip(body_lines, body_lines[1:])
                       if 0 < b['c'] - a['c'] <= 2 * body)
    pitch = leading.most_common(1)[0][0] if leading else 1.5 * body
    jitter = max(12, pitch / 4)

    def key_of(l):
        # A changing folio may share the title's run or visual line.
        return re.sub(r'\d+', '', txt_of(l['html'])).strip().lower()

    # Estimate only the top from each page's first text line with a neighbour
    # within normal leading. Detached one-off heads, roman folios and copyright
    # lines cannot move it merely by occupying the same height on a few pages.
    # On sparse pages an interior text line can supply the fallback. The outer
    # decile allows different layouts without letting a title page set the top.
    starts = []
    for p in pages:
        real = [l for l in p['lines'] if txt_of(l['html'])]
        flow = [l for l in real if l['size'] <= body]
        block = [l for i, l in enumerate(flow)
                 if (i > 0 and 0 < l['c'] - flow[i - 1]['c'] <= 1.2 * pitch)
                 or (i + 1 < len(flow) and 0 < flow[i + 1]['c'] - l['c'] <= 1.2 * pitch)]
        if not block:
            block = [l for l in real[1:-1] if l['size'] <= body]
        if block:
            starts.append(block[0]['c'])
    starts.sort()
    top = starts[(len(starts) - 1) // 10] if starts else None

    def above_block(l):
        # Spaced captions/subheads inside the extent are always content, even
        # when repeated. Include offsets up to 12px (equality stays content),
        # while a tight head 30px above the block still lies outside it.
        # If no block is measured, preserve page-top text.
        return top is not None and l['c'] < top - jitter

    edge, detached = collections.Counter(), collections.Counter()
    for p in pages:
        real = [l for l in p['lines'] if txt_of(l['html'])]
        # Keep the original first/last-line counts and threshold for footers.
        # No geometric or low-repetition rule applies at the page bottom:
        # repeated citations and infrequent single-line note bands survive.
        for l in real[:1] + real[-1:]:
            key = key_of(l)
            if key:
                edge[key] += 1
        if (len(real) >= 2 and above_block(real[0])
                and real[1]['c'] - real[0]['c'] > 1.2 * pitch):
            key = key_of(real[0])
            if key:
                detached[key] += 1
    repeated = {k for k, v in edge.items() if v >= max(8, len(pages) * 0.15)}
    heads = {k for k, v in detached.items() if v >= 2}
    dropped = 0
    for p in pages:
        keep = []
        real = [l for l in p['lines'] if txt_of(l['html'])]
        for i, l in enumerate(real):
            t = txt_of(l['html'])
            key = key_of(l)
            atedge = i < 1 or i >= len(real) - 1
            # Only digits, and only in body type: a part opener's roman numeral
            # is set in display type and must survive.
            if atedge and l['size'] <= body and re.fullmatch(r'[\divxlcdm]{1,8}', t.lower()):
                dropped += 1
                continue
            # Only page-top heads get the two-page rule, supported by detached
            # occurrences outside the block. The book-wide rule also needs
            # that position at the top, but stays geometry-free at the bottom.
            # Judge modal size: a head may carry a larger-type folio.
            if l['size'] <= body and (
                    (i == 0 and above_block(l) and (key in heads or key in repeated))
                    or (i == len(real) - 1 and key in repeated)):
                dropped += 1
                continue
            keep.append(l)
        p['lines'] = keep
    return dropped


# ------------------------------------------------------------ classification
def classify(pages, body, opt):
    """Tag every line: head / body / quote / note / code / table."""
    tbl_sizes = {int(x) for x in opt.table_sizes.split(',')} if opt.table_sizes else set()
    for p in pages:
        flowing = [l for l in p['lines'] if l['size'] < body + opt.head_delta]
        ref = [l for l in flowing if l['size'] == body] or flowing
        page_left = (collections.Counter(l['left'] for l in ref).most_common(1)[0][0]
                     if ref else 0)
        p['left'] = page_left
        for l in p['lines']:
            # Judge headings by the largest type on the line, not the most
            # common: a chapter opener reads "CAPITULO" at body size beside a
            # numeral at 138pt, so by volume it looks like body text. Require
            # the big type to carry the line, or the line to be short, so a
            # drop cap in a long paragraph is not mistaken for a heading.
            chars = sum(max(len(txt_of(r[4])), 1) for r in l['runs'])
            big = sum(max(len(txt_of(r[4])), 1) for r in l['runs']
                      if r[2] >= body + opt.head_delta)
            if l['max'] >= body + opt.head_delta and (big / chars >= 0.4 or chars < 60):
                l['kind'] = 'head'
            # Column gaps only mean a table in text-size type. A centred
            # display numeral sitting beside its title also shows a wide gap,
            # and turning a chapter opener into a picture loses the heading.
            elif ((opt.table_gap and l['gap'] >= opt.table_gap and len(l['runs']) > 1
                   and l['size'] <= body)
                    or l['size'] in tbl_sizes):
                l['kind'] = 'table'          # columns, not prose
            elif l['mono'] and opt.code:
                l['kind'] = 'code'
            elif l['size'] <= body - 2:
                # Block quotes and footnotes share the same small type in most
                # books. Indentation tells them apart: a quote is inset as a
                # whole block; a footnote starts at the body margin, with at
                # most a hanging indent on continuation lines.
                l['kind'] = 'quote' if l['left'] - page_left >= opt.quote_indent else 'note'
            else:
                l['kind'] = 'body'


def heading_groups(pages, body):
    """Consecutive display-type lines form one heading.

    A chapter opener is typically a huge numeral, a small label word and the
    title on two or three lines -- separate lines in the PDF, one heading in
    the book.
    """
    groups = []
    for p in pages:
        run_ = []
        for l in p['lines']:
            if l['kind'] == 'head':
                # Keep collecting across a stray quote or table line, but a
                # body line means the heading is over and prose has started.
                if run_ and l['c'] - run_[-1]['c'] > 150:
                    groups.append((p, run_)); run_ = []
                run_.append(l)
            elif l['kind'] == 'body' and run_:
                groups.append((p, run_)); run_ = []
        if run_:
            groups.append((p, run_))
    return groups


NUMERAL = re.compile(r'^(?:[IVXLCDM]{1,8}|\d{1,3})$', re.I)


def heading_text(lines, page_width):
    """Join a heading group, moving a standalone numeral next to its label.

    Work at the *run* level, not the line level. A chapter numeral is set so
    large that it shares a visual line with the label or the title, so joining
    whole lines yields "CAPITULOV" or "TRISTEZA NAO E DEPRESSAOCAPITULOIX".
    Splitting by run recovers "CAPITULO IX — TRISTEZA NAO E DEPRESSAO".
    """
    parts = []
    for l in lines:
        for i, (left, w, sz, fam, t) in enumerate(l['runs']):
            s = txt_of(t)
            # A contents-page folio sits far to the right of its title,
            # across a column-sized gap. Keep isolated chapter numerals and
            # label/number runs separated by an ordinary word space.
            if (s.isdigit() and i > 0 and left >= 0.75 * page_width
                    and left - sum(l['runs'][i - 1][:2]) >= 30):
                continue
            if s:
                parts.append((sz, s))
    if not parts:
        return ''
    nums = [s for sz, s in parts if NUMERAL.match(s)]
    if not nums:
        return ' '.join(s for _, s in parts)
    labels = [s for sz, s in parts if s not in nums and len(s.split()) == 1 and s.isupper()]
    # Only the first label is structural; every other run is title text.
    rest = [s for sz, s in parts if s not in nums]
    if labels:
        rest.remove(labels[0])
    lead = ' '.join(labels[:1] + nums[:1])
    return f"{lead} — {' '.join(rest)}" if rest else lead


# ------------------------------------------------------------------- tables
def crop_tables(pages, work, dpi):
    """Render table regions as images.

    A multi-column table cannot survive linear reflow -- the columns interleave
    into nonsense ("1. Todo mundo sabe Tirar conclusoes 1. Sou desorganizada").
    A picture of the table stays readable and zoomable.
    """
    scale = dpi / 72 / ZOOM
    made = 0
    for p in pages:
        rows = [l for l in p['lines'] if l['kind'] == 'table']
        if not rows:
            p['tables'] = []
            continue
        groups, cur = [], []
        for l in sorted(rows, key=lambda l: l['c']):
            if cur and l['c'] - cur[-1]['c'] > 60:
                groups.append(cur); cur = []
            cur.append(l)
        if cur:
            groups.append(cur)
        regions = []
        for i, grp in enumerate(groups):
            # A row with a single cell has no column gap, so it is not tagged
            # as a table line -- yet it sits inside the crop. Left as text it
            # prints a second time, out of order, after the picture.
            lo, hi = grp[0]['c'], grp[-1]['c']
            x0, x1 = min(l['left'] for l in grp), max(l['right'] for l in grp)
            for l in p['lines']:
                if (l['kind'] in ('body', 'note', 'quote') and lo < l['c'] < hi
                        and l['left'] >= x0 - 10 and l['right'] <= x1 + 10):
                    l['kind'] = 'table'
                    grp.append(l)
            top = min(l['c'] - l['h'] for l in grp) - 10
            bot = max(l['c'] + l['h'] for l in grp) + 10
            left = min(l['left'] for l in grp) - 10
            right = max(l['right'] for l in grp) + 10
            x, y = max(0, int(left * scale)), max(0, int(top * scale))
            w, h = max(1, int((right - left) * scale)), max(1, int((bot - top) * scale))
            # Cache the actual pdftoppm parameters, including rounded pixels.
            name = f'tbl-{p["n"]}-{i}-{dpi}-{x}-{y}-{w}-{h}.png'
            path = os.path.join(work, name)
            if not os.path.exists(path):
                run(['pdftoppm', '-png', '-gray', '-r', str(dpi),
                     '-f', str(p['n']), '-l', str(p['n']),
                     '-x', str(x), '-y', str(y), '-W', str(w), '-H', str(h),
                     'src.pdf', name[:-4]], cwd=work)
                for f in os.listdir(work):
                    if f.startswith(name[:-4] + '-'):
                        os.rename(os.path.join(work, f), path)
                made += 1
            regions.append({'lines': {id(l) for l in grp}, 'src': name, 'done': False})
        p['tables'] = regions
    return made


# ------------------------------------------------------------ build the HTML
CSS = """body{margin:0;padding:0}
h1{page-break-before:always;text-align:center;font-size:1.6em;margin:2em 0 1em}
h2{page-break-before:always;text-align:center;font-size:1.4em;margin:2em 0 1em}
h3{font-size:1.05em;margin:1.4em 0 .6em}
p{margin:0;text-indent:1.2em;text-align:justify}
p.fn{font-size:.85em;text-indent:0;margin:.3em 0}
p.fig{text-indent:0;text-align:center;margin:1em 0}
blockquote{margin:1em 0 1em 1.6em;text-indent:0;text-align:justify}
pre{font-size:.85em;white-space:pre-wrap;margin:1em 0;text-indent:0}
img{max-width:100%}"""


def midline_words(pages):
    """Count case-insensitive tokens independent of pdftotext dehyphenation."""
    words = collections.Counter()
    for p in pages:
        for l in p['lines']:
            tokens = re.findall(WORD, html.unescape(txt_of(l['html'])).lower())
            # Mid-line means excluding EVERY line's first and last token.
            # Thus neither fragment of a hyphen-minus/soft-hyphen break can
            # supply evidence, even across pages or on a one-word line.
            # WORD keeps compounds whole: their halves are not standalone.
            words.update(tokens[1:-1])
    return words


def hyphen_join(prev, nxt, evidence, page=None, decisions=None):
    """Resolve a line-end hyphen using mid-line forms, then standalone halves."""
    # Only word fragments touching the break qualify. Searching for the
    # nearest words instead can turn "pages 212-" / "218 and" into 212218.
    stem = re.search(r'(?<!\w)(' + WORD + r')$',
                     html.unescape(re.sub(r'<[^>]+>', '', prev[:-1])))
    head = re.match(r'(' + WORD + r')(?!\w)',
                    html.unescape(re.sub(r'<[^>]+>', '', nxt)).lstrip())
    if stem and head:
        a, b = stem[1].lower(), head[1].lower()
        hyphenated, joined = evidence[a + '-' + b], evidence[a + b]
        if hyphenated or joined:
            keep = hyphenated >= joined       # a tie keeps the hyphen
        else:
            keep = bool(evidence[a] and evidence[b])
            if decisions is not None:
                decisions.append({'page': page, 'stem': stem[1], 'head': head[1],
                                  'action': 'keep' if keep else 'join'})
        if not keep:
            return prev[:-1] + nxt
    return prev + nxt


CLOSING = re.compile(r'(?:\s*</[bi]>)+\s*$')


def split_tail(s):
    """Separate trailing closing tags: 'demo\\xad</i>' -> ('demo\\xad', '</i>').

    A hyphen inside an italic run sits *before* the </i>, so a plain
    endswith() check misses it and the halves get joined with a space --
    "demo ra" for "demora".
    """
    m = CLOSING.search(s)
    if not m:
        return s.rstrip(), ''
    return s[:m.start()].rstrip(), re.sub(r'\s+', '', m.group(0))


def join_lines(prev, nxt, evidence, page=None, decisions=None):
    core, tail = split_tail(prev)
    nxt = nxt.lstrip()
    if core.endswith('\xad'):
        # soft hyphen: join without a space. Left to a converter this becomes
        # "impor tante".
        return core[:-1] + tail + nxt
    if core.endswith('-'):
        return hyphen_join(core, tail + nxt, evidence, page, decisions)
    return core + tail + ' ' + nxt


MARKER = re.compile(r'^\s*(?:[•●▪■◦‣·]|\(?(?:\d{1,3}|[a-zA-Z]|[ivxlcIVXLC]{1,6})[.)])\s*$')


OPEN_END = re.compile(r'[.!?:;…"”»)\]*]$')
PROSE_LINE = 35         # characters: a line of running prose, not a cell or label
LIST_HEAD = re.compile(r'(?:[a-z]|[ivx]{1,4})[.)]\s')


def runs_on(prev, nxt):
    """True when `prev` stops mid-sentence and `nxt` carries on in lower case."""
    a = html.unescape(re.sub(r'<[^>]+>', '', prev)).replace('\xad', '').rstrip()
    b = html.unescape(re.sub(r'<[^>]+>', '', nxt)).lstrip()
    return bool(a and b and not OPEN_END.search(a)
                and b[0].islower() and not LIST_HEAD.match(b))


def marker_left(l):
    """Where a list item's words start, if the line opens with a bullet or
    a number set as its own run ('•' at 85, 'Embora ...' at 111); else None."""
    runs = l['runs']
    if len(runs) > 1 and MARKER.match(txt_of(runs[0][4])):
        return runs[1][0]
    if re.match(r'\s*[•●▪■◦‣]', txt_of(l['html'])):
        return l['left']
    return None


def build_html(pages, body, opt, h1s, h2s, vocab=frozenset(), hyphen_decisions=None):
    blocks = []
    evidence = midline_words(pages)
    flows = {k: {'cur': None, 'gap': None, 'bgap': None, 'base': None, 'item': False,
                 'last': 0} for k in ('p', 'q', 'fn')}
    pending = []            # footnotes wait for the paragraph they interrupted
    pending_images = []    # figures also wait for any open prose/quote
    code = []

    def flush_code():
        if code:
            blocks.append(('pre', '\n'.join(code)))
            code.clear()

    def close(which):
        f = flows[which]
        if f['cur']:
            (pending if which == 'fn' else blocks).append((which, f['cur'][1]))
        f['cur'], f['gap'] = None, None
        if which == 'p':
            blocks.extend(pending)
            pending.clear()
        if which in ('p', 'q') and not any(flows[w]['cur'] for w in ('p', 'q')):
            blocks.extend(pending_images)
            pending_images.clear()

    def image(src):
        flush_code()
        target = pending_images if any(flows[w]['cur'] for w in ('p', 'q')) else blocks
        target.append(('img', src))

    def boundary():
        flush_code()
        for w in ('fn', 'q', 'p'):
            close(w)

    groups = {id(l): g for _, g in heading_groups(pages, body) for l in g}
    emitted = set()

    for i, p in enumerate(pages):
        for f in flows.values():
            f['base'] = None            # line positions are per page

        # Text beside a drop cap is inset to make room for the letter, not to
        # begin a paragraph. Require the line's bottom inside the cap's box:
        # real pdftohtml boxes overhang the next 14-15px line by up to 10px,
        # past its centre, but not its bottom. This preserves the next indent.
        # Covered starts only vote for the margin if an ordinary line
        # corroborates them. Initial lines retain their existing margin vote.
        # After that vote, covered lines use the flow's margin. An initial
        # keeps its own indent, clamped to that margin for hanging letters.
        # Line clustering and short-line breaks retain their usual behaviour.
        paragraph_left = {}
        for initial in p['lines']:
            if 'dropcap' not in initial:
                continue
            right, bottom = initial['dropcap']
            for l in p['lines']:
                if (initial['c'] < l['c'] and l['c'] + l['h'] / 2 <= bottom
                        and l['left'] >= right - 2):
                    paragraph_left[id(l)] = None

        # margins per flow: a page with both a quote and a footnote has two
        # different left margins at the same font size
        geo = {}
        for k in ('body', 'quote', 'note'):
            g = [l for l in p['lines'] if l['kind'] == k]
            if g:
                ordinary = {l['left'] for l in g if id(l) not in paragraph_left
                            and 'dropcap' not in l}
                starts = [l['left'] for l in g
                          if id(l) not in paragraph_left or l['left'] in ordinary]
                starts = starts or [g[0]['left']]
                geo[k] = (collections.Counter(starts).most_common(1)[0][0],
                          max(l['right'] for l in g))
                for l in g:
                    if 'dropcap' in l:
                        paragraph_left[id(l)] = max(l['left'], geo[k][0])
                    elif id(l) in paragraph_left:
                        paragraph_left[id(l)] = geo[k][0]

        # Interleave figures by page position, then defer them if a paragraph
        # is still open. Keep imgs as filenames for the cover-duplicate rule.
        images = p.get('positioned_images', [(0, src) for src in p['imgs']])
        events = [(top, 0, src) for top, src in images]
        events += [(l['c'] - l['h'] / 2, 1, l) for l in p['lines']]
        for _, event_kind, l in sorted(events, key=lambda e: (e[0], e[1])):
            if event_kind == 0:
                image(l)
                continue
            kind = l['kind']
            if kind == 'table':
                r = next((r for r in p['tables'] if id(l) in r['lines']), None)
                if r and not r['done']:
                    image(r['src'])
                    r['done'] = True
                continue
            if kind == 'head':
                grp = groups.get(id(l))
                if grp and id(grp[0]) in emitted:
                    continue
                boundary()
                lines = grp or [l]
                emitted.add(id(lines[0]))
                top = max(x['max'] for x in lines)
                tag = 'h1' if top in h1s else ('h2' if top in h2s else 'h3')
                blocks.append((tag, heading_text(lines, p['w'])))  # runs are already escaped by inner()
                continue
            if kind == 'code':
                for w in ('fn', 'q', 'p'):
                    close(w)
                code.append(txt_of(l['html']))
                continue
            flush_code()

            which = {'body': 'p', 'quote': 'q', 'note': 'fn'}[kind]
            bl, br = geo.get(kind, (l['left'], l['right']))
            if which in ('p', 'q'):           # body and quote alternate, never nest
                other = 'q' if which == 'p' else 'p'
                if flows[other]['cur']:
                    close(other)
            f = flows[which]
            cur, prev = f['cur'], f['gap']
            ml = marker_left(l)
            tl = (ml if ml is not None else paragraph_left.get(id(l), l['left'])) - bl
            if cur is None or ml is not None:
                new = True                              # nothing open, or a list item
            elif split_tail(cur[1])[0].endswith('\xad'):
                new = False                             # a hyphenated word runs on
            elif prev is None or prev >= opt.short:
                new = True                              # previous line fell short
            elif f['base'] is None:
                # No continuation line of this paragraph on this page yet:
                # judge against the page margin, letting a bulleted item's
                # wrapped lines sit anywhere in its hanging indent.
                new = not (tl < opt.indent or (f['item'] and tl > 0))
            else:
                # Against the leftmost continuation line on this page, not the
                # margin: list items wrap at a hanging indent, and some PDFs
                # jitter each line's start by several px -- the minimum
                # absorbs the jitter. It resets per page, so a page whose
                # margin was misjudged cannot carry a wrong base onward.
                new = tl - f['base'] >= opt.indent
            if (new and cur is not None and ml is None and f['bgap'] is not None
                    and f['last'] >= PROSE_LINE
                    and (f['bgap'] < 3 * opt.short or getattr(opt, 'ragged_prose', False))
                    and runs_on(cur[1], l['html'])):
                # Geometry said "new paragraph", but the text says the sentence
                # is still going: no closing punctuation, then lower case.
                # Dialogue with a hanging speaker name and inset blocks fool the
                # geometry; this does not. Only after a prose line -- long in
                # characters *and* reaching near the page's body measure. The
                # body measure, not the flow's own: an inset poem or a column
                # of index entries sets its own right edge, and its lines must
                # stay line by line. A ragged-right prose box looks exactly like
                # that poem, so rejoining it is opt-in (--ragged-prose).
                new = False
            if new:
                close(which)
                cur = f['cur'] = [l['size'], l['html']]
                f['item'], f['base'] = ml is not None, None
            else:
                f['base'] = tl if f['base'] is None else min(f['base'], tl)
                cur[1] = join_lines(cur[1], l['html'], evidence, p['n'], hyphen_decisions)
            f['gap'] = br - l['right']
            f['bgap'] = geo.get('body', (bl, br))[1] - l['right']
            f['last'] = len(txt_of(l['html']))

        # A footnote belongs to the page it sits on, so close it here rather
        # than waiting for the next heading or image -- left open it drifts
        # past the paragraph it annotates. The one case where it genuinely
        # continues is when the next page carries footnote lines too, so ask
        # that directly instead of guessing from the line width (a single-line
        # note is its own widest line, which makes width tell you nothing).
        nxt = pages[i + 1] if i + 1 < len(pages) else None
        if flows['fn']['cur'] and not (nxt and any(l['kind'] == 'note'
                                                   for l in nxt['lines'])):
            close('fn')
        if pending and flows['p']['cur'] is None:
            blocks.extend(pending)          # a page of pure endnotes
            pending.clear()
    boundary()

    def clean(s):
        s = re.sub(r'</([bi])>(\s*)<\1>', r'\2', s)     # one italic run, not one per line
        return re.sub(r'[ \t\xa0]{2,}', ' ', s.replace('­', '')).strip()

    out = ['<html><head><meta charset="utf-8"/><title>book</title>',
           f'<style>{CSS}</style></head><body>']
    counts = collections.Counter()
    for kind, t in blocks:
        if kind == 'img':
            out.append(f'<p class="fig"><img src="{t}"/></p>')
        elif kind == 'pre':
            out.append(f'<pre>{t}</pre>')
        else:
            t = clean(t)
            if not t:
                continue
            out.append({'p': f'<p>{t}</p>', 'q': f'<blockquote>{t}</blockquote>',
                        'fn': f'<p class="fn">{t}</p>'}.get(kind, f'<{kind}>{t}</{kind}>'))
        counts[kind] += 1
    out.append('</body></html>')
    return '\n'.join(out), counts, blocks


# -------------------------------------------------------------------- images
def shrink_images(work, out, max_px, quality):
    """Cap dimensions, and pick a format per image.

    Book scans arrive at print resolution -- a single 3719x5394 page image was
    12MB, four times what any e-ink screen can show. Line art and text crops
    quantize to a tiny palette; photographs do not, so they go to JPEG.
    """
    os.makedirs(out, exist_ok=True)
    magick = shutil.which('magick') or shutil.which('convert')
    renamed = {}
    for f in sorted(os.listdir(work)):
        if not f.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue
        src, dst = os.path.join(work, f), os.path.join(out, f)
        if not magick:
            shutil.copy(src, dst)
            continue
        try:
            k = int(run([magick, src, '-format', '%k', 'info:']).stdout.strip())
        except Exception:
            k = 99999
        if k <= 5000:
            run([magick, src, '-resize', f'{max_px}x{max_px}>', '-strip',
                 '-colors', '32', f'PNG8:{dst}'])
        else:
            jpg = os.path.splitext(f)[0] + '.jpg'
            run([magick, src, '-resize', f'{max_px}x{max_px}>', '-strip',
                 '-quality', str(quality), os.path.join(out, jpg)])
            if jpg != f:
                renamed[f] = jpg
    return renamed


# -------------------------------------------------------------------- verify
def verify(epub, plain_txt):
    """Compare the EPUB's words against the PDF's own text.

    In measured poppler 26.10 output, pdftotext drops every line-end hyphen,
    including compounds. This catches some split/unknown words, but cannot
    certify hyphen decisions or detect text omitted from the EPUB.
    """
    vocab = set(w.lower() for w in re.findall(WORD, open(plain_txt, encoding='utf8').read()))
    inline = re.compile(r'</?(?:span|i|b|em|strong|a|sup|sub|font|small|big|u)\b[^>]*>', re.I)
    z = zipfile.ZipFile(epub)
    words = []
    for n in sorted(z.namelist()):
        if n.endswith(('.html', '.xhtml')):
            t = z.read(n).decode('utf8', 'replace')
            t = re.sub(r'<head\b.*?</head>', ' ', t, flags=re.S | re.I)
            t = re.sub(r'<[^>]+>', ' ', inline.sub('', t))
            # unescape first, or &gt; in a code listing is counted as the word "gt"
            words += re.findall(WORD, html.unescape(t))
    bad = [w for w in words if w.lower() not in vocab]
    return len(words), bad


ITEM_START = re.compile(r'(?:[•●▪■◦‣·–-]|\(?(?:\d{1,3}|[a-zA-Z]|[ivxlcIVXLC]{1,6})[.)])\s')


def midsentence_breaks(blocks):
    """Paragraphs that stop without closing punctuation while another
    paragraph follows: one paragraph cut in two.

    The vocabulary check cannot see this -- every word is intact -- yet it is
    the failure a reader hits first. Deliberately blind to how the next
    paragraph starts: `runs_on` already repairs breaks before a lower-case
    word, so a check on that would only re-ask its question and could never
    fail. What it cannot repair -- "dos Estados" | "Unidos", or every line
    split by a bad --short -- shows here. Some hits are legitimate (verse,
    captions, table text), hence a rate, not a zero. Two kinds are not
    counted: paragraphs under ten words, since a cut paragraph holds at least
    a line of prose while captions, cells and verse lines are short; and a
    break before a list item, since unpunctuated list items are normal.
    """
    out, prev = [], None
    for kind, t in blocks:
        if kind not in ('p', 'q'):
            prev = prev if kind in ('fn', 'img') else None  # outside the flow
            continue
        s = re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', '', t)).replace('\xad', '')).strip()
        if (prev and s and len(prev.split()) >= 10 and not OPEN_END.search(prev)
                and not ITEM_START.match(s)):
            out.append((prev, s))
        prev = s
    return out


# ---------------------------------------------------------------------- main
def pick_levels(pages, body, opt):
    """Choose which display sizes become h1 and h2.

    Sizes used only a handful of times are structural (parts, chapters); a size
    used hundreds of times is a run-of-the-mill subhead and would swamp a
    table of contents.
    """
    cnt = collections.Counter()
    for _, grp in heading_groups(pages, body):
        cnt[max(l['max'] for l in grp)] += 1
    eligible = sorted((s for s, n in cnt.items() if 1 <= n <= opt.toc_max), reverse=True)
    return cnt, eligible


def load_vocab(work):
    try:
        txt = open(os.path.join(work, 'plain.txt'), encoding='utf8', errors='replace').read()
    except OSError:
        return frozenset()
    return frozenset(w.lower() for w in re.findall(WORD, txt))


def analyze(pages, body, opt, vocab=frozenset()):
    sizes = collections.Counter()
    fams = collections.Counter()
    for p in pages:
        for l in p['lines']:
            sizes[l['size']] += len(txt_of(l['html']))
            for r in l['runs']:
                fams[r[3]] += len(txt_of(r[4]))
    kinds = collections.Counter(l['kind'] for p in pages for l in p['lines'])
    cnt, eligible = pick_levels(pages, body, opt)

    print(f'pages: {len(pages)}   body font size: {body}')
    print(f'\nfont sizes by text volume: {sizes.most_common(10)}')
    mono = {f: n for f, n in fams.items() if MONO.search(f or '')}
    print(f'monospace families: {mono or "none"}')
    print(f'\nline kinds: {dict(kinds)}')
    print('\nsmall type below body size (tabular = has wide internal column gaps):')
    for sz in sorted({l['size'] for p in pages for l in p['lines'] if l['size'] < body},
                     reverse=True):
        g = [l for p in pages for l in p['lines'] if l['size'] == sz]
        multi = sum(1 for l in g if l['gap'] >= opt.table_gap and len(l['runs']) > 1)
        ex = next((txt_of(l['html']) for l in g if len(txt_of(l['html'])) > 40), '')
        print(f'  size {sz:>3}: {len(g):>5} lines, {multi * 100 // max(len(g), 1):>3}% tabular'
              f'  e.g. {ex[:58]}')
    print('  -> a size that is mostly tabular belongs in --table-sizes')
    print(f'\nheading sizes -> group count: {sorted(cnt.items(), reverse=True)}')
    print(f'TOC-eligible sizes (<= {opt.toc_max} groups): {eligible}')
    if eligible:
        print(f'  default: --h1-sizes {eligible[0]}'
              + (f' --h2-sizes {eligible[1]}' if len(eligible) > 1 else ''))
    print('\nheadings found (size, text):')
    shown = 0
    for p, grp in heading_groups(pages, body):
        top = max(l['max'] for l in grp)
        if top in eligible and shown < 40:
            print(f'  {top:>4}  {heading_text(grp, p["w"])[:70]}')
            shown += 1
    print('\nsample reconstructed paragraphs (check these read as prose):')
    h1s = {eligible[0]} if eligible else set()
    h2s = {eligible[1]} if len(eligible) > 1 else set()
    doc, counts, blocks = build_html(pages, body, opt, h1s, h2s, vocab)
    paras = [t for k, t in blocks if k == 'p' and len(txt_of(t)) > 300]
    for t in paras[len(paras) // 3:len(paras) // 3 + 2]:
        print('  * ' + txt_of(t)[:300] + ' ...')
    print(f'\nblocks: {dict(counts)}')


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('mode', choices=['analyze', 'convert'])
    ap.add_argument('pdf')
    ap.add_argument('-o', '--out', help='output .epub (convert mode)')
    ap.add_argument('--work', help='scratch dir (default: <pdf stem>-build next to output)')
    ap.add_argument('--title'); ap.add_argument('--author'); ap.add_argument('--lang')
    ap.add_argument('--cover-page', type=int, default=1,
                    help='PDF page rendered as the cover, 0 to skip')
    ap.add_argument('--h1-sizes', help='comma-separated font sizes that become h1')
    ap.add_argument('--h2-sizes', help='comma-separated font sizes that become h2')
    ap.add_argument('--toc-max', type=int, default=80,
                    help='a heading size used more times than this is a subhead, not TOC')
    ap.add_argument('--head-delta', type=int, default=2,
                    help='points above body size that count as display type')
    ap.add_argument('--quote-indent', type=int, default=40,
                    help='px inset marking small type as a block quote, not a footnote')
    ap.add_argument('--indent', type=int, default=6, help='px indent starting a paragraph')
    ap.add_argument('--short', type=int, default=18, help='px short of margin ending one')
    ap.add_argument('--ragged-prose', action='store_true',
                    help='rejoin a prose-length line (35+ chars) to a lower-case next line '
                         'even far from the margin: for ragged inset prose boxes; merges '
                         'free verse, so leave off for books with poetry')
    ap.add_argument('--table-gap', type=int, default=40,
                    help='px gap between runs marking a line as tabular; 0 disables')
    ap.add_argument('--table-sizes',
                    help='font sizes to render as images regardless of column gaps; '
                         'use when analyze shows a small size that is mostly tabular')
    ap.add_argument('--drop-pages',
                    help='PDF pages to omit, e.g. 9-12,540 (a printed contents page '
                         'is page-number noise once the book reflows)')
    ap.add_argument('--no-code', dest='code', action='store_false',
                    help='reflow monospace text instead of keeping it preformatted')
    ap.add_argument('--dpi', type=int, default=150, help='resolution for table crops')
    ap.add_argument('--max-image-px', type=int, default=1400)
    ap.add_argument('--jpeg-quality', type=int, default=82)
    ap.add_argument('--keep-first-image', action='store_true',
                    help='keep page 1 art inline (by default it duplicates the cover)')
    opt = ap.parse_args()

    need_tools()
    pdf = os.path.abspath(opt.pdf)
    stem = os.path.splitext(os.path.basename(pdf))[0]
    out = os.path.abspath(opt.out or (stem + '.epub'))
    work = os.path.abspath(opt.work or os.path.join(os.path.dirname(out), stem + '-build'))

    xml = extract(pdf, work)
    pages, body = parse(xml)
    if opt.drop_pages:
        skip = set()
        for part in opt.drop_pages.split(','):
            a, _, b = part.partition('-')
            skip.update(range(int(a), int(b or a) + 1))
        pages = [p for p in pages if p['n'] not in skip]
    dropped = strip_furniture(pages, body)
    classify(pages, body, opt)

    if opt.mode == 'analyze':
        print(f'(dropped {dropped} folio/running-head lines)')
        for p in pages:
            p['tables'] = []
        analyze(pages, body, opt, load_vocab(work))
        return

    made = crop_tables(pages, work, opt.dpi)
    cnt, eligible = pick_levels(pages, body, opt)
    h1s = ({int(x) for x in opt.h1_sizes.split(',')} if opt.h1_sizes
           else ({eligible[0]} if eligible else set()))
    h2s = ({int(x) for x in opt.h2_sizes.split(',')} if opt.h2_sizes
           else ({eligible[1]} if len(eligible) > 1 else set()))

    decisions = []
    doc, counts, blocks = build_html(pages, body, opt, h1s, h2s,
                                     hyphen_decisions=decisions)
    broken = midsentence_breaks(blocks)
    print(f'no-evidence hyphen decisions: {len(decisions)}')
    for d in decisions[:8]:
        print(f'  page {d["page"]}: {d["stem"]!r} / {d["head"]!r}: {d["action"]}')

    # page 1 art is nearly always the front cover; inline it and the reader
    # meets the same image twice
    first = pages[0]['imgs'][0] if pages and pages[0]['imgs'] else None
    if first and not opt.keep_first_image:
        doc = re.sub(rf'<p class="fig"><img src="{re.escape(first)}"/></p>\n?', '', doc, count=1)

    outdir = os.path.join(work, 'epub')
    os.makedirs(outdir, exist_ok=True)
    renamed = shrink_images(work, outdir, opt.max_image_px, opt.jpeg_quality)
    for old, new in renamed.items():
        doc = doc.replace(f'src="{old}"', f'src="{new}"')
    open(os.path.join(outdir, 'book.html'), 'w', encoding='utf8').write(doc)

    cmd = ['ebook-convert', 'book.html', out,
           '--level1-toc', '//h:h1', '--level2-toc', '//h:h2',
           '--page-breaks-before', '//h:h1|//h:h2',
           '--disable-font-rescaling']      # keep the sizes pinned in CSS above
    if opt.title:  cmd += ['--title', opt.title]
    if opt.author: cmd += ['--authors', opt.author]
    if opt.lang:   cmd += ['--language', opt.lang]
    if opt.cover_page:
        cover = os.path.join(outdir, 'cover.jpg')
        run(['pdftoppm', '-jpeg', '-r', '150', '-f', str(opt.cover_page),
             '-l', str(opt.cover_page), 'src.pdf', 'cover-tmp'], cwd=work)
        tmp = [f for f in os.listdir(work) if f.startswith('cover-tmp')]
        if tmp:
            shutil.move(os.path.join(work, tmp[0]), cover)
            cmd += ['--cover', 'cover.jpg']
    run(cmd, cwd=outdir)

    total, bad = verify(out, os.path.join(work, 'plain.txt'))
    size = os.path.getsize(out) / 1e6
    z = zipfile.ZipFile(out)
    ncx = [n for n in z.namelist() if n.endswith('.ncx')]
    toc = len(re.findall(r'<text>', z.read(ncx[0]).decode('utf8'))) if ncx else 0

    print(f'wrote {out}  ({size:.1f} MB)')
    print(f'blocks: {dict(counts)}')
    print(f'table crops rendered: {made}   TOC entries: {toc}')
    print(f'words: {total}   not in PDF vocabulary: {len(bad)} '
          f'({len(bad) / max(total, 1) * 100:.2f}%)')
    paras = counts['p'] + counts['q']
    print(f'paragraphs ending mid-sentence: {len(broken)} of {paras} '
          f'({len(broken) / max(paras, 1) * 100:.1f}%)')
    if paras and len(broken) / paras > 0.04:
        print('  ^ above ~4% means lines are still being cut into separate paragraphs; '
              'check --indent / --short against the line positions in book.xml')
        for a, b in broken[:5]:
            print(f'    ...{a[-40:]!r} | {b[:40]!r}...')
    if total and len(bad) / total > 0.01:
        print('  ^ above ~1% usually means words are still being split; '
              'check hyphen joining and the sample paragraphs in analyze mode')
        print('  most common:', collections.Counter(bad).most_common(8))
    if size > 25:
        print('  ^ over 25 MB: too big to email via Gmail. Lower --max-image-px, '
              'or use Send to Kindle on the web (200 MB limit).')


if __name__ == '__main__':
    main()
