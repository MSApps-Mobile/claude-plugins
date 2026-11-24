#!/usr/bin/env python3
"""
Trello IMjjDwAS - the catalogue page must list every marketplace plugin that
should be shown, and nothing the marketplace does not publish.

Measured 2026-11-21: marketplace.json had 38 plugins, docs/index.html rendered
30 cards, and nothing compared them. Plugins that are deliberately not shown
are recorded, with a reason, in scripts/catalogue-hidden-plugins.json.

Fails (exit 1) when:
  (a) a marketplace plugin that is not allow-listed has no card,
  (b) a card links a plugin that marketplace.json does not publish,
  (c) an allow-list entry names a plugin that is no longer in marketplace.json,
  (d) an allow-listed plugin also has a card (the entry outlived the decision),
  (e) an allow-list entry has no reason, or the page has no cards (vacuity).

The marketplace is read with the loader in check-marketplace-coverage.py
(manifest_names / manifest_sources); it is not parsed a second time here.

Run: python3 scripts/check-catalogue-matches-marketplace.py [--root .]
"""

import argparse
import importlib.util
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

_spec = importlib.util.spec_from_file_location(
    "marketplace_coverage", os.path.join(HERE, "check-marketplace-coverage.py")
)
mc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mc)

PAGE = os.path.join("docs", "index.html")
HIDDEN = os.path.join("scripts", "catalogue-hidden-plugins.json")

CARD = re.compile(r'<div\s+class="card"\s*>(.*?)(?=<div\s+class="card"\s*>|</section>|\Z)', re.S)
LINK = re.compile(r'class="card-link"\s+href="[^"]*?/plugins/([^/"]+)/README\.md"')


def card_slugs(html):
    """One slug per .card block; None for a card with no plugin docs link."""
    out = []
    for m in CARD.finditer(html):
        link = LINK.search(m.group(1))
        out.append(link.group(1) if link else None)
    return out


def load_hidden(path):
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    return dict(data.get("hidden", {}))


def audit(page_html, root, hidden):
    problems = []
    names = mc.manifest_names(root)
    sources = mc.manifest_sources(root)
    dir_to_name = {d: n for n, d in sources.items() if d}

    slugs = card_slugs(page_html)
    if not slugs:
        return ["VACUITY: no .card entries found on the page, so nothing was measured."], {}
    shown = set()
    for i, slug in enumerate(slugs, 1):
        if slug is None:
            problems.append(f"card #{i} has no plugins/<slug>/README.md docs link.")
            continue
        name = slug if slug in names else dir_to_name.get(slug)
        if name is None:
            problems.append(
                f"card links plugin {slug!r}, which is not in .claude-plugin/marketplace.json. "
                f"Remove the card or publish the plugin."
            )
        else:
            shown.add(name)

    for n in names:
        if n not in shown and n not in hidden:
            problems.append(
                f"marketplace plugin {n!r} has no card on {PAGE} and is not in {HIDDEN}. "
                f"Add a card, or record why it is hidden."
            )

    for n, reason in hidden.items():
        if n not in names:
            problems.append(f"{HIDDEN} lists {n!r}, which is no longer in marketplace.json - remove the stale entry.")
        elif n in shown:
            problems.append(f"{HIDDEN} lists {n!r}, but it has a card - remove the entry or the card.")
        if not str(reason).strip():
            problems.append(f"{HIDDEN}[{n!r}] has no reason written.")

    return problems, {"manifest": len(names), "cards": len(slugs), "hidden": len(hidden)}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=".")
    ap.add_argument("--page", default=None)
    ap.add_argument("--hidden", default=None)
    args = ap.parse_args(argv)
    page = args.page or os.path.join(args.root, PAGE)
    hidden_path = args.hidden or os.path.join(args.root, HIDDEN)
    with open(page, encoding="utf-8") as fh:
        html = fh.read()
    problems, summary = audit(html, args.root, load_hidden(hidden_path))
    for p in problems:
        print("::error::" + str(p).replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A"))
    if problems:
        print(f"FAIL catalogue vs marketplace: {len(problems)} problem(s)")
        return 1
    print(
        f"OK catalogue vs marketplace: {summary['manifest']} plugins = "
        f"{summary['cards']} cards + {summary['hidden']} hidden"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
