"""
Capture the full content of a scrollable area in your current Safari tab.

Usage:
    scrollshot [options] output_path

By default, uses the scroller (an element, or the page itself) with the most
hidden scrollable content. Otherwise, provide one of:
    --click:            waits for you to click, then uses nearest scrollable ancestor
                        of the clicked element (or the page, if none)
    --selector <CSS>:   uses nearest scrollable ancestor of the element matching the
                        CSS selector (or the page, if none)

Output is PDF if the path ends in .pdf, else PNG. If PDF:
    --page a4 (default) | max (sizes each page to fit as much content as possible)
                        | <width>x<height> (mm)

Other options:
    --margin 0.2        fraction of visible height discarded at the top and bottom
                        of every slice (overlap trimming between slices)
    --keep-fixed        don't neutralise fixed/sticky elements after the first
                        slice (by default fixed ones are hidden and sticky ones
                        are made static, so they don't repeat in every slice)
    --keep-scrollbars   don't hide scrollbars during the capture (by default a
                        temporary style hides them, so overlay scrollbars don't
                        appear at different positions in every slice)
    --max-slices 200    safety cap for infinite-scroll pages

Requirements:
    pip install pillow img2pdf
    Safari > Develop > "Allow JavaScript from Apple Events"
    Give the terminal Screen Recording permission when prompted.
    Give the terminal Accessibility permission when prompted (optional). It is used to read
    the exact web-view frame, which makes sidebars, docked inspectors, page zoom
    and multiple monitors work. Without it, a less accurate heuristic is used.
"""
import argparse, io, json, math, os, subprocess, sys, tempfile, time
from PIL import Image

ap = argparse.ArgumentParser(description="Capture a scrollable area of the current Safari tab.")
grp = ap.add_mutually_exclusive_group()
grp.add_argument("--click", action="store_true",
                 help="click inside the scrollable area to choose it")
grp.add_argument("--selector", metavar="CSS", help="CSS selector of the scrollable area")
ap.add_argument("--margin", type=float, default=0.2,
                help="fraction of the visible height discarded at the top and "
                     "bottom of every slice (default 0.2; must be < 0.5)")
ap.add_argument("--page", default="a4",
                help="PDF page size: a4 (default), max (one page as big "
                     "as possible), or WxH in mm, e.g. 200x300")
ap.add_argument("--keep-fixed", action="store_true",
                help="don't hide fixed / unstick sticky elements after the first slice")
ap.add_argument("--keep-scrollbars", action="store_true",
                help="don't hide scrollbars during the capture")
ap.add_argument("--max-slices", type=int, default=200,
                help="abort after this many slices (default 200)")
ap.add_argument("out", metavar="OUTPUT", help="output file (.png or .pdf)")
a = ap.parse_args()
out = a.out
if not 0 <= a.margin < 0.5:
    sys.exit("--margin must be between 0 and 0.5")

# Shared JS helpers. `up(e)` returns the nearest scrollable ancestor of e (or e itself).
# html/body are mapped to document.scrollingElement, because page scrolling
# normally has overflow:visible and would otherwise never be detected.
SCROLL_JS = """
var DOC = document.scrollingElement || document.documentElement;
function isS(e) {
  if (e === document.documentElement || e === document.body)
    return DOC.scrollHeight > DOC.clientHeight + 1;
  return e.scrollHeight > e.clientHeight + 1 &&
         ['auto', 'scroll', 'overlay'].indexOf(getComputedStyle(e).overflowY) >= 0;
}
function up(e) {
  while (e && !isS(e)) e = e.parentElement;
  return (e === document.documentElement || e === document.body) ? DOC : e;
}
"""

# Temporary style that hides every scrollbar (standard property + WebKit
# pseudo-element). Removed again in cleanup().
HIDE_SB_JS = """
  if (!document.getElementById('__nosb')) {
    var s = document.createElement('style');
    s.id = '__nosb';
    s.textContent = '*{scrollbar-width:none !important}' +
                    '*::-webkit-scrollbar{display:none !important}';
    (document.head || document.documentElement).appendChild(s);
  }
  return 1;
"""


def run_js(src, fatal=True):
    """Run JavaScript in Safari's front tab, return the result string."""
    r = subprocess.run(
        ["osascript", "-e", "on run argv",
         "-e", 'tell application "Safari" to do JavaScript (item 1 of argv) '
               "in current tab of front window",
         "-e", "end run", src], capture_output=True, text=True)
    if r.returncode != 0:
        if not fatal:
            return ""
        err = r.stderr.strip()
        low = err.lower()
        if "apple events" in low and "javascript" in low:
            hint = "Enable Safari > Develop > Allow JavaScript from Apple Events."
        elif "can't get window" in low or "-1728" in err:
            hint = "Is there a Safari window open?"
        elif "exception" in low or "typeerror" in low:
            hint = ("The page's JavaScript threw an error. The page may have "
                    "navigated or reloaded during the capture; try again.")
        else:
            hint = "Unexpected AppleScript failure; see the message above."
        sys.exit(f"AppleScript error: {err}\n{hint}")
    return r.stdout.strip()


def js(code, pre=False, _fatal=True, **vars):
    """Run `code` (a function body using `return`) in the page; returns decoded JSON.
    Keyword args are injected as JS variables. pre=True adds SCROLL_JS helpers."""
    decl = "".join(f"var {k}={json.dumps(v)};" for k, v in vars.items())
    src = ("JSON.stringify((function(){" + decl + (SCROLL_JS if pre else "") +
           code + "})())")
    res = run_js(src, fatal=_fatal)
    if res in ("", "missing value"):
        return None
    return json.loads(res)


# Exact frame of Safari's web view via the Accessibility API (global screen
# points, top-left origin: the same space screencapture -R uses).
JXA = """
(function () {
  var se = Application('System Events');
  var w = se.processes.byName('Safari').windows[0];
  function find(el, d) {
    if (d > 9) return null;
    var kids;
    try { kids = el.uiElements(); } catch (e) { return null; }
    for (var i = 0; i < kids.length; i++) {
      var k = kids[i], role;
      try { role = k.role(); } catch (e) { continue; }
      if (role === 'AXWebArea') return k;
      var f = find(k, d + 1);
      if (f) return f;
    }
    return null;
  }
  var wa = find(w, 0);
  if (!wa) return '';
  var p = wa.position(), s = wa.size();
  return JSON.stringify({x: p[0], y: p[1], w: s[0], h: s[1]});
})()
"""


def webview_frame():
    try:
        r = subprocess.run(["osascript", "-l", "JavaScript", "-e", JXA],
                           capture_output=True, text=True, timeout=20)
        if r.returncode != 0 or not r.stdout.strip():
            return None
        f = json.loads(r.stdout)
        return f if f["w"] > 0 and f["h"] > 0 else None
    except Exception:
        return None


def cleanup():
    """Restore everything we touched in the page (best effort, never fatal)."""
    js("""
      var ns = document.getElementById('__nosb');
      if (ns) ns.remove();
      var o = window.__orig, el = window.__t;
      (window.__fix || []).forEach(function (p) {
        if (p[1] === null) p[0].removeAttribute('style'); else p[0].setAttribute('style', p[1]);
      });
      window.__fix = [];
      if (o && el) {
        el.scrollTop = o.st;
        window.scrollTo(o.px, o.py);
        var de = document.documentElement;
        [[el, o.e], [de, o.d]].forEach(function (q) {
          if (q[1]) q[0].style.setProperty('scroll-behavior', q[1].v, q[1].p);
          else q[0].style.removeProperty('scroll-behavior');
        });
      }
      window.__t = null; window.__orig = null;
      return 1;
    """, _fatal=False)


subprocess.run(["osascript", "-e", 'tell application "Safari" to activate'])
time.sleep(0.5)

# ---- find the scrollable element and store it in window.__t ----
if a.click:
    js("""
      window.__t = null; window.__done = false;
      window.__h = function (ev) {
        ev.preventDefault(); ev.stopPropagation();
        window.__t = up(ev.target); window.__done = true;
        document.removeEventListener('click', window.__h, true);
      };
      document.addEventListener('click', window.__h, true);
      return 1;
    """, pre=True)
    print("In Safari, click anywhere inside the scrollable area (60 s)...")
    for _ in range(120):
        time.sleep(0.5)
        if js("return window.__done;"):
            break
    else:
        js("document.removeEventListener('click', window.__h, true); return 1;")
        sys.exit("No click received.")
    if not js("return !!window.__t;"):
        sys.exit("Nothing scrollable under that click. Click inside the area "
                 "and try again, or run without --click to auto-detect.")
elif a.selector:
    ok = js("""
      var e = document.querySelector(sel);
      if (!e) return 'notfound';
      e = up(e);
      window.__t = e;
      return e ? 'ok' : 'noscroll';
    """, pre=True, sel=a.selector)
    if ok == "notfound":
        sys.exit("Selector not found. Try --click, or run without options to auto-detect.")
    if ok == "noscroll":
        sys.exit("That element and its ancestors don't scroll.")
else:
    ok = js("""
      var best = null, bs = 1;
      if (DOC.scrollHeight - DOC.clientHeight > bs) {
        bs = DOC.scrollHeight - DOC.clientHeight; best = DOC;
      }
      document.querySelectorAll('*').forEach(function (e) {
        if (e === document.documentElement || e === document.body) return;
        if (isS(e) && e.scrollHeight - e.clientHeight > bs) {
          bs = e.scrollHeight - e.clientHeight; best = e;
        }
      });
      window.__t = best; return !!best;
    """, pre=True)
    if not ok:
        sys.exit("No scrollable element found. Try --click.")


def alive():
    return js("return !!window.__t && document.documentElement.contains(window.__t);")


def settle(target):
    """Scroll to target and wait until scrollTop/scrollHeight stop changing.
    Returns (scrollTop, scrollHeight, clientHeight) as actually reached."""
    js("window.__t.scrollTop = target; return 1;", target=target)
    prev = None
    for _ in range(10):
        time.sleep(0.35)
        cur = js("var e = window.__t; return [e.scrollTop, e.scrollHeight, e.clientHeight];")
        if cur == prev:
            return cur
        prev = cur
    return prev


try:
    # Hide scrollbars BEFORE measuring anything: with classic scrollbars this
    # changes the content width (and possibly the wrapping / scrollHeight), so
    # all geometry below must be measured in the hidden state.
    if not a.keep_scrollbars:
        js(HIDE_SB_JS)
        time.sleep(0.3)

    # Remember the original state, force instant scrolling, scroll the area into view.
    info = js("""
      var el = window.__t, de = document.documentElement;
      function sv(n) {
        var v = n.style.getPropertyValue('scroll-behavior');
        return v ? {v: v, p: n.style.getPropertyPriority('scroll-behavior')} : null;
      }
      window.__orig = {st: el.scrollTop, px: window.scrollX, py: window.scrollY,
                       e: sv(el), d: sv(de)};
      el.style.setProperty('scroll-behavior', 'auto', 'important');
      de.style.setProperty('scroll-behavior', 'auto', 'important');
      var isDoc = el === (document.scrollingElement || de);
      if (!isDoc) el.scrollIntoView({block: 'start'});
      el.scrollTop = 0;
      return {sh: el.scrollHeight, ch: el.clientHeight, isDoc: isDoc};
    """)
    print(f"Found scroll area ({'page' if info['isDoc'] else 'element'}): "
          f"content {info['sh']} px, visible {info['ch']} px")
    time.sleep(0.6)

    g = js("""
      var el = window.__t, isDoc = el === (document.scrollingElement || document.documentElement);
      var de = document.documentElement, left, top, cw, ch;
      if (isDoc) { left = 0; top = 0; cw = de.clientWidth; ch = de.clientHeight; }
      else {
        var r = el.getBoundingClientRect();
        left = r.left + el.clientLeft; top = r.top + el.clientTop;
        cw = el.clientWidth; ch = el.clientHeight;
      }
      return {left: left, top: top, cw: cw, ch: ch, isDoc: isDoc,
              iw: window.innerWidth, ih: window.innerHeight,
              sx: window.screenX, sy: window.screenY,
              ow: window.outerWidth, oh: window.outerHeight};
    """)
    if (g["cw"] <= 0 or g["ch"] <= 0 or g["left"] < -1 or g["top"] < -1 or
            g["left"] + g["cw"] > g["iw"] + 1 or g["top"] + g["ch"] > g["ih"] + 1):
        sys.exit(f"The scroll area ({g['cw']:.0f}x{g['ch']:.0f} px) doesn't fit entirely "
                 f"in the viewport ({g['iw']}x{g['ih']} px). Enlarge the Safari window "
                 "or zoom out (Cmd -) and try again.")

    # ---- map the area to screen points ----
    fr = webview_frame()
    zoom = None
    if fr:
        zoom = fr["w"] / g["iw"]
        if not 0.2 < zoom < 6:
            fr = None
    if fr:
        if abs(fr["h"] / g["ih"] - zoom) > 0.02 * zoom:
            print("warning: web view frame and viewport disagree in height; "
                  "the region may be offset.")
        X0, Y0 = fr["x"], fr["y"]
    else:
        print("warning: couldn't read the web view frame (grant the terminal "
              "Accessibility permission). Using a heuristic that assumes 100% zoom, "
              "no sidebar and no docked inspector.")
        zoom = 1.0
        X0 = g["sx"] + (g["ow"] - g["iw"]) / 2
        Y0 = g["sy"] + (g["oh"] - g["ih"])

    fx, fy = X0 + g["left"] * zoom, Y0 + g["top"] * zoom
    fw, fh = g["cw"] * zoom, g["ch"] * zoom
    # Round the capture region inward to whole points, then derive everything
    # else from the rounded numbers so slices line up exactly.
    x0, y0 = math.ceil(fx - 1e-3), math.ceil(fy - 1e-3)
    w0 = math.floor(fx + fw + 1e-3) - x0
    h0 = math.floor(fy + fh + 1e-3) - y0
    if w0 <= 0 or h0 <= 0:
        sys.exit("Computed an empty capture region.")
    d = (y0 - fy) / zoom        # CSS px between the area's top edge and the region's top
    hc = h0 / zoom              # CSS px of content covered by the region
    m = hc * a.margin           # CSS px trimmed from top/bottom of each slice
    print(f"Region: x={x0} y={y0} w={w0} h={h0} (zoom {zoom:.2f})")

    strips, covered, n = [], 0.0, 0   # covered = content position of next row needed
    scale = 1.0
    with tempfile.TemporaryDirectory() as tmp:
        while True:
            if n >= a.max_slices:
                sys.exit(f"Stopped after {n} slices (--max-slices). Is this an infinite scroller?")
            if not alive():
                sys.exit("The scroll area disappeared (page navigated or re-rendered).")
            path = os.path.join(tmp, f"s{n}.png")
            for _ in range(3):
                st, sh, ch = settle(max(covered - m, 0))
                subprocess.run(["screencapture", "-x", "-R",
                                f"{x0},{y0},{w0},{h0}", path], check=True)
                after = js("return window.__t.scrollTop;")
                if abs(after - st) < 0.5:
                    break
            else:
                sys.exit("The content kept moving while capturing; try again.")

            img = Image.open(path).convert("RGB")
            scale = img.height / hc               # image px per CSS px
            at_end = st + ch >= sh - 0.5
            top_px = max(0, round((covered - st - d) * scale))
            bot_px = img.height if at_end else round((hc - m) * scale)
            if bot_px <= top_px:
                sys.exit("Empty slice; try a smaller --margin.")
            strips.append(img.crop((0, top_px, img.width, bot_px)))
            print(f"kept content {covered:.0f} -> "
                  f"{(sh if at_end else st + d + hc - m):.0f} of {sh} px")
            n += 1
            if at_end:
                break

            if n == 1 and not a.keep_fixed:
                # Fixed elements would repeat in every slice and sticky ones would
                # overlap content: hide the former, make the latter static.
                cnt = js("""
                  var t = window.__t, k = 0;
                  window.__fix = window.__fix || [];
                  document.querySelectorAll('*').forEach(function (e) {
                    if (e === t || e.contains(t)) return;
                    var cs = getComputedStyle(e), pos = cs.position;
                    if (pos === 'sticky' || pos === '-webkit-sticky') {
                      if (!t.contains(e)) return;
                      window.__fix.push([e, e.getAttribute('style')]);
                      e.style.setProperty('position', 'relative', 'important');
                      e.style.setProperty('top', 'auto', 'important');
                      e.style.setProperty('bottom', 'auto', 'important');
                      k++;
                    } else if (pos === 'fixed' && cs.visibility !== 'hidden') {
                      var r = e.getBoundingClientRect();
                      if (r.width > 0 && r.height > 0 && r.bottom > T && r.top < T + H &&
                          r.right > L && r.left < L + W) {
                        window.__fix.push([e, e.getAttribute('style')]);
                        e.style.setProperty('visibility', 'hidden', 'important');
                        k++;
                      }
                    }
                  });
                  return k;
                """, T=g["top"], H=g["ch"], L=g["left"], W=g["cw"])
                if cnt:
                    print(f"(neutralised {cnt} fixed/sticky element(s) for later slices)")

            new_cov = st + d + hc - m
            if new_cov <= covered:
                sys.exit("No scroll progress; try a smaller --margin.")
            covered = new_cov
finally:
    cleanup()

res = Image.new("RGB", (strips[0].width, sum(s.height for s in strips)))
yy = 0
for s in strips:
    res.paste(s, (0, yy)); yy += s.height

if out.lower().endswith(".pdf"):
    try:
        import img2pdf
    except ImportError:
        sys.exit("PDF output needs img2pdf:  pip install img2pdf")

    def png_bytes(im):
        b = io.BytesIO(); im.save(b, "PNG"); return b.getvalue()

    pg = a.page.lower()
    sizes = {"a4": (210, 297)}
    if pg == "max":
        # one page sized like the capture (1 CSS px = 1 pt), split only when
        # exceeding the ~14400 pt page limit of PDF viewers
        max_rows = int(14000 * scale)
        pages = [png_bytes(res.crop((0, t, res.width, min(t + max_rows, res.height))))
                 for t in range(0, res.height, max_rows)]
        dpi = 72 * scale
        layout = img2pdf.get_fixed_dpi_layout_fun((dpi, dpi))
    else:
        try:
            pw_mm, ph_mm = sizes[pg] if pg in sizes else map(float, pg.split("x"))
        except ValueError:
            sys.exit("--page must be a4, max, or WxH in mm (e.g. 200x300)")
        pw, ph = img2pdf.mm_to_pt(pw_mm), img2pdf.mm_to_pt(ph_mm)
        rows = int(res.width * ph / pw)              # image rows per page
        bg = res.getpixel((0, res.height - 1))       # pad last page with edge colour
        pages = []
        for t in range(0, res.height, rows):
            chunk = res.crop((0, t, res.width, min(t + rows, res.height)))
            if chunk.height < rows:
                padded = Image.new("RGB", (res.width, rows), bg)
                padded.paste(chunk, (0, 0)); chunk = padded
            pages.append(png_bytes(chunk))
        layout = img2pdf.get_layout_fun(pagesize=(pw, ph), fit=img2pdf.FitMode.into)
    with open(out, "wb") as f:
        f.write(img2pdf.convert(pages, layout_fun=layout))
    print(f"saved {out} ({len(pages)} page(s), page={pg}, lossless)")
else:
    res.save(out)
    print(f"saved {out} ({res.width}x{res.height})")