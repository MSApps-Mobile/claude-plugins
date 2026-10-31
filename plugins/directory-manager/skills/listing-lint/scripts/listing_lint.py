#!/usr/bin/env python3
"""Check Claude plugins against the Anthropic directory's listing and submission rules.

Usage: listing_lint.py PLUGIN_DIR [PLUGIN_DIR ...] [--json]
       listing_lint.py --repo REPO_ROOT [--json]   (every plugins/*/ with a manifest)

Exit codes: 0 no errors · 1 at least one error · 2 bad usage or unreadable input.
Warnings never change the exit code.
"""
import json
import os
import re
import sys

LISTING_URL_FIELDS = ["documentationUrl", "supportUrl", "privacyPolicyUrl", "termsOfServiceUrl"]
LEGACY_FIELDS = {"privacy_policy": "privacyPolicyUrl", "terms_of_service": "termsOfServiceUrl"}
# A launcher that downloads a package at run time must name an exact version
# (claude.com/docs/plugins/pre-submission-checklist: "npx, bunx, pnpm dlx, yarn dlx, uvx,
# pipx run, and uv run all count ... Run uv run with --locked or --frozen").
LAUNCHERS = {"npx", "bunx", "uvx", "pnpx"}
DLX_LAUNCHERS = {"pnpm", "yarn"}  # '<cmd> dlx <pkg>'
ALLOWED_VARS = re.compile(r"^(CLAUDE_PLUGIN_ROOT|CLAUDE_PLUGIN_DATA|user_config\.[A-Za-z_][A-Za-z0-9_]*)$")
VAR_RE = re.compile(r"\$\{([^}]+)\}")
MIN_README_WORDS = 40


def _load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _pinned(pkg):
    """npm 'name@1.2.3' / '@scope/name@1.2.3', python 'name==1.2.3' count as pinned."""
    if "==" in pkg:
        return True
    at = pkg.rfind("@")
    return at > 0 and re.match(r"^\d", pkg[at + 1:]) is not None


def _first_positional(args):
    """The first argument that is not a flag ('--yes', '-p', ...)."""
    return next((a for a in args if not a.startswith("-")), "")


def _subcommand_at(args, word):
    """Index of the first `word` in args, or -1. Global options may sit before a
    subcommand ('uv --directory X run ...'), so the position is not fixed."""
    return args.index(word) if word in args else -1


def _check_pkg(pkg, label, server_name, issues):
    if not _pinned(pkg):
        issues.append(("error", f"mcp:{server_name}", f"unpinned {label} launcher: '{pkg or '?'}' (pin an exact version, e.g. tsx@4.19.2 or name==1.2.3)"))


def _check_uvx(args, label, server_name, issues):
    if "--from" in args:
        k = args.index("--from") + 1
        pkg = args[k] if k < len(args) else ""
        if not _pinned(pkg):
            issues.append(("error", f"mcp:{server_name}", f"{label} --from {pkg or '?'} is not pinned (use name==X.Y.Z)"))
        return
    _check_pkg(_first_positional(args), label, server_name, issues)


def check_launcher(server_name, cfg, issues):
    cmd = os.path.basename(str(cfg.get("command", "")))
    args = [str(a) for a in cfg.get("args", [])]
    if cmd == "uvx":
        _check_uvx(args, "uvx", server_name, issues)
    elif cmd in LAUNCHERS:
        _check_pkg(_first_positional(args), cmd, server_name, issues)
    elif cmd in DLX_LAUNCHERS:
        k = _subcommand_at(args, "dlx")
        if k >= 0:
            _check_pkg(_first_positional(args[k + 1:]), f"{cmd} dlx", server_name, issues)
    elif cmd == "pipx":
        k = _subcommand_at(args, "run")
        if k >= 0:
            rest = args[k + 1:]
            if "--spec" in rest:
                j = rest.index("--spec") + 1
                _check_pkg(rest[j] if j < len(rest) else "", "pipx run --spec", server_name, issues)
            else:
                _check_pkg(_first_positional(rest), "pipx run", server_name, issues)
    elif cmd == "uv":
        k = _subcommand_at(args, "tool")
        if k >= 0 and args[k + 1:k + 2] == ["run"]:  # 'uv tool run' is uvx
            _check_uvx(args[k + 2:], "uv tool run", server_name, issues)
        elif _subcommand_at(args, "run") >= 0 and not ({"--locked", "--frozen"} & set(args)):
            issues.append(("error", f"mcp:{server_name}", "'uv run' without --locked or --frozen (the directory requires a locked run)"))


def lint_plugin(pdir):
    issues = []
    name = os.path.basename(os.path.normpath(pdir))
    mpath = os.path.join(pdir, ".claude-plugin", "plugin.json")
    manifest = {}
    if not os.path.exists(mpath):
        issues.append(("error", "plugin.json", "missing .claude-plugin/plugin.json (directory lists it for Claude Code only)"))
    else:
        try:
            manifest = _load_json(mpath)
        except (OSError, ValueError) as e:
            return name, [("error", "plugin.json", f"cannot parse: {e}")]
        name = manifest.get("name", name)
        for field in ("name", "description"):
            if not str(manifest.get(field, "")).strip() or str(manifest.get(field)).strip() in ("---", "TODO"):
                issues.append(("error", "plugin.json", f"'{field}' is missing or a placeholder"))
        if not (manifest.get("author") or {}).get("name"):
            issues.append(("error", "plugin.json", "'author.name' is missing"))
        if not manifest.get("license") and not os.path.exists(os.path.join(pdir, "LICENSE")):
            issues.append(("error", "plugin.json", "no 'license' field and no LICENSE file (directory will not list it)"))
        if "displayName" not in manifest:
            issues.append(("warn", "plugin.json", "no 'displayName' (listing shows the kebab-case name)"))
        if not manifest.get("homepage"):
            issues.append(("warn", "plugin.json", "no 'homepage'"))
        kws = [k for k in manifest.get("keywords", []) if k != "sosa-agents"]
        if not kws:
            issues.append(("warn", "plugin.json", "no descriptive 'keywords' (listing Discovery shows none)"))
        for f in LISTING_URL_FIELDS:
            if not manifest.get(f):
                issues.append(("warn", "plugin.json", f"no '{f}' (listing shows 'No value')"))
        for old, new in LEGACY_FIELDS.items():
            if old in manifest:
                issues.append(("error", "plugin.json", f"'{old}' is not read by the directory; rename it to '{new}'"))
        desc = str(manifest.get("description", ""))
        if len(desc) > 300:
            issues.append(("warn", "plugin.json", f"description is {len(desc)} chars; keep the short description under ~300"))

    readme = next((os.path.join(pdir, f) for f in os.listdir(pdir) if f.lower() == "readme.md"), None) if os.path.isdir(pdir) else None
    if not readme:
        issues.append(("error", "README", "no README.md (required to publish; it is the listing's description)"))
    else:
        with open(readme, encoding="utf-8") as f:
            words = len(re.findall(r"\w+", f.read()))
        if words < MIN_README_WORDS:
            issues.append(("error", "README", f"README has {words} words; the directory needs at least {MIN_README_WORDS}"))

    user_config = manifest.get("userConfig", {}) or {}
    mcp_path = os.path.join(pdir, ".mcp.json")
    if os.path.exists(mcp_path):
        try:
            mcp = _load_json(mcp_path)
        except (OSError, ValueError) as e:
            issues.append(("error", ".mcp.json", f"cannot parse: {e}"))
            mcp = {}
        for sname, cfg in (mcp.get("mcpServers") or {}).items():
            check_launcher(sname, cfg, issues)
            for var in sorted(set(VAR_RE.findall(json.dumps(cfg)))):
                if ALLOWED_VARS.match(var):
                    if var.startswith("user_config.") and var.split(".", 1)[1] not in user_config:
                        issues.append(("error", f"mcp:{sname}", f"${{{var}}} has no matching userConfig entry in plugin.json"))
                    continue
                issues.append(("error", f"mcp:{sname}", f"reads environment variable ${{{var}}}; ask for it through userConfig and use ${{user_config.{var}}}"))
            headers = json.dumps(cfg.get("headers", {}))
            if re.search(r"(Bearer|Basic)\s+[A-Za-z0-9+/=_\-]{12,}", headers):
                issues.append(("error", f"mcp:{sname}", "a literal credential sits in the headers"))

    for key, spec in user_config.items():
        if not isinstance(spec, dict):
            issues.append(("error", "userConfig", f"'{key}' must be an object"))
            continue
        for req in ("type", "title", "description"):
            if req not in spec:
                issues.append(("error", "userConfig", f"'{key}' is missing '{req}'"))
        if re.search(r"(TOKEN|SECRET|PASSWORD|AUTH|API_?KEY)", key, re.I) and not spec.get("sensitive"):
            issues.append(("warn", "userConfig", f"'{key}' looks like a secret but is not sensitive: true"))

    hooks_path = os.path.join(pdir, "hooks", "hooks.json")
    if os.path.exists(hooks_path):
        try:
            hooks = _load_json(hooks_path)
            if not isinstance(hooks, dict) or not isinstance(hooks.get("hooks"), dict):
                issues.append(("error", "hooks.json", "needs a top-level 'hooks' object"))
        except (OSError, ValueError) as e:
            issues.append(("error", "hooks.json", f"cannot parse: {e}"))
    return name, issues


def main(argv):
    as_json = "--json" in argv
    argv = [a for a in argv if a != "--json"]
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    if argv[0] == "--repo":
        if len(argv) < 2 or not os.path.isdir(os.path.join(argv[1], "plugins")):
            print("--repo needs a folder that holds plugins/", file=sys.stderr)
            return 2
        root = os.path.join(argv[1], "plugins")
        dirs = sorted(os.path.join(root, d) for d in os.listdir(root)
                      if os.path.exists(os.path.join(root, d, ".claude-plugin", "plugin.json")))
    else:
        dirs = argv
    for d in dirs:
        if not os.path.isdir(d):
            print(f"not a folder: {d}", file=sys.stderr)
            return 2
    results = [lint_plugin(d) for d in dirs]
    errors = sum(1 for _, iss in results for lvl, _, _ in iss if lvl == "error")
    warns = sum(1 for _, iss in results for lvl, _, _ in iss if lvl == "warn")
    if as_json:
        print(json.dumps({"plugins": [{"plugin": n, "issues": [{"level": l, "where": w, "message": m} for l, w, m in iss]} for n, iss in results],
                          "errors": errors, "warnings": warns}, indent=1))
    else:
        for n, iss in results:
            mark = "✗" if any(l == "error" for l, _, _ in iss) else ("!" if iss else "✓")
            print(f"{mark} {n}")
            for l, w, m in iss:
                print(f"    {'ERROR' if l == 'error' else 'warn '} [{w}] {m}")
        print(f"\n{len(results)} plugin(s) · {errors} error(s) · {warns} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
