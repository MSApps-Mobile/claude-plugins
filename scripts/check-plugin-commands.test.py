#!/usr/bin/env python3
"""Negative controls for check-plugin-commands.py (card NDw31FqM).
Builds throwaway plugin trees and proves the check goes red on each defect
and green on a good plugin.  Run: python3 scripts/check-plugin-commands.py is
the real gate; this proves the gate can fail."""
import importlib.util
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("cpc", os.path.join(HERE, "check-plugin-commands.py"))
cpc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cpc)

CMD_OK = '---\ndescription: "Do a thing"\nargument-hint: "[thing]"\n---\n\nUse the skill: $ARGUMENTS\n'
README_OK = "# demo\n\n## Usage\n\n```\n/demo:run [thing]\n\n# Examples:\n/demo:run\n/demo:run x\n```\n\n## License\nMIT\n"
failures = []


def make(cmd=CMD_OK, readme=README_OK, with_cmd=True):
    root = tempfile.mkdtemp()
    p = os.path.join(root, "plugins", "demo")
    os.makedirs(os.path.join(p, ".claude-plugin"))
    json.dump({"name": "demo"}, open(os.path.join(p, ".claude-plugin", "plugin.json"), "w"))
    if with_cmd:
        os.makedirs(os.path.join(p, "commands"))
        open(os.path.join(p, "commands", "run.md"), "w").write(cmd)
    if readme is not None:
        open(os.path.join(p, "README.md"), "w").write(readme)
    return root


def case(label, root, expect_fail, match=None):
    probs, _ = cpc.audit(root)
    if bool(probs) != expect_fail:
        failures.append(f"{label}: expected {'problems' if expect_fail else 'clean'}, got {probs}")
    elif match and not any(match in x for x in probs):
        failures.append(f"{label}: no problem mentioned {match!r}: {probs}")
    else:
        print(f"  ok  {label}")


print("negative controls - these MUST red:")
case("missing command", make(with_cmd=False), True, "no commands")
case("missing argument-hint", make(cmd='---\ndescription: "x"\n---\nbody\n'), True, "argument-hint")
case("empty argument-hint", make(cmd='---\ndescription: "x"\nargument-hint: ""\n---\nbody\n'), True, "argument-hint")
case("missing description", make(cmd='---\nargument-hint: "[x]"\n---\nbody\n'), True, "description")
case("README without Usage", make(readme="# demo\n\n## Install\nfoo\n"), True, "## Usage")
case("README without README", make(readme=None), True, "README")
case("Usage omits the command", make(readme="# d\n\n## Usage\n\n```\n/demo:other [x]\n\n# Examples:\n/demo:other\n```\n"), True, "/demo:run")
case("Usage without Examples", make(readme="# d\n\n## Usage\n\n```\n/demo:run [x]\n```\n"), True, "# Examples:")
print("positive control - this MUST be green:")
case("good plugin", make(), False)
print("real repo - this MUST be green:")
case("this repository", os.path.dirname(HERE), False)

if failures:
    print("\nFAIL")
    for f in failures:
        print("  " + f)
    sys.exit(1)
print("\nall cases behaved as declared")
