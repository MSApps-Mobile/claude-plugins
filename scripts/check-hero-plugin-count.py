#!/usr/bin/env python3
"""
Trello rkdB5zOu - the hero "Plugins" number on docs/index.html must equal the
number of plugin cards the page renders.

The hero describes this catalogue page, so it counts the `.card` entries the
reader can see (not the manifest, which may list more). The number is static so
no-JS readers and crawlers see it; this check stops it drifting.

Closed list of what this script reads:
  - one file: the HTML given by --page (default docs/index.html), UTF-8.
  - from that file only, the markup a no-JS reader sees: comments, <template>
    contents and <script>/<style> bodies are dropped first (stdlib html.parser,
    see visible_markup), then two patterns are matched on what remains:
      * the exact start tag `<div class="card">` (class must be exactly "card",
        no other attributes, no single quotes) -> one plugin card each;
      * the exact hero pair `<div class="stat-num">N</div>` followed by
        `<div class="stat-label">Plugins</div>`; exactly one must exist.

What it does NOT read or count:
  - anything the page builds with JavaScript at runtime (a card created by a
    script is never counted; a no-JS reader does not see it either);
  - card or hero markup variants (`<div class='card'>`, `<div class="card big">`,
    `<section class="card">`, extra attributes on the card tag): not counted;
  - the plugin manifest (.claude-plugin/marketplace.json), the plugin folders,
    and any other page: never opened.

Run: python3 scripts/check-hero-plugin-count.py --page docs/index.html
Exit 0 = hero number equals the card count; 1 = mismatch or unparseable page.
"""

import argparse
import html
import re
import sys
from html.parser import HTMLParser

CARD = re.compile(r'<div\s+class="card"\s*>')
HERO = re.compile(
    r'<div\s+class="stat-num"\s*>\s*(\d+)\s*</div>\s*<div\s+class="stat-label"\s*>\s*Plugins\s*</div>'
)


class _Visible(HTMLParser):
    """Re-emit only the markup a no-JS reader sees.

    Dropped: comments, declarations, processing instructions, the contents of
    any <template> (nesting counted), and the bodies of <script> and <style>.
    Text is escaped on the way out, so `&lt;div class="card"&gt;` in visible text
    cannot be mistaken for a card tag.
    """

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []
        self.template_depth = 0
        self.raw_tag = None  # "script" or "style" while inside its body

    def _visible(self):
        return self.template_depth == 0 and self.raw_tag is None

    def handle_starttag(self, tag, attrs):
        if tag == "template":
            self.template_depth += 1
        elif tag in ("script", "style") and self._visible():
            self.raw_tag = tag
        if self._visible():
            self.out.append(self.get_starttag_text())

    def handle_endtag(self, tag):
        if self._visible():
            self.out.append(f"</{tag}>")
        if tag == "template" and self.template_depth:
            self.template_depth -= 1
        elif tag == self.raw_tag:
            self.raw_tag = None

    def handle_data(self, data):
        if self._visible():
            self.out.append(html.escape(data, quote=False))


def visible_markup(page):
    """Return the page's markup with comments, <template> and script/style bodies removed."""
    parser = _Visible()
    parser.feed(page)
    parser.close()
    return "".join(parser.out)


def audit(page):
    """Return (problems, hero, cards)."""
    visible = visible_markup(page)
    heroes = HERO.findall(visible)
    cards = len(CARD.findall(visible))
    if len(heroes) != 1:
        return [f"expected exactly one hero 'Plugins' stat, found {len(heroes)}"], None, cards
    hero = int(heroes[0])
    if cards == 0:
        return ["no .card plugin entries found on the page"], hero, cards
    if hero != cards:
        return [f"hero says {hero} plugins but the page renders {cards} .card entries"], hero, cards
    return [], hero, cards


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--page", default="docs/index.html")
    args = ap.parse_args(argv)
    with open(args.page, encoding="utf-8") as f:
        problems, hero, cards = audit(f.read())
    for p in problems:
        print(f"FAIL {args.page}: {p}")
    if problems:
        return 1
    print(f"OK {args.page}: hero {hero} == {cards} .card entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
