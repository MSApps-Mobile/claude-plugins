#!/usr/bin/env python3
"""
Trello rkdB5zOu - the hero "Plugins" number on docs/index.html must equal the
number of plugin cards the page renders.

The hero describes this catalogue page, so it counts the `.card` entries the
reader can see (not the manifest, which may list more). The number is static so
no-JS readers and crawlers see it; this check stops it drifting.

Run: python3 scripts/check-hero-plugin-count.py --page docs/index.html
Exit 0 = hero number equals the card count; 1 = mismatch or unparseable page.
"""

import argparse
import re
import sys

CARD = re.compile(r'<div\s+class="card"\s*>')
HERO = re.compile(
    r'<div\s+class="stat-num"\s*>\s*(\d+)\s*</div>\s*<div\s+class="stat-label"\s*>\s*Plugins\s*</div>'
)


def audit(html):
    """Return (problems, hero, cards)."""
    heroes = HERO.findall(html)
    cards = len(CARD.findall(html))
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
