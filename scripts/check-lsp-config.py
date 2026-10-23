#!/usr/bin/env python3
"""
ARE THE PLUGINS' LSP SERVER CONFIGS ONES CLAUDE CODE WILL ACTUALLY LOAD?

Trello czICbElh. No PR check ever read `.lsp.json` (or an inline `lspServers`
block in plugin.json). Claude Code's loader rejects a config with an unknown
key (e.g. `startupTimeoutMs` instead of `startupTimeout`) and drops the whole
file, so such a plugin merged and published green with no working language
server.

What is checked, for every plugins/*/ directory:
  - plugins/<p>/.lsp.json, when present
  - plugin.json `lspServers`: an inline object, or a path (or list of paths)
    to a JSON file relative to the plugin root

Each config maps a server name to an object that must have `command` and
`extensionToLanguage`, and no key outside ALLOWED_KEYS.

An `lspServers` path must stay inside the plugin directory (card DMqfyLzZ):
an absolute path, or one whose realpath leaves the plugin root (`../..`, a
symlink out), is reported and never opened. Claude Code refuses such a path
too ("path escapes plugin directory").

    check-lsp-config.py [--root .]        exit 1 on any problem
"""

import argparse
import json
import os
import sys

# The ONE place the Claude Code LSP server schema is pinned. Value: the JSON
# type(s) the key accepts (None = any JSON value). Source for every key: the
# `lspServers` table in the plugin manifest reference,
# https://code.claude.com/docs/en/plugins-reference#lspservers
# (`requestTimeout` there: milliseconds, positive integer, Claude Code v2.1.288+;
# re-read 2026-10-21, card DMqfyLzZ).
ALLOWED_KEYS = {
    "command": (str,),
    "args": (list,),
    "extensionToLanguage": (dict,),
    "transport": (str,),
    "env": (dict,),
    "initializationOptions": None,
    "settings": None,
    "workspaceFolder": (str,),
    "startupTimeout": (int, float),
    "shutdownTimeout": (int, float),
    "requestTimeout": (int, float),
    "restartOnCrash": (bool,),
    "maxRestarts": (int,),
}
REQUIRED_KEYS = ("command", "extensionToLanguage")
TRANSPORTS = ("stdio", "socket")


def _type_ok(value, types):
    if types is None:
        return True
    # bool is a subclass of int in Python; a timeout of `true` is not a number.
    if isinstance(value, bool) and bool not in types:
        return False
    return isinstance(value, types)


def check_servers(servers, where):
    """Validate one LSP config (server name -> server object). Returns problems."""
    problems = []
    if not isinstance(servers, dict) or not servers:
        return [f"{where}: must be a non-empty object mapping server name -> config"]
    for name, cfg in servers.items():
        at = f"{where}: server '{name}'"
        if not isinstance(cfg, dict):
            problems.append(f"{at}: must be an object")
            continue
        for key in REQUIRED_KEYS:
            if key not in cfg:
                problems.append(f"{at}: missing required key '{key}'")
        for key, value in cfg.items():
            if key not in ALLOWED_KEYS:
                problems.append(f"{at}: unknown key '{key}' (allowed: {', '.join(ALLOWED_KEYS)})")
            elif not _type_ok(value, ALLOWED_KEYS[key]):
                want = "/".join(t.__name__ for t in ALLOWED_KEYS[key])
                problems.append(f"{at}: '{key}' must be {want}, got {type(value).__name__}")
        if isinstance(cfg.get("command"), str) and not cfg["command"].strip():
            problems.append(f"{at}: 'command' is empty")
        etl = cfg.get("extensionToLanguage")
        if isinstance(etl, dict):
            if not etl:
                problems.append(f"{at}: 'extensionToLanguage' is empty")
            for ext, lang in etl.items():
                if not isinstance(lang, str):
                    problems.append(f"{at}: extensionToLanguage['{ext}'] must be a string")
        if "transport" in cfg and cfg["transport"] not in TRANSPORTS:
            problems.append(f"{at}: 'transport' must be one of {TRANSPORTS}, got {cfg['transport']!r}")
        if isinstance(cfg.get("args"), list) and not all(isinstance(a, str) for a in cfg["args"]):
            problems.append(f"{at}: 'args' must be a list of strings")
    return problems


def _load(path, rel):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh), []
    except FileNotFoundError:
        return None, [f"{rel}: file not found"]
    except (OSError, ValueError) as e:
        return None, [f"{rel}: invalid JSON: {e}"]


def _inside(path, base):
    """True when the realpath of `path` is `base` itself or below it."""
    real, top = os.path.realpath(path), os.path.realpath(base)
    return real == top or real.startswith(top + os.sep)


def workflow_text(message):
    """Escape a message for a `::error::` line the way GitHub's own toolkit does,
    so a CR/LF inside a JSON key cannot start a new (forged) workflow command."""
    return message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def check_plugin(root, plugin):
    """Returns (problems, number of configs checked)."""
    pdir = os.path.join(root, "plugins", plugin)
    problems, checked, seen = [], 0, set()

    def check_file(path):
        nonlocal checked
        real = os.path.realpath(path)
        if real in seen:
            return
        seen.add(real)
        rel = os.path.relpath(path, root)
        data, errs = _load(path, rel)
        problems.extend(errs)
        if data is not None:
            checked += 1
            problems.extend(check_servers(data, rel))

    default = os.path.join(pdir, ".lsp.json")
    if os.path.isfile(default):
        check_file(default)

    pj_path = os.path.join(pdir, ".claude-plugin", "plugin.json")
    if os.path.isfile(pj_path):
        pj_rel = os.path.relpath(pj_path, root)
        pj, errs = _load(pj_path, pj_rel)
        # An unparsable plugin.json is the plugin.json validator's finding.
        lsp = pj.get("lspServers") if isinstance(pj, dict) else None
        if lsp is not None:
            entries = lsp if isinstance(lsp, list) else [lsp]
            for entry in entries:
                if isinstance(entry, str):
                    where = f"{pj_rel} lspServers {entry!r}"
                    if os.path.isabs(entry):
                        problems.append(f"{where}: absolute path; it must be relative to the plugin root")
                        continue
                    target = os.path.join(pdir, entry)
                    if not _inside(target, pdir):
                        problems.append(f"{where}: path escapes the plugin directory")
                        continue
                    check_file(target)
                elif isinstance(entry, dict):
                    checked += 1
                    problems.extend(check_servers(entry, f"{pj_rel} lspServers"))
                else:
                    problems.append(f"{pj_rel}: lspServers must be a path, an object, or a list of those")
    return problems, checked


def audit(root):
    pdir = os.path.join(root, "plugins")
    if not os.path.isdir(pdir):
        return [f"{pdir}: no plugins/ directory"], 0
    problems, checked = [], 0
    for plugin in sorted(os.listdir(pdir)):
        if os.path.isdir(os.path.join(pdir, plugin)):
            p, c = check_plugin(root, plugin)
            problems.extend(p)
            checked += c
    return problems, checked


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=".")
    args = ap.parse_args()
    problems, checked = audit(args.root)
    for p in problems:
        print(f"::error::{workflow_text(p)}")
    if problems:
        print(f"\n{len(problems)} LSP config problem(s) across {checked} config(s)")
        return 1
    print(f"✓ {checked} LSP server config(s) valid")
    return 0


if __name__ == "__main__":
    sys.exit(main())
