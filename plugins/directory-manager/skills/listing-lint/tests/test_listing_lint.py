"""Run: python3 -m unittest discover -s plugins/directory-manager/skills/listing-lint/tests"""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import listing_lint  # noqa: E402

README = "word " * 60
GOOD = {
    "name": "demo", "displayName": "Demo", "description": "Does demo things.",
    "author": {"name": "MSApps"}, "license": "MIT", "homepage": "https://claudeservices.ai/plugins",
    "keywords": ["demo"], "documentationUrl": "https://x/doc", "supportUrl": "https://x/s",
    "privacyPolicyUrl": "https://x/p", "termsOfServiceUrl": "https://x/t",
}


def make(manifest, readme=README, mcp=None, hooks=None):
    d = tempfile.mkdtemp()
    os.makedirs(os.path.join(d, ".claude-plugin"))
    json.dump(manifest, open(os.path.join(d, ".claude-plugin", "plugin.json"), "w"))
    if readme is not None:
        open(os.path.join(d, "README.md"), "w").write(readme)
    if mcp is not None:
        json.dump(mcp, open(os.path.join(d, ".mcp.json"), "w"))
    if hooks is not None:
        os.makedirs(os.path.join(d, "hooks"))
        json.dump(hooks, open(os.path.join(d, "hooks", "hooks.json"), "w"))
    return d


def errors(d):
    return [m for lvl, _, m in listing_lint.lint_plugin(d)[1] if lvl == "error"]


class ListingLint(unittest.TestCase):
    def test_complete_plugin_is_clean(self):
        self.assertEqual(listing_lint.lint_plugin(make(GOOD))[1], [])

    def test_legacy_policy_fields_are_errors(self):
        m = dict(GOOD); m.pop("privacyPolicyUrl"); m["privacy_policy"] = "https://x/p"
        self.assertTrue(any("privacyPolicyUrl" in e for e in errors(make(m))))

    def test_placeholder_description_and_short_readme(self):
        m = dict(GOOD, description="---")
        errs = errors(make(m, readme="too short"))
        self.assertTrue(any("description" in e for e in errs))
        self.assertTrue(any("40" in e for e in errs))

    def test_unpinned_vs_pinned_npx(self):
        bad = {"mcpServers": {"a": {"command": "npx", "args": ["tsx", "x.ts"]}}}
        good = {"mcpServers": {"a": {"command": "npx", "args": ["--yes", "tsx@4.19.2", "x.ts"]}}}
        self.assertTrue(any("unpinned npx" in e for e in errors(make(GOOD, mcp=bad))))
        self.assertEqual(errors(make(GOOD, mcp=good)), [])

    def test_uvx_from_must_be_pinned(self):
        bad = {"mcpServers": {"a": {"command": "uvx", "args": ["--from", "pkg", "run"]}}}
        good = {"mcpServers": {"a": {"command": "uvx", "args": ["--from", "pkg==1.2.3", "run"]}}}
        self.assertTrue(errors(make(GOOD, mcp=bad)))
        self.assertEqual(errors(make(GOOD, mcp=good)), [])

    def launcher_errors(self, command, args):
        issues = []
        listing_lint.check_launcher("s", {"command": command, "args": args}, issues)
        return [m for lvl, _, m in issues if lvl == "error"]

    def test_known_negative_pinned_npx(self):
        self.assertEqual(self.launcher_errors("npx", ["tsx@4.19.2", "x.ts"]), [])

    def test_uv_run_needs_locked_or_frozen(self):
        # plugins/whatsapp-mcp/.mcp.json as on main (2026-10-30): uv --directory ... run main.py
        args = ["--directory", "${WHATSAPP_MCP_PATH}/whatsapp-mcp-server", "run", "main.py"]
        self.assertEqual(len(self.launcher_errors("uv", args)), 1)
        self.assertEqual(self.launcher_errors("uv", args[:3] + ["--frozen", "main.py"]), [])
        self.assertEqual(self.launcher_errors("uv", ["run", "--locked", "main.py"]), [])
        self.assertEqual(len(self.launcher_errors("uv", ["run", "server.py"])), 1)
        self.assertEqual(self.launcher_errors("uv", ["--version"]), [])

    def test_whatsapp_mcp_file_in_repo_is_flagged(self):
        path = os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "whatsapp-mcp", ".mcp.json")
        if not os.path.exists(path):
            self.skipTest("not inside the claude-plugins repo")
        with open(path, encoding="utf-8") as f:
            servers = json.load(f)["mcpServers"]
        uv = [cfg for cfg in servers.values() if os.path.basename(cfg.get("command", "")) == "uv"]
        self.assertEqual(len(uv), 1)
        if {"--locked", "--frozen"} & set(uv[0].get("args", [])):
            self.skipTest("whatsapp-mcp now runs uv with --locked/--frozen")
        self.assertEqual(len(self.launcher_errors("uv", uv[0]["args"])), 1)
        fixed = dict(uv[0], args=uv[0]["args"][:-1] + ["--frozen", uv[0]["args"][-1]])
        self.assertEqual(self.launcher_errors(fixed["command"], fixed["args"]), [])

    def test_uv_tool_run_is_a_uvx_launcher(self):
        self.assertEqual(len(self.launcher_errors("uv", ["tool", "run", "ruff"])), 1)
        self.assertEqual(self.launcher_errors("uv", ["tool", "run", "ruff==0.6.9"]), [])

    def test_pipx_run_must_be_pinned(self):
        self.assertEqual(len(self.launcher_errors("pipx", ["run", "black"])), 1)
        self.assertEqual(self.launcher_errors("pipx", ["run", "black==24.8.0"]), [])
        self.assertEqual(len(self.launcher_errors("pipx", ["run", "--spec", "mcp-x", "mcp-x"])), 1)
        self.assertEqual(self.launcher_errors("pipx", ["run", "--spec", "mcp-x==1.0.0", "mcp-x"]), [])

    def test_pnpm_and_yarn_dlx_must_be_pinned(self):
        for cmd in ("pnpm", "yarn"):
            self.assertEqual(len(self.launcher_errors(cmd, ["dlx", "@scope/srv"])), 1, cmd)
            self.assertEqual(self.launcher_errors(cmd, ["dlx", "@scope/srv@1.2.3"]), [], cmd)
            self.assertEqual(self.launcher_errors(cmd, ["install"]), [], cmd)

    def test_env_var_needs_user_config(self):
        mcp = {"mcpServers": {"a": {"command": "node", "args": ["${CLAUDE_PLUGIN_ROOT}/i.js"], "env": {"K": "${API_TOKEN}"}}}}
        self.assertTrue(any("userConfig" in e for e in errors(make(GOOD, mcp=mcp))))
        m = dict(GOOD, userConfig={"API_TOKEN": {"type": "string", "title": "T", "description": "D", "sensitive": True}})
        mcp2 = {"mcpServers": {"a": {"command": "node", "args": [], "env": {"K": "${user_config.API_TOKEN}"}}}}
        self.assertEqual(errors(make(m, mcp=mcp2)), [])

    def test_user_config_reference_without_entry(self):
        mcp = {"mcpServers": {"a": {"command": "node", "args": [], "env": {"K": "${user_config.MISSING}"}}}}
        self.assertTrue(any("no matching userConfig" in e for e in errors(make(GOOD, mcp=mcp))))

    def test_hooks_need_top_level_object(self):
        self.assertTrue(any("top-level" in e for e in errors(make(GOOD, hooks={"SessionStart": []}))))
        self.assertEqual(errors(make(GOOD, hooks={"hooks": {"SessionStart": []}})), [])

    def test_missing_license_is_error(self):
        m = dict(GOOD); m.pop("license")
        self.assertTrue(any("license" in e for e in errors(make(m))))

    def test_exit_codes(self):
        self.assertEqual(listing_lint.main([make(GOOD)]), 0)
        self.assertEqual(listing_lint.main([make(dict(GOOD, description=""))]), 1)
        self.assertEqual(listing_lint.main([]), 2)
        self.assertEqual(listing_lint.main(["/nonexistent/folder"]), 2)


if __name__ == "__main__":
    unittest.main()
