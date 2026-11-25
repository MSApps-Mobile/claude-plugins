#!/usr/bin/env python3
"""
Trello I6sF6fRf - every link inside running text on docs/index.html must be
told apart from the text around it by something other than colour (WCAG 2.2
SC 1.4.1, axe `link-in-text-block`). The SOSA subtitle link shipped with
`text-decoration:none` and a colour 1.01:1 from its sentence.

Closed list of what this script reads:
  - one file: the HTML given by --page (default docs/index.html), UTF-8.
  - <style> blocks of that file: plain rules whose selector is a chain of
    compound selectors (tag, .class, #id, joined by spaces or `>`). Rules with a
    pseudo-class/element or attribute selector, and everything inside @-rules
    (@media ...), are ignored.
  - the inline `style` attribute of each <a>.

A link is "inline in running text" when the nearest enclosing block element
(p, li, div, td, dd, dt, blockquote, section, header, footer, h1-h6) holds
letters or digits outside any <a>. Rows that only hold links and a separator
(e.g. `A · B`), standalone buttons and card title links are not running text.
An inline link passes when its resolved text-decoration is not `none`
(inline style beats rules; then specificity, then source order; no rule = the
browser default, underlined).

What it does NOT do: it does not render the page, so it cannot see a rule set
by JavaScript, a pseudo-class state (:hover/:focus), or a border-bottom used
as the cue; those do not count as passing. The real-browser computed-style
proof (390x844 and 1440x900) is recorded on the card's PR, not run in CI.

Run: python3 scripts/check-inline-links-underlined.py --page docs/index.html
Exit 0 = every inline link is underlined; 1 = at least one is not, or unparseable.
"""

import argparse
import re
import sys
from html.parser import HTMLParser

BLOCKS = {"p", "li", "div", "td", "dd", "dt", "blockquote", "section", "header",
          "footer", "h1", "h2", "h3", "h4", "h5", "h6", "article", "main", "body"}
VOID = {"br", "img", "hr", "meta", "link", "input", "area", "base", "col", "embed",
        "source", "track", "wbr"}
WORD = re.compile(r"\w")


def parse_rules(css):
    """Return [(selector_chain, specificity, order, decl_dict)] for plain rules."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    rules, i, depth, start, order = [], 0, 0, 0, 0
    while i < len(css):
        c = css[i]
        if c == "{":
            if depth == 0:
                head = css[start:i].strip()
                body_start = i + 1
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                body = css[body_start:i]
                start = i + 1
                if not head.startswith("@"):
                    decls = {}
                    for d in body.split(";"):
                        if ":" in d:
                            k, v = d.split(":", 1)
                            decls[k.strip().lower()] = v.strip().lower()
                    for sel in head.split(","):
                        sel = sel.strip()
                        if not sel or re.search(r"[:\[\]*+~]", sel):
                            continue
                        chain = re.split(r"\s*>\s*|\s+", sel)
                        spec = (sum(p.count("#") for p in chain),
                                sum(p.count(".") for p in chain),
                                sum(1 for p in chain if re.match(r"[a-z]", p)))
                        order += 1
                        rules.append((chain, spec, order, decls))
        i += 1
    return rules


def compound_matches(compound, node):
    m = re.fullmatch(r"([a-z][a-z0-9]*)?((?:[.#][\w-]+)*)", compound)
    if not m:
        return False
    tag, rest = m.group(1), m.group(2)
    if tag and tag != node["tag"]:
        return False
    for kind, name in re.findall(r"([.#])([\w-]+)", rest):
        if kind == "." and name not in node["classes"]:
            return False
        if kind == "#" and name != node["id"]:
            return False
    return True


def chain_matches(chain, path):
    """path = ancestor nodes, outermost first, last = the element itself."""
    if not compound_matches(chain[-1], path[-1]):
        return False
    j = len(chain) - 2
    for node in reversed(path[:-1]):
        if j < 0:
            break
        if compound_matches(chain[j], node):
            j -= 1
    return j < 0


def resolved_decoration(link, path, rules):
    inline = link["style"]
    m = re.search(r"text-decoration(?:-line)?\s*:\s*([^;]+)", inline)
    if m:
        return m.group(1).strip().lower()
    best = None
    for chain, spec, order, decls in rules:
        val = decls.get("text-decoration", decls.get("text-decoration-line"))
        if val is None or not chain_matches(chain, path):
            continue
        if best is None or (spec, order) > best[0]:
            best = ((spec, order), val)
    return best[1] if best else "underline"  # UA default for <a href>


class _Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []      # open nodes
        self.css = []
        self.links = []      # dicts: path, style, block, text
        self.in_style = False
        self.in_script = False
        self.link_depth = 0

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        node = {"tag": tag, "classes": (a.get("class") or "").split(),
                "id": a.get("id") or "", "style": a.get("style") or "",
                "outside_text": False, "is_block": tag in BLOCKS}
        if tag == "style":
            self.in_style = True
        if tag == "script":
            self.in_script = True
        if tag == "a" and "href" in a:
            self.link_depth += 1
            link = dict(node, path=[dict(n) for n in self.stack] + [node],
                        block=next((n for n in reversed(self.stack) if n["is_block"]), None))
            self.links.append(link)
        if tag not in VOID:
            self.stack.append(node)

    def handle_endtag(self, tag):
        if tag == "style":
            self.in_style = False
        if tag == "script":
            self.in_script = False
        for k in range(len(self.stack) - 1, -1, -1):
            if self.stack[k]["tag"] == tag:
                if tag == "a" and self.link_depth:
                    self.link_depth -= 1
                del self.stack[k:]
                break

    def handle_data(self, data):
        if self.in_style:
            self.css.append(data)
            return
        if self.in_script or self.link_depth or not WORD.search(data):
            return
        for n in reversed(self.stack):
            if n["is_block"]:
                n["outside_text"] = True  # text outside any <a> in this block
                break
        # text also counts for every enclosing block up to the body
        for n in self.stack:
            if n["is_block"]:
                n["outside_text"] = True


def audit(page):
    """Return (problems, inline_links_checked)."""
    p = _Page()
    p.feed(page)
    p.close()
    rules = parse_rules("\n".join(p.css))
    problems, checked = [], 0
    for link in p.links:
        block = link["block"]
        if block is None or not block["outside_text"]:
            continue
        checked += 1
        deco = resolved_decoration(link, link["path"], rules)
        if "underline" not in deco:
            problems.append(f"link in running text has text-decoration '{deco}' "
                            f"(told apart by colour only): <a href=...> inside <{block['tag']}"
                            + (f" class=\"{' '.join(block['classes'])}\"" if block["classes"] else "") + ">")
    return problems, checked


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--page", default="docs/index.html")
    args = ap.parse_args(argv)
    with open(args.page, encoding="utf-8") as f:
        problems, checked = audit(f.read())
    for pr in problems:
        print(f"FAIL {args.page}: {pr}")
    if problems:
        return 1
    if checked == 0:
        print(f"FAIL {args.page}: no inline links found in running text (parser drift?)")
        return 1
    print(f"OK {args.page}: {checked} inline links in running text, all underlined")
    return 0


if __name__ == "__main__":
    sys.exit(main())
