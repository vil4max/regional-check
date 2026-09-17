#!/usr/bin/env python3
"""Render the redesign canvas boards (boards/*.dc.html) to static PNGs.

Supports the subset of the canvas format used here: {{dotted.path}} holes,
<sc-for>, <sc-if>, <dc-import>, and data-props defaults. Animations are not
rendered; ColdStart.dc.html takes a `frame` prop for static frames.

Requirements: Python 3.11+, beautifulsoup4, playwright (with Chromium), node.
Usage: python3 render.py                 # all boards in exports.json
       python3 render.py Main.dc.html    # one board
"""
import argparse
import tempfile
import json, re, subprocess, pathlib
from bs4 import BeautifulSoup, NavigableString, Tag

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE / "boards"
ASSETS = HERE / "assets"
BLOBS = {k: (ASSETS / v).as_uri() for k, v in json.loads((ASSETS / "blobs.json").read_text()).items() if k.startswith("/_blob/")}

HOLE = re.compile(r"\{\{\s*([^}]+?)\s*\}\}")

def parse(name):
    src = (ROOT / name).read_text()
    soup = BeautifulSoup(src, "html.parser")
    script = soup.find("script", attrs={"data-dc-script": True})
    props = json.loads(script["data-props"]) if script.has_attr("data-props") else {}
    return soup, script.string, props

def run_logic(js, props):
    harness = """
class DCLogic { constructor(p){ this.props=p; this.state={}; } setState(){} }
%s
const c = new Component(%s);
process.stdout.write(JSON.stringify(c.renderVals(), (k,v)=> typeof v==='function'? null : v));
""" % (js, json.dumps(props))
    r = subprocess.run(["node", "-e", harness], capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(r.stderr)
    return json.loads(r.stdout)

def lookup(scope, path):
    path = path.strip()
    if path in ("true", "false"):
        return path == "true"
    if re.fullmatch(r"-?\d+(\.\d+)?", path):
        return float(path)
    if path.startswith(("'", '"')):
        return path[1:-1]
    cur = scope
    for part in path.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return None
    return cur

def interp(text, scope):
    def rep(m):
        v = lookup(scope, m.group(1))
        return "" if v is None else (str(int(v)) if isinstance(v, float) and v.is_integer() else str(v))
    return HOLE.sub(rep, text)

def whole(text, scope):
    m = HOLE.fullmatch(text.strip())
    return lookup(scope, m.group(1)) if m else text

def render_children(node, scope, soup):
    out = []
    for child in list(node.children):
        out.extend(render_node(child, scope, soup))
    return out

def kebab_to_camel(s):
    parts = s.split("-")
    return parts[0] + "".join(p.title() for p in parts[1:])

def render_node(node, scope, soup):
    if isinstance(node, NavigableString):
        if node.__class__.__name__ in ("Comment", "Doctype"):
            return []
        return [NavigableString(interp(str(node), scope))]
    if not isinstance(node, Tag):
        return []
    if node.name == "sc-for":
        items = whole(node["list"], scope) or []
        alias = node["as"]
        out = []
        for i, it in enumerate(items):
            s = dict(scope); s[alias] = it; s["$index"] = i
            out.extend(render_children(node, s, soup))
        return out
    if node.name == "sc-if":
        return render_children(node, scope, soup) if whole(node["value"], scope) else []
    if node.name == "dc-import":
        props = {}
        for k, v in node.attrs.items():
            if k in ("name",) or k.startswith("hint-"):
                continue
            props[kebab_to_camel(k)] = whole(v, scope)
        frag = render_board(node["name"] + ".dc.html", props)
        return list(BeautifulSoup(frag, "html.parser").children)
    new = soup.new_tag(node.name)
    for k, v in node.attrs.items():
        if isinstance(v, list):
            v = " ".join(v)
        new[k] = interp(v, scope)
    for c in render_children(node, scope, soup):
        new.append(c)
    return [new]

USED = set()
def render_board(name, overrides=None):
    USED.add(name)
    soup, js, props = parse(name)
    defaults = {k: v.get("default") for k, v in props.items() if not k.startswith("$") and isinstance(v, dict) and "default" in v}
    defaults.update(overrides or {})
    scope = run_logic(js, defaults)
    xdc = soup.find("x-dc")
    root = [c for c in xdc.children if isinstance(c, Tag) and c.name != "helmet"][0]
    rendered = render_node(root, scope, soup)[0]
    return str(rendered)

def page(name):
    soup, _, props = parse(name)
    USED.clear()
    body = render_board(name)
    style = "\n".join(parse(u)[0].find("x-dc").find("helmet").find("style").string for u in sorted(USED, key=lambda u: u != name))
    for blob, uri in BLOBS.items():
        body = body.replace(blob, uri)
    w, h = props["$preview"]["width"], props["$preview"]["height"]
    html = f"<!doctype html><html><head><meta charset='utf-8'><style>{style}</style></head><body>{body}</body></html>"
    return html, w, h

def main():
    ap = argparse.ArgumentParser(description="Render canvas boards to PNG (2x).")
    ap.add_argument("boards", nargs="*", help="board files, e.g. Main.dc.html (default: all in exports.json)")
    ap.add_argument("--out", default=str(HERE.parent), help="output folder (default: docs/design/redesign)")
    args = ap.parse_args()
    exports = json.loads((HERE / "exports.json").read_text())
    names = args.boards or list(exports)
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path(tempfile.mkdtemp())
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch()
        for n in names:
            html, w, h = page(n)
            f = tmp / n.replace(".dc.html", ".html")
            f.write_text(html)
            pg = b.new_page(viewport={"width": w, "height": h}, device_scale_factor=2)
            pg.goto(f.as_uri())
            pg.wait_for_timeout(300)
            target = out / exports.get(n, n.replace(".dc.html", ".png"))
            pg.screenshot(path=str(target))
            pg.close()
            print("rendered", n, "->", target)
        b.close()


if __name__ == "__main__":
    main()
