#!/usr/bin/env python3
"""Turn page text read from the Claude directory developer portal into two datasets.

Input: a JSON file, a list of {"id", "name", "status", "overview": <Overview tab innerText>,
"usage": <Usage tab innerText>}. "usage"/"overview" may be empty for a plugin that is not live.

Usage: parse_usage.py INPUT.json OUT_DIR
Writes OUT_DIR/plugins.json (one row per submission) and OUT_DIR/install_sources.json
(one row per plugin x install path). Exit 0 ok · 2 bad input.
"""
import json
import os
import re
import sys

GLYPHS = re.compile(r"[-]")  # icon-font glyphs the portal puts between labels and values


def num(s):
    if s is None:
        return None
    s = s.replace(",", "").replace("+", "")
    try:
        return float(s) if "." in s else int(s)
    except ValueError:
        return None


def pct(s):
    return round(float(s.rstrip("%")) / 100, 4) if s else None


def clean(t):
    return re.sub(r"\n+", "\n", GLYPHS.sub("", t or ""))


def grab(pattern, t):
    m = re.search(pattern, t)
    return m.group(1) if m else None


def parse(item):
    u, o = clean(item.get("usage")), clean(item.get("overview"))
    where = o.split("TOP INSTALL")[0][o.find("Where it’s installed"):] if "Where it’s installed" in o else ""
    share = {k: float(v) / 100 for k, v in re.findall(r"\n(Claude\.ai|Cowork|Claude Code)\n([\d.]+)%", where)}
    row = {
        "plugin": item["name"], "status": item.get("status"),
        "rank": num(grab(r"Directory rank[^#]{0,12}#([\d,]+)", o)),
        "installs_all_time": num(grab(r"\n([\d,]+) all time\nInstallers", u)),
        "installers": num(grab(r"Installers\n([\d,]+)\n", u)),
        "active_accounts_28d": num(grab(r"Active accounts\n([\d,]+)\nOver 28", u)),
        "active_accounts_7d": num(grab(r"Over 28 days · ([\d,]+) over 7", u)),
        "uses_30d": num(grab(r"Uses\n([\d,]+)\n", u)),
        "sessions_30d": num(grab(r"\n([\d,]+) sessions\n", u)),
        "organizations": grab(r"Organizations\n([^\n]+)\n", u),
        "uninstalls": num(grab(r"Uninstalls\n([\d,]+)\n", u)),
        "share_claude_ai": share.get("Claude.ai"), "share_cowork": share.get("Cowork"),
        "share_claude_code": share.get("Claude Code"),
        "retention_next_day": pct(grab(r"NEXT DAY\n([\d.]+%)", u)),
        "retention_7d": pct(grab(r"WITHIN 7 DAYS\n([\d.]+%)", u)),
        "load_error_rate": pct(grab(r"LOAD ERROR RATE\n([\d.]+%)", u)),
        "data_through": grab(r"Data through ([^\n]+)\n", u),
    }
    sources = []
    i = u.find("Path\tInstalls\tAccounts reached")
    if i >= 0:
        block = u[i:u.find("Version adoption", i)].split("\n")[1:]
        for k in range(0, len(block) - 2, 3):
            cells = block[k + 2].split("\t")
            if len(cells) >= 3:
                sources.append({"plugin": item["name"], "surface": block[k + 1], "path": block[k],
                                "installs_30d": num(cells[1]), "accounts_reached": num(cells[2])})
    return row, sources


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    try:
        items = json.load(open(argv[0], encoding="utf-8"))
        assert isinstance(items, list) and all("name" in x for x in items)
    except (OSError, ValueError, AssertionError) as e:
        print(f"bad input: {e}", file=sys.stderr)
        return 2
    rows, sources = [], []
    for it in items:
        r, s = parse(it)
        rows.append(r)
        sources.extend(s)
    rows.sort(key=lambda r: -(r["installs_all_time"] or 0))
    os.makedirs(argv[1], exist_ok=True)
    json.dump(rows, open(os.path.join(argv[1], "plugins.json"), "w"), indent=1)
    json.dump(sources, open(os.path.join(argv[1], "install_sources.json"), "w"), indent=1)
    print(f"{len(rows)} plugins, {len(sources)} install-path rows, "
          f"{sum(r['installs_all_time'] or 0 for r in rows):,} installs all time")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
