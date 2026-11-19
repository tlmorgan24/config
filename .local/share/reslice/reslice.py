"""
Re-paginate a PDF to a different page size, preserving all content.

Usage:
    reslice [options] input.pdf output.pdf

The input pages are treated as one continuous vertical strip (stacked in
order), scaled to the target page width, and cut into pages of the target
height. By default every page is exactly the target size.

With -A / -B / -C, each cut is instead placed in a blank horizontal gap
(between text lines, paragraphs or blocks) near the nominal cut point, so lines
and images are not sliced through. The page width is still exactly the target
width, but heights then vary: a page is shorter than the target if its cut is
found above the nominal point, and taller if below it. If the last page would
be shorter than the target height, it is padded to the target height, with the
extra space filled with the colour of the bottom edge of the input (normally
the page background).

Content is embedded, not re-rendered: vector graphics stay vector, text stays
selectable, and raster images keep their original pixels. (Links and
bookmarks are not carried over.)

Options:
    --page a4 (default) | a3 | a5 | letter | legal | <width>x<height> (mm)
                        the width, and the nominal height, of each page
    --margin 0          blank margin in mm around the content on each page
    -A, --after 0       fraction of the nominal page height to search for a gap
                        *below* the nominal cut point (pages may be taller by
                        up to this much)
    -B, --before 0      fraction of the nominal page height to search for a gap
                        *above* the nominal cut point (pages may be shorter
                        by up to this much)
    -C, --around N      shorthand for -A N -B N (explicit -A / -B override it)
                        With a window on both sides, the tallest blank gap in
                        the whole window wins; ties go to the one nearest the
                        nominal cut. By default (-A 0 -B 0) no search is done:
                        every page is exactly the nominal height, as with a
                        plain page-size conversion. Pass -B, -A or -C to look
                        for better break points.
    --tol 8             grey-level difference (0-255) within which a row counts
                        as blank. A row is blank if it is one flat colour, or
                        if it matches the page's background profile (so grey
                        margins, borders and sidebars around the content are fine)
    --dpi 50            resolution used for gap detection

Requirements:
    pip install pymupdf numpy
"""
import argparse
import os
import sys

try:
    try:
        import pymupdf as fitz  # current PyMuPDF name
    except ImportError:
        import fitz  # older PyMuPDF versions
    import numpy as np
except ImportError:
    sys.exit("Requires PyMuPDF and NumPy:  pip install pymupdf numpy")

MM = 72 / 25.4  # points per millimetre
PAGE_SIZES = {
    "a3": (297, 420),
    "a4": (210, 297),
    "a5": (148, 210),
    "letter": (215.9, 279.4),
    "legal": (215.9, 355.6),
}


def parse_page(spec):
    spec = spec.lower()
    if spec in PAGE_SIZES:
        return PAGE_SIZES[spec]
    try:
        w, h = (float(v) for v in spec.split("x"))
        if w > 0 and h > 0:
            return w, h
    except ValueError:
        pass
    sys.exit(f"--page must be one of {', '.join(PAGE_SIZES)} or WxH in mm (e.g. 200x300)")


def build_profile(doc, offsets, dpi, tol):
    """Return (blank, ypos): for every low-res pixel row of the whole strip,
    whether the row is uniform (blank) and its y position in strip points."""
    blank, ypos = [], []
    for i, page in enumerate(doc):
        pix = page.get_pixmap(dpi=dpi, colorspace=fitz.csGRAY, alpha=False)
        a = np.frombuffer(pix.samples, np.uint8).reshape(pix.h, pix.stride)[:, :pix.w]
        a = a.astype(np.int16)
        # A row is blank if it is a single flat colour, OR if it matches the page's background
        # profile: the per-column 80th-percentile brightness (20th for dark pages), i.e. what each
        # column looks like when it holds no content. The second test handles backgrounds that are
        # not flat across the width, e.g. grey margins and border lines around a white page in a
        # screenshot. A percentile is used rather than a median so that columns crossed by ink in
        # over half the rows (barlines, braces, table borders) still get a clean background
        # reference.
        q = 80 if np.median(a) >= 128 else 20
        flat = (a.max(axis=1) - a.min(axis=1)) <= tol
        typical = np.abs(a - np.percentile(a, q, axis=0)).max(axis=1) <= tol
        blank.append(flat | typical)
        ypos.append(offsets[i] + (np.arange(pix.h) + 0.5) * page.rect.height / pix.h)
    return np.concatenate(blank), np.concatenate(ypos)


def find_gap(blank, ypos, lo, hi, target):
    """Best place to cut between strip positions lo and hi: the centre of the
    tallest run of blank rows (nearest `target` on ties). None if there is none."""
    i0, i1 = np.searchsorted(ypos, [lo, hi])
    seg = blank[i0:i1]
    if not seg.any():
        return None
    d = np.diff(np.concatenate(([0], seg.astype(np.int8), [0])))
    starts, ends = np.flatnonzero(d == 1), np.flatnonzero(d == -1)
    lens = ends - starts
    centres = (ypos[i0 + starts] + ypos[i0 + ends - 1]) / 2
    best = np.flatnonzero(lens == lens.max())
    return float(centres[best[np.argmin(np.abs(centres[best] - target))]])


def main():
    ap = argparse.ArgumentParser(
        description="Re-paginate a PDF to a different page size, preserving all content.")
    ap.add_argument("--page", default="a4",
                    help="a4 (default), a3, a5, letter, legal, or WxH in mm")
    ap.add_argument("--margin", type=float, default=0.0,
                    help="blank margin in mm around the content (default 0)")
    ap.add_argument("-B", "--before", dest="before", type=float,
                    default=None, metavar="FRAC",
                    help="fraction of page height to search above the nominal cut "
                         "(default 0: no search)")
    ap.add_argument("-A", "--after", type=float, default=None, metavar="FRAC",
                    help="fraction of page height to search below the nominal cut "
                         "(default 0: no search)")
    ap.add_argument("-C", "--around", type=float, default=None, metavar="FRAC",
                    help="shorthand for -A FRAC -B FRAC")
    ap.add_argument("--tol", type=int, default=8,
                    help="grey-level tolerance for a blank row (default 8)")
    ap.add_argument("--dpi", type=int, default=50,
                    help="resolution for gap detection (default 50)")
    ap.add_argument("input", metavar="INPUT", help="input PDF")
    ap.add_argument("output", metavar="OUTPUT", help="output PDF")
    a = ap.parse_args()

    if not a.output.lower().endswith(".pdf"):
        sys.exit("output path must end with .pdf")
    if os.path.abspath(a.input) == os.path.abspath(a.output):
        sys.exit("output must be a different file from the input")
    before = a.before if a.before is not None else (a.around if a.around is not None else 0.0)
    after = a.after if a.after is not None else (a.around if a.around is not None else 0.0)
    if before < 0 or after < 0 or before >= 1:
        sys.exit("-A must be >= 0 and -B must be between 0 and 1")
    smart = before > 0 or after > 0

    pw_mm, ph_mm = parse_page(a.page)
    pw, ph, m = pw_mm * MM, ph_mm * MM, a.margin * MM
    if 2 * m >= min(pw, ph):
        sys.exit("--margin is too large for this page size")

    try:
        src = fitz.open(a.input)
    except Exception as e:
        sys.exit(f"Couldn't open {a.input}: {e}")
    if src.needs_pass:
        sys.exit("The input PDF is password protected.")
    if len(src) == 0:
        sys.exit("The input PDF has no pages.")

    # Stack the source pages into one virtual strip.
    heights = [p.rect.height for p in src]
    widths = [p.rect.width for p in src]
    offsets = [sum(heights[:i]) for i in range(len(src))]
    total = sum(heights)
    W = max(widths)                      # narrower pages are centred
    scale = (pw - 2 * m) / W             # strip points -> output points
    H = (ph - 2 * m) / scale             # strip height covered by one output page

    # Choose cut points.
    cuts = [0.0]
    missed = 0
    if smart and total > H:
        blank, ypos = build_profile(src, offsets, a.dpi, a.tol)
    while total - cuts[-1] > H * (1 + after) + 1e-3:
        target = cuts[-1] + H                   # nominal cut point
        cut = None
        if smart:
            cut = find_gap(blank, ypos, target - H * before,
                           target + H * after, target)
        if cut is None or cut <= cuts[-1] + 1:
            cut = target
            missed += smart
        cuts.append(cut)
    cuts.append(total)

    # Build the output pages by clipping and placing the original pages.
    out = fitz.open()
    for top, bot in zip(cuts, cuts[1:]):
        page_h = (bot - top) * scale + 2 * m
        if bot == total and page_h < ph:
            # Short last page: pad to the nominal height, matching the background colour at the
            # bottom edge of the input.
            page_h = ph
            last = src[-1]
            r = last.rect
            px = last.get_pixmap(dpi=72, alpha=False,
                                 clip=fitz.Rect(r.x0, r.y1 - 2, r.x0 + 2, r.y1))
            rgb = [c / 255 for c in px.pixel(0, 0)[:3]]
            page = out.new_page(width=pw, height=page_h)
            page.draw_rect(page.rect, color=None, fill=rgb)
        else:
            page = out.new_page(width=pw, height=page_h)
        for i, sp in enumerate(src):
            lo = max(top, offsets[i])
            hi = min(bot, offsets[i] + heights[i])
            if hi - lo < 0.01:
                continue
            xoff = (W - widths[i]) / 2
            clip = fitz.Rect(0, lo - offsets[i], widths[i], hi - offsets[i])
            dest = fitz.Rect(m + xoff * scale, m + (lo - top) * scale,
                             m + (xoff + widths[i]) * scale, m + (hi - top) * scale)
            page.show_pdf_page(dest, src, i, clip=clip)

    out.set_metadata(src.metadata or {})
    out.save(a.output, garbage=3, deflate=True)
    if missed:
        print(f"warning: no blank gap found for {missed} of {len(cuts) - 2} cut(s); "
              f"those fell back to the nominal position. Try a larger -A/-B/-C "
              f"or a higher --tol.", file=sys.stderr)
    hs = [p.rect.height / MM for p in out]
    print(f"saved {a.output}: {len(src)} page(s) -> {len(out)} page(s), "
          f"{pw_mm:g} mm wide, heights {min(hs):.0f}-{max(hs):.0f} mm "
          f"(nominal {ph_mm:g}, {'smart' if smart else 'fixed'} cuts)")


if __name__ == "__main__":
    main()