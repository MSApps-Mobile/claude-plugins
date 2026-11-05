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


# The checklist asks for "an exact version ... not a range or @latest": a full X.Y.Z, with an
# optional pre-release/build tag, and nothing else ('4', '4.x', '4.19', '1.*', '>=1,==2' all fail).
EXACT_NPM = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.\-]+)?(?:\+[0-9A-Za-z.\-]+)?$")
EXACT_PY = re.compile(r"^\d+\.\d+\.\d+(?:(?:a|b|rc)\d+)?(?:\.post\d+)?(?:\.dev\d+)?$")
PY_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._\-]*(?:\[[A-Za-z0-9,._\-]+\])?$")


def _pinned(pkg):
    """npm 'name@1.2.3' / '@scope/name@1.2.3' and python 'name==1.2.3' count as pinned,
    only with a full exact version: no range, wildcard, partial version or second specifier."""
    if "==" in pkg:
        name, _, ver = pkg.partition("==")
        return bool(PY_NAME.match(name)) and EXACT_PY.match(ver) is not None
    at = pkg.rfind("@")
    return at > 0 and EXACT_NPM.match(pkg[at + 1:]) is not None


# Options that take a value in the next argument, so that value is not the package/script.
VALUE_FLAGS = {
    "npx": {"-p", "--package", "-c", "--call", "--cache", "--registry", "--userconfig"},
    "bunx": {"-p", "--package"},
    "pnpx": set(),
    "dlx": {"-p", "--package", "-c", "--reporter"},
    "uvx": {"--from", "--with", "-w", "--with-editable", "--with-requirements", "--python", "-p",
            "--index", "--index-url", "--extra-index-url", "--find-links", "-f", "--directory",
            "--project", "--cache-dir", "--config-file", "--constraints", "--overrides"},
    "pipx": {"--spec", "--python", "--pip-args", "--index-url", "-i", "--backend"},
    "uv": {"--with", "-w", "--with-editable", "--with-requirements", "--python", "-p", "--directory",
           "--project", "--package", "--extra", "--group", "--only-group", "--no-group", "--env-file",
           "--index", "--index-url", "--extra-index-url", "--find-links", "-f", "--cache-dir",
           "--config-file", "--script", "-s"},
}


def _first_positional(args, value_flags=()):
    """Index of the first argument that is neither a flag nor a flag's value, or -1."""
    skip = False
    for i, a in enumerate(args):
        if skip:
            skip = False
            continue
        if a.startswith("-"):
            skip = "=" not in a and a in value_flags
            continue
        return i
    return -1


def _positional(args, value_flags=()):
    i = _first_positional(args, value_flags)
    return args[i] if i >= 0 else ""


def _flag_value(args, names):
    """Value of the first of `names` ('--package X' or '--package=X'), or None if absent."""
    for i, a in enumerate(args):
        for n in names:
            if a == n:
                return args[i + 1] if i + 1 < len(args) else ""
            if a.startswith(n + "="):
                return a.split("=", 1)[1]
    return None


def _subcommand_at(args, word):
    """Index of the first `word` in args, or -1. Global options may sit before a
    subcommand ('uv --directory X run ...'), so the position is not fixed."""
    return args.index(word) if word in args else -1


def _check_pkg(pkg, label, server_name, issues):
    if not _pinned(pkg):
        issues.append(("error", f"mcp:{server_name}", f"unpinned {label} launcher: '{pkg or '?'}' (pin an exact version, e.g. tsx@4.19.2 or name==1.2.3)"))


def _check_uvx(args, label, server_name, issues):
    head = args[:max(_first_positional(args, VALUE_FLAGS["uvx"]), 0) or len(args)]
    frm = _flag_value(head, ["--from"])
    if frm is not None:
        if not _pinned(frm):
            issues.append(("error", f"mcp:{server_name}", f"{label} --from {frm or '?'} is not pinned (use name==X.Y.Z)"))
        return
    _check_pkg(_positional(args, VALUE_FLAGS["uvx"]), label, server_name, issues)


def _check_npm(cmd, args, label, server_name, issues):
    flags = VALUE_FLAGS[cmd]
    k = _first_positional(args, flags)
    head = args if k < 0 else args[:k]
    pkg = _flag_value(head, ["--package", "-p"])
    _check_pkg(pkg if pkg is not None else _positional(args, flags), label, server_name, issues)


def check_launcher(server_name, cfg, issues):
    if not isinstance(cfg, dict):
        issues.append(("error", f"mcp:{server_name}", "server entry must be an object"))
        return
    cmd = os.path.basename(str(cfg.get("command", "")))
    args = [str(a) for a in cfg.get("args", []) or []]
    if cmd == "uvx":
        _check_uvx(args, "uvx", server_name, issues)
    elif cmd in LAUNCHERS:
        _check_npm(cmd, args, cmd, server_name, issues)
    elif cmd in DLX_LAUNCHERS:
        k = _subcommand_at(args, "dlx")
        if k >= 0:
            _check_npm("dlx", args[k + 1:], f"{cmd} dlx", server_name, issues)
    elif cmd == "pipx":
        k = _subcommand_at(args, "run")
        if k >= 0:
            rest = args[k + 1:]
            j = _first_positional(rest, VALUE_FLAGS["pipx"])
            spec = _flag_value(rest if j < 0 else rest[:j], ["--spec"])
            if spec is not None:
                _check_pkg(spec, "pipx run --spec", server_name, issues)
            else:
                _check_pkg(_positional(rest, VALUE_FLAGS["pipx"]), "pipx run", server_name, issues)
    elif cmd == "uv":
        # 'uv [global options] <subcommand> ...': the subcommand is the first positional.
        k = _first_positional(args, VALUE_FLAGS["uv"])
        sub = args[k] if k >= 0 else ""
        if sub == "tool" and args[k + 1:k + 2] == ["run"]:  # 'uv tool run' is uvx
            _check_uvx(args[k + 2:], "uv tool run", server_name, issues)
        elif sub == "run":
            # Only options before the script count; '--frozen' after it is the script's own argument.
            rest = args[k + 1:]
            j = _first_positional(rest, VALUE_FLAGS["uv"])
            opts = args[:k] + (rest if j < 0 else rest[:j])
            if not ({"--locked", "--frozen"} & set(opts)):
                issues.append(("error", f"mcp:{server_name}", "'uv run' without --locked or --frozen before the script (the directory requires a locked run)"))


def _readme_words(text):
    """Words outside fenced code blocks: the checklist says words in code blocks don't count."""
    prose, fence = [], None
    for line in text.splitlines():
        m = re.match(r"^\s{0,3}(`{3,}|~{3,})", line)
        if m:
            mark = m.group(1)
            if fence is None:
                fence = mark
            elif mark[0] == fence[0] and len(mark) >= len(fence):
                fence = None
            continue
        if fence is None:
            prose.append(line)
    return len(re.findall(r"\w+", "\n".join(prose)))


def _mcp_servers(pdir, manifest, issues):
    """(source, servers) pairs from .mcp.json and from plugin.json's mcpServers (inline object,
    or a path / list of paths to JSON files)."""
    found = []
    mcp_path = os.path.join(pdir, ".mcp.json")
    if os.path.exists(mcp_path):
        try:
            found.append((".mcp.json", _load_json(mcp_path).get("mcpServers") or {}))
        except (OSError, ValueError, AttributeError) as e:
            issues.append(("error", ".mcp.json", f"cannot parse: {e}"))
    inline = manifest.get("mcpServers")
    refs = inline if isinstance(inline, list) else [inline]
    for ref in refs:
        if isinstance(ref, dict):
            found.append(("plugin.json", ref))
        elif isinstance(ref, str) and ref:
            path = os.path.normpath(os.path.join(pdir, ref.replace("${CLAUDE_PLUGIN_ROOT}", ".")))
            if os.path.abspath(path) == os.path.abspath(mcp_path):
                continue
            try:
                data = _load_json(path)
                found.append((ref, data.get("mcpServers", data) if isinstance(data, dict) else {}))
            except (OSError, ValueError) as e:
                issues.append(("error", "plugin.json", f"mcpServers file {ref} cannot be read: {e}"))
    return found


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
        author = manifest.get("author")
        if not isinstance(author, dict) or not author.get("name"):
            issues.append(("error", "plugin.json", "'author.name' is missing (author must be an object with a name)"))
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
            words = _readme_words(f.read())
        if words < MIN_README_WORDS:
            issues.append(("error", "README", f"README has {words} words outside code blocks; the directory needs at least {MIN_README_WORDS}"))

    user_config = manifest.get("userConfig", {}) or {}
    if not isinstance(user_config, dict):
        issues.append(("error", "plugin.json", "'userConfig' must be an object"))
        user_config = {}
    for _src, servers in _mcp_servers(pdir, manifest, issues):
        for sname, cfg in (servers.items() if isinstance(servers, dict) else []):
            check_launcher(sname, cfg, issues)
            if not isinstance(cfg, dict):
                continue
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
