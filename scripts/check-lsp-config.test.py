#!/usr/bin/env python3
"""
Trello czICbElh, AC-2 - the negative control.

    "today's main passes (kotlin-lsp and swift-lsp use the right keys); a
     fixture with `startupTimeoutMs` fails the check."

Run: python3 scripts/check-lsp-config.test.py
Exit 0 = every case behaved as declared, INCLUDING the ones that must fail.
"""

import importlib.util
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures", "lsp-config")
SCRIPT = os.path.join(HERE, "check-lsp-config.py")

_spec = importlib.util.spec_from_file_location("check_lsp_config", SCRIPT)
lc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(lc)

failures = []


def case(label, fixture, expect_bad, match=None):
    root = os.path.join(FIX, fixture)
    problems, _ = lc.audit(root)
    text = " ".join(problems)
    rc = subprocess.run([sys.executable, SCRIPT, "--root", root], capture_output=True, text=True).returncode
    if bool(problems) != expect_bad or rc != (1 if expect_bad else 0):
        failures.append(f"{label}: expected {'red' if expect_bad else 'green'}, got rc={rc} problems={problems}")
    elif match and match not in text:
        failures.append(f"{label}: output did not mention {match!r}: {text}")
    else:
        print(f"  ok  {label}")


print("negative controls - these MUST red:")
case("startupTimeoutMs instead of startupTimeout", "startup-timeout-ms", True, match="startupTimeoutMs")
case("server without command / extensionToLanguage", "missing-required", True, match="extensionToLanguage")
case("unknown key in an inline plugin.json lspServers", "inline-unknown-key", True, match="restartOnCrashes")
case("lspServers path pointing at a missing file", "dangling-path", True, match="servers.json")
case(".lsp.json that does not parse", "bad-json", True, match="invalid JSON")
case("lspServers given as an absolute path (DMqfyLzZ)", "absolute-path", True, match="absolute path")
case("lspServers path that leaves the plugin dir (DMqfyLzZ)", "escaping-path", True, match="escapes the plugin directory")
case("key with a newline in it (DMqfyLzZ)", "newline-key", True, match="unknown key")
case("diagnostics set to a non-boolean (3P7ZxakX)", "diagnostics-not-bool", True, match="'diagnostics' must be bool")


def one_command_per_problem(fixture):
    """AC-3: a CR/LF in a key must not let the output start a second workflow
    command. Every stdout line that opens with '::' is an '::error::' line, and
    the forged '::warning::' never starts a line."""
    root = os.path.join(FIX, fixture)
    out = subprocess.run([sys.executable, SCRIPT, "--root", root], capture_output=True, text=True).stdout
    commands = [l for l in out.splitlines() if l.startswith("::")]
    forged = [l for l in commands if not l.startswith("::error::")]
    if forged or not commands:
        failures.append(f"{fixture}: workflow-command lines not escaped: {commands}")
    elif "%0A" not in out:
        failures.append(f"{fixture}: the newline was not encoded as %0A: {out!r}")
    else:
        print(f"  ok  {fixture}: newline encoded, no forged workflow command")


one_command_per_problem("newline-key")

print("known-positive - this MUST be green:")
case(".lsp.json via path + inline lspServers, every allowed key style", "valid", False)

print("the real repo:")
problems, checked = lc.audit(os.path.dirname(HERE))
# A check that visits nothing is indistinguishable from one that finds nothing
# wrong: main ships kotlin-lsp and swift-lsp, so at least two configs.
if problems:
    failures.append(f"repo LSP configs invalid: {problems}")
elif checked < 2:
    failures.append(f"repo walk checked only {checked} LSP config(s); expected >= 2 (kotlin-lsp, swift-lsp)")
else:
    print(f"  ok  {checked} LSP config(s) in this repo are valid")

if failures:
    print("\nFAILED:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("\nall cases behaved as declared")
