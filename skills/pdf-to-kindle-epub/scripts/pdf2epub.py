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
import argparse, collections, html, os, re, shutil, subprocess, sys, zipfile
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
    if not os.path.exists(src):
        shutil.copy(pdf, src)
    xml = os.path.join(work, 'book.xml')
    if not os.path.exists(xml):
        run(['pdftohtml', '-xml', '-enc', 'UTF-8', '-nodrm', 'src.pdf', 'book'], cwd=work)
    txt = os.path.join(work, 'plain.txt')
    if not os.path.exists(txt):
        # pdftotext dehyphenates correctly; used later as ground truth
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

    Bucketing on `top` splits a small-caps or drop-cap run onto its own line
    ("D" + "avid" as two lines), because a different font size sits at a
    different top. Centres line up where tops do not.
    """
    out = []
    for top, height, left, width, size, fam, txt in sorted(runs):
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
    res = []
    for ln in out:
        runs = sorted(ln['runs'])
        sizes = collections.Counter()
        for left, w, sz, fam, t in runs:
            sizes[sz] += max(len(txt_of(t)), 1)
        gaps = [runs[i + 1][0] - (runs[i][0] + runs[i][1]) for i in range(len(runs) - 1)]
        res.append({
            'left': runs[0][0],
            'right': max(r[0] + r[1] for r in runs),
            'size': sizes.most_common(1)[0][0],
            'max': max(r[2] for r in runs),
            'mono': all(MONO.search(r[3] or '') for r in runs),
            'gap': max(gaps) if gaps else 0,          # widest internal gap = column split
            'html': ''.join(r[4] for r in runs),
            'runs': runs,
            'c': ln['c'], 'h': ln['h'],
        })
    return res


def parse(xml):
    root = ET.parse(xml).getroot()
    fonts, pages = {}, []
    for pg in root.findall('page'):
        for f in pg.findall('fontspec'):          # ids persist across pages
            fonts[f.get('id')] = (int(f.get('size')), f.get('family') or '')
        runs, imgs = [], []
        for el in pg:
            if el.tag == 'text':
                sz, fam = fonts.get(el.get('font'), (0, ''))
                runs.append((int(el.get('top')), int(el.get('height')),
                             int(el.get('left')), int(el.get('width')),
                             sz, fam, inner(el)))
            elif el.tag == 'image':
                imgs.append(el.get('src').split('/')[-1])
        pages.append({'n': int(pg.get('number')),
                      'w': int(pg.get('width')), 'h': int(pg.get('height')),
                      'lines': lines_of(runs), 'imgs': imgs})
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

    A folio is a line that is just a number. A running head is a top- or
    bottom-margin line whose text (digits removed) repeats across many pages.
    Both become noise in a reflowed book.
    """
    edge = collections.Counter()
    for p in pages:
        real = [l for l in p['lines'] if txt_of(l['html'])]
        for l in real[:1] + real[-1:]:
            key = re.sub(r'\d+', '', txt_of(l['html'])).strip().lower()
            if key:
                edge[key] += 1
    repeated = {k for k, v in edge.items() if v >= max(8, len(pages) * 0.15)}
    dropped = 0
    for p in pages:
        keep = []
        real = [l for l in p['lines'] if txt_of(l['html'])]
        for i, l in enumerate(real):
            t = txt_of(l['html'])
            key = re.sub(r'\d+', '', t).strip().lower()
            atedge = i < 1 or i >= len(real) - 1
            # Only digits, and only in body type: a part opener's roman numeral
            # is set in display type and must survive.
            if atedge and l['size'] <= body and re.fullmatch(r'[\divxlcdm]{1,8}', t.lower()):
                dropped += 1
                continue
            if atedge and key in repeated and l['size'] <= body:
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


def heading_text(lines):
    """Join a heading group, moving a standalone numeral next to its label.

    Work at the *run* level, not the line level. A chapter numeral is set so
    large that it shares a visual line with the label or the title, so joining
    whole lines yields "CAPITULOV" or "TRISTEZA NAO E DEPRESSAOCAPITULOIX".
    Splitting by run recovers "CAPITULO IX — TRISTEZA NAO E DEPRESSAO".
    """
    parts = []
    for l in lines:
        for left, w, sz, fam, t in l['runs']:
            s = txt_of(t)
            if s:
                parts.append((sz, s))
    # bare page numbers leak in from a printed contents page
    parts = [(sz, s) for sz, s in parts if not s.isdigit()]
    if not parts:
        return ''
    nums = [s for sz, s in parts if NUMERAL.match(s)]
    if not nums:
        return ' '.join(s for _, s in parts)
    labels = [s for sz, s in parts if s not in nums and len(s.split()) == 1 and s.isupper()]
    rest = [s for sz, s in parts if s not in nums and s not in labels]
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
            name = f'tbl-{p["n"]}-{i}.png'
            path = os.path.join(work, name)
            if not os.path.exists(path):
                top = min(l['c'] - l['h'] for l in grp) - 10
                bot = max(l['c'] + l['h'] for l in grp) + 10
                left = min(l['left'] for l in grp) - 10
                right = max(l['right'] for l in grp) + 10
                run(['pdftoppm', '-png', '-gray', '-r', str(dpi),
                     '-f', str(p['n']), '-l', str(p['n']),
                     '-x', str(max(0, int(left * scale))),
                     '-y', str(max(0, int(top * scale))),
                     '-W', str(max(1, int((right - left) * scale))),
                     '-H', str(max(1, int((bot - top) * scale))),
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


def hyphen_join(prev, nxt, vocab):
    """Join across a real hyphen-minus at a line end.

    Drop the hyphen only if the PDF's own text knows the joined word --
    pdftotext dehyphenates correctly, so its vocabulary is the oracle. That
    keeps "produc-/tive" -> "productive" while leaving a genuine compound
    like "self-/interest" hyphenated.
    """
    stem = re.findall(WORD, html.unescape(re.sub(r'<[^>]+>', '', prev[:-1])))
    head = re.findall(WORD, html.unescape(re.sub(r'<[^>]+>', '', nxt)))
    if stem and head and (stem[-1] + head[0]).lower() in vocab:
        return prev[:-1] + nxt
    return prev + nxt


def build_html(pages, body, opt, h1s, h2s, vocab=frozenset()):
    blocks = []
    flows = {'p': {'cur': None, 'gap': None}, 'q': {'cur': None, 'gap': None},
             'fn': {'cur': None, 'gap': None}}
    pending = []            # footnotes wait for the paragraph they interrupted
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

    def boundary():
        flush_code()
        for w in ('fn', 'q', 'p'):
            close(w)

    groups = {id(l): g for _, g in heading_groups(pages, body) for l in g}
    emitted = set()

    for i, p in enumerate(pages):
        for src in p['imgs']:
            boundary()
            blocks.append(('img', src))

        # margins per flow: a page with both a quote and a footnote has two
        # different left margins at the same font size
        geo = {}
        for k in ('body', 'quote', 'note'):
            g = [l for l in p['lines'] if l['kind'] == k]
            if g:
                geo[k] = (collections.Counter(l['left'] for l in g).most_common(1)[0][0],
                          max(l['right'] for l in g))

        for l in p['lines']:
            kind = l['kind']
            if kind == 'table':
                r = next((r for r in p['tables'] if id(l) in r['lines']), None)
                if r and not r['done']:
                    boundary()
                    blocks.append(('img', r['src']))
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
                blocks.append((tag, html.escape(heading_text(lines))))
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
            new = (cur is None
                   or l['left'] - bl >= opt.indent          # first line is indented
                   or prev is None or prev >= opt.short)    # previous line fell short
            if new:
                close(which)
                cur = f['cur'] = [l['size'], l['html']]
            else:
                prev, nxt = cur[1].rstrip(), l['html'].lstrip()
                if prev.endswith('\xad'):
                    # soft hyphen: join without a space. Left to a converter
                    # this becomes "impor tante".
                    cur[1] = prev[:-1] + nxt
                elif prev.endswith('-'):
                    cur[1] = hyphen_join(prev, nxt, vocab)
                else:
                    cur[1] = prev + ' ' + nxt
            f['gap'] = br - l['right']

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

    pdftotext joins hyphenated line breaks correctly, so its vocabulary is a
    good oracle: a spike in unknown words means words are still being split.
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
    for _, grp in heading_groups(pages, body):
        top = max(l['max'] for l in grp)
        if top in eligible and shown < 40:
            print(f'  {top:>4}  {heading_text(grp)[:70]}')
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

    doc, counts, _ = build_html(pages, body, opt, h1s, h2s, load_vocab(work))

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
    if total and len(bad) / total > 0.01:
        print('  ^ above ~1% usually means words are still being split; '
              'check hyphen joining and the sample paragraphs in analyze mode')
        print('  most common:', collections.Counter(bad).most_common(8))
    if size > 25:
        print('  ^ over 25 MB: too big to email via Gmail. Lower --max-image-px, '
              'or use Send to Kindle on the web (200 MB limit).')


if __name__ == '__main__':
    main()
