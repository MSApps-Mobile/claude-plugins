"""Secrets never reach memory.db, and the store is private (card gFeFnGRA, CTO review 5554454332).

Synthetic secrets only: every value below is made up for the test and grants nothing.

Run: python3 -m unittest discover -s plugins/cowork-mem/skills/cowork-mem/tests
"""
import importlib.util
import json
import os
import sqlite3
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
PLUGIN = SKILL.parents[1]
CAPTURE = SKILL / "scripts" / "post_tool_capture.py"
HOOKS = PLUGIN / "hooks" / "hooks.json"

# Built at runtime so no secret-shaped literal sits in the repo for scanners to flag.
GHP = "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8"
PAT = "github_pat_" + "11AAAAAAA0" + "x" * 30
SK = "sk-" + "ant-api03-" + "Z" * 32
AIZA = "AIza" + "SyB" + "9" * 32
XOX = "xox" + "b-1234567890-0987654321-" + "q" * 20
BEARER = "eyJhbGciOiJIUzI1NiJ9" + ".synthetic.payload"
URLPASS = "hunter2-synthetic"
KV = "kv-synthetic-value-77"

SECRETS = [GHP, PAT, SK, AIZA, XOX, BEARER, URLPASS, KV]
PEMBODY = "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC" + "S" * 150 + "syntheticPemTailZZ"
AKIA = "AKIA" + "SYNTHETIC0000007"
ASIA = "ASIA" + "SYNTHETIC0000008"
AWSSECRET = "wJalrXUtnFEMI" + "/K7MDENG/bPxRfiCY" + "SYNTHETIC"
JWT = "eyJ" + "hbGciOiJIUzI1NiJ9.eyJzdWIiOiJzeW50aGV0aWMifQ.c3ludGhldGljc2ln"
STRIPE = "sk_" + "live_" + "S" * 24
STRIPE_R = "rk_" + "live_" + "R" * 24
NPM = "npm_" + "N" * 36
HF = "hf_" + "H" * 34

BASH = {
    "tool_name": "Bash",
    "tool_input": {"command": (
        f'curl -H "Authorization: Bearer {BEARER}" "https://api.example.com/v1?token={KV}" && '
        f"git clone https://bot:{URLPASS}@github.com/acme/repo.git && export GH_TOKEN={GHP} "
        f"OPENAI_API_KEY={SK} password={KV} && echo {PAT} {AIZA} {XOX}"
    )},
    "tool_response": f"cloned with {GHP}; key={KV}; Authorization: Bearer {BEARER}",
}
EDIT = {"tool_name": "Edit", "tool_input": {"file_path": "/tmp/synthetic.env", "old_string": "a",
                                            "new_string": f"SLACK_BOT={XOX}\nGOOGLE={AIZA}\napi_key: {KV}"},
        "tool_response": "ok"}
TASK = {"tool_name": "Task", "tool_input": {"description": f"use token {GHP}", "prompt": f"sk {SK}"},
        "tool_response": f"done with {PAT}"}


def load_capture():
    spec = importlib.util.spec_from_file_location("post_tool_capture_t", CAPTURE)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def run_hook(home, payload, plugin_root=PLUGIN):
    d = json.loads(HOOKS.read_text(encoding="utf-8"))
    cmd = d["hooks"]["PostToolUse"][0]["hooks"][0]["command"].replace("${CLAUDE_PLUGIN_ROOT}", str(plugin_root))
    env = {"PATH": os.environ["PATH"], "HOME": str(home), "CLAUDE_PLUGIN_ROOT": str(plugin_root)}
    return subprocess.run(["sh", "-c", cmd], input=json.dumps(payload), env=env,
                          capture_output=True, text=True, timeout=60)


def db_dump(db):
    con = sqlite3.connect(db)
    try:
        rows = con.execute("select * from observations").fetchall()
    finally:
        con.close()
    return rows, db.read_bytes()


def mode(p):
    return stat.S_IMODE(p.stat().st_mode)


class Redact(unittest.TestCase):
    def setUp(self):
        self.m = load_capture()

    def test_every_secret_shape_is_masked(self):
        for s in SECRETS:
            self.assertIn(s, BASH["tool_input"]["command"] + EDIT["tool_input"]["new_string"])
        out = self.m.redact(BASH["tool_input"]["command"]) + self.m.redact(EDIT["tool_input"]["new_string"])
        for s in SECRETS:
            self.assertNotIn(s, out, f"{s[:8]}... survived redaction")
        self.assertIn("[REDACTED]", out)

    def test_secret_cut_by_the_stored_slice_is_still_masked(self):
        cmd = "x" * 190 + " GH_TOKEN=" + GHP
        out = self.m.safe(cmd, 200)
        self.assertLessEqual(len(out), 200)
        self.assertNotIn(GHP[:6], out)  # not even the head of the key survives the cut

    def test_aligned_and_next_line_values_are_masked(self):
        for t in [f"password:{' ' * 40}{KV}", f"api_key =\n    {KV}", f"Authorization:    Bearer    {BEARER}",
                  f"--token\t\t{KV}"]:
            self.assertNotIn(KV if KV in t else BEARER, self.m.redact(t), t)

    def test_no_fragment_survives_the_window_edge_after_length_shift(self):
        # many short secrets shrink nothing, many LONG secrets shrink the text a lot,
        # pulling chars from past the window edge into the stored prefix
        long_secret = "sk-" + "L" * 300
        edge = "x" * 5 + "ghp_" + "E" * 600  # a key shape that straddles the window edge
        value = " ".join([long_secret] * 2) + " " + edge
        out = self.m.safe(value, 200)
        self.assertNotIn("EEEEEEEEEE", out)
        self.assertNotIn("LLLLLLLLLL", out)

    def test_large_adversarial_input_is_fast(self):
        import time
        blobs = ["a" * 1_000_000, "token" * 200_000, ("x_" * 400_000) + "=", "key" + "-" * 1_000_000,
                 "-----BEGIN PRIVATE KEY-----" * 40_000, " -u " * 250_000 + "a:", "aws_secret_access_key " * 50_000]
        t = time.monotonic()
        for b in blobs:
            self.m.redact(b)
            self.m.safe(b, 200)
        self.assertLess(time.monotonic() - t, 2.0)

    # Security leg B1-B3 on 8361e928 (PR #45 comment 6226725445): each shape was stored verbatim.
    def test_b1_pem_private_key_is_masked_whole(self):
        for kind in ("OPENSSH ", "EC ", "RSA ", ""):
            pem = (f"-----BEGIN {kind}PRIVATE KEY-----\n" + "\n".join([PEMBODY[i:i + 64] for i in range(0, len(PEMBODY), 64)])
                   + f"\n-----END {kind}PRIVATE KEY-----")
            out = self.m.redact(f"new_string: {pem}\nafter")
            self.assertNotIn(PEMBODY[:12], out, kind)
            self.assertNotIn(PEMBODY[-12:], out, kind)
            self.assertIn("after", out)  # text past END is kept
            out = self.m.safe(pem, 120)  # END cut off by the stored slice: masked to the end
            self.assertNotIn(PEMBODY[:12], out, kind)
            out = self.m.redact(pem.split("-----END")[0])  # no END at all: masked to the end
            self.assertNotIn(PEMBODY[:12], out, kind)
            self.assertNotIn(PEMBODY[-12:], out, kind)

    def test_pgp_and_putty_private_keys_are_masked(self):
        pgp = "-----BEGIN PGP PRIVATE KEY BLOCK-----\n\n" + PEMBODY + "\n-----END PGP PRIVATE KEY BLOCK-----\nafter"
        putty = ("PuTTY-User-Key-File-3: ssh-ed25519\nEncryption: none\nComment: k\nPublic-Lines: 2\nAAAApub\nAAAApub2\n"
                 "Private-Lines: 1\n" + PEMBODY + "\nPrivate-MAC: " + "f" * 64 + "\nafter")
        for t in (pgp, putty):
            out = self.m.redact(t)
            self.assertNotIn(PEMBODY[:12], out)
            self.assertIn("after", out)

    def test_b1_gcp_service_account_private_key_is_masked(self):
        sa = json.dumps({"type": "service_account", "private_key_id": "abc",
                         "private_key": "-----BEGIN PRIVATE KEY-----\n" + PEMBODY + "\n-----END PRIVATE KEY-----\n",
                         "client_email": "x@y.iam.gserviceaccount.com"})
        out = self.m.redact(sa)
        self.assertNotIn(PEMBODY[:12], out)
        self.assertIn("client_email", out)

    def test_b2_curl_user_password_is_masked(self):
        for t in [f"curl -u bot:{URLPASS} https://x", f"curl --user bot:{URLPASS} https://x",
                  f"curl --user=bot:{URLPASS} https://x", f'curl -u "bot:{URLPASS}" https://x', f"curl -ubot:{URLPASS} x"]:
            self.assertNotIn(URLPASS, self.m.redact(t), t)
        for t in [f"curl -su bot:{URLPASS} x", f"curl --proxy-user bot:{URLPASS} x", f"curl -U bot:{URLPASS} x",
                  f'curl -u "bot:{URLPASS} with space" x', f"curl -u 'bot:{URLPASS} with space' x"]:
            out = self.m.redact(t)
            self.assertNotIn(URLPASS, out, t)
            self.assertNotIn("with space", out, t)
        long_pw = URLPASS + " w" * 300  # a quoted password longer than any fixed bound
        self.assertNotIn(URLPASS, self.m.redact(f'curl -u "bot:{long_pw}" x'))
        self.assertNotIn("w w w", self.m.redact(f'curl -u "bot:{long_pw}" x'))
        cut = self.m.safe("x" * 150 + f' curl -u "bot:{URLPASS} {"y" * 600}', 200)  # closing quote past the window
        self.assertNotIn(URLPASS, cut)
        self.assertEqual(self.m.redact("git push -u origin main"), "git push -u origin main")

    def test_b3_aws_access_key_id_and_secret_are_masked(self):
        for t in [f"export AWS_ACCESS_KEY_ID={AKIA}", f"id {AKIA} used", f"temp {ASIA}",
                  f"aws configure set aws_secret_access_key {AWSSECRET}",
                  f"aws_secret_access_key   {AWSSECRET}", f"aws_secret_access_key = {AWSSECRET}"]:
            out = self.m.redact(t)
            for v in (AKIA, ASIA, AWSSECRET):
                self.assertNotIn(v, out, t)

    def test_more_token_shapes_are_masked(self):
        for v in (JWT, STRIPE, STRIPE_R, NPM, HF):
            self.assertNotIn(v, self.m.redact(f"value {v} end"), v[:8])
        self.assertNotIn("p@ss", self.m.redact(f"https://bot:p@ss{URLPASS}@github.com/a/b"))

    def test_plain_text_is_left_alone(self):
        for t in ["git commit -m 'monkey patch the keyboard'", "tokens used: 5", "npm test -- --watch"]:
            self.assertEqual(self.m.redact(t), t)


class HookStoresNoSecret(unittest.TestCase):
    def test_db_never_holds_a_synthetic_secret(self):
        with tempfile.TemporaryDirectory() as home:
            for payload in (BASH, EDIT, TASK):
                r = run_hook(home, payload)
                self.assertEqual(r.returncode, 0, r.stderr)
            db = Path(home) / ".claude" / ".cowork-mem" / "memory.db"
            rows, raw = db_dump(db)
            self.assertEqual(len(rows), 3, rows)  # known positive: all three were captured
            text = json.dumps(rows, default=str)
            self.assertIn("[REDACTED]", text)
            for s in SECRETS:
                self.assertNotIn(s, text, f"{s[:8]}... stored in a row")
                self.assertNotIn(s.encode(), raw, f"{s[:8]}... present in the DB file bytes")


class HookStoresNoB1B3Secret(unittest.TestCase):
    def test_pem_curl_user_and_aws_never_reach_the_db(self):
        pem = "-----BEGIN OPENSSH PRIVATE KEY-----\n" + PEMBODY + "\n-----END OPENSSH PRIVATE KEY-----\n"
        payloads = [
            {"tool_name": "Edit", "tool_input": {"file_path": "/tmp/id_ed25519", "old_string": "", "new_string": pem},
             "tool_response": "ok"},
            {"tool_name": "Bash", "tool_input": {"command": (
                f"curl -u bot:{URLPASS} https://x && curl --user bot:{URLPASS} https://y && "
                f"aws configure set aws_secret_access_key {AWSSECRET} && echo {AKIA}")},
             "tool_response": f"ok {ASIA}"},
        ]
        with tempfile.TemporaryDirectory() as home:
            for payload in payloads:
                r = run_hook(home, payload)
                self.assertEqual(r.returncode, 0, r.stderr)
            rows, raw = db_dump(Path(home) / ".claude" / ".cowork-mem" / "memory.db")
            self.assertEqual(len(rows), 2, rows)  # known positive: both were captured
            for v in (PEMBODY[:12], URLPASS, AWSSECRET, AKIA, ASIA):
                self.assertNotIn(v.encode(), raw, f"{v[:8]}... present in the DB file bytes")


class LargePayload(unittest.TestCase):
    def test_big_write_is_captured_with_its_real_line_count(self):
        body = ("line with api_" + "key=" + KV + "\n") * 50_000  # name split in two so the SOSA secret grep does not read the fixture as a literal
        with tempfile.TemporaryDirectory() as home:
            r = run_hook(home, {"tool_name": "Write", "tool_input": {"file_path": "/tmp/big.txt", "content": body},
                                "tool_response": "ok"})
            self.assertEqual(r.returncode, 0, r.stderr)
            rows, raw = db_dump(Path(home) / ".claude" / ".cowork-mem" / "memory.db")
            self.assertIn("(50000 lines)", json.dumps(rows, default=str))
            self.assertNotIn(KV.encode(), raw)


class PrivateModes(unittest.TestCase):
    def test_fresh_store_is_0700_and_db_0600(self):
        with tempfile.TemporaryDirectory() as home:
            r = run_hook(home, EDIT)
            self.assertEqual(r.returncode, 0, r.stderr)
            d = Path(home) / ".claude" / ".cowork-mem"
            self.assertEqual(mode(d), 0o700, oct(mode(d)))
            files = [p for p in d.iterdir() if p.is_file() and p.name.startswith("memory.db")]
            self.assertTrue(any(p.name == "memory.db" for p in files), files)
            for p in files:
                self.assertEqual(mode(p), 0o600, f"{p.name} {oct(mode(p))}")

    def test_error_log_is_0600(self):
        with tempfile.TemporaryDirectory() as home:
            r = run_hook(home, EDIT, plugin_root=Path(home) / "no-such-plugin")
            self.assertEqual(r.returncode, 0)
            log = Path(home) / ".claude" / ".cowork-mem" / "capture-errors.log"
            self.assertTrue(log.exists())
            self.assertEqual(mode(log), 0o600, oct(mode(log)))

    def test_pre_umask_store_is_tightened(self):
        with tempfile.TemporaryDirectory() as home:
            d = Path(home) / ".claude" / ".cowork-mem"
            d.mkdir(parents=True)
            os.chmod(d, 0o755)
            (d / "capture-errors.log").write_text("old\n")
            os.chmod(d / "capture-errors.log", 0o644)
            r = run_hook(home, EDIT)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(mode(d), 0o700)
            self.assertEqual(mode(d / "capture-errors.log"), 0o600)
            self.assertEqual(mode(d / "memory.db"), 0o600)


class ErrorLogCap(unittest.TestCase):
    def test_log_rotates_past_cap(self):
        with tempfile.TemporaryDirectory() as home:
            d = Path(home) / ".claude" / ".cowork-mem"
            d.mkdir(parents=True)
            (d / "capture-errors.log").write_text("x" * (300 * 1024))
            r = run_hook(home, EDIT, plugin_root=Path(home) / "no-such-plugin")
            self.assertEqual(r.returncode, 0)
            self.assertTrue((d / "capture-errors.log.1").exists(), "oversized log was not rotated")
            self.assertEqual(mode(d / "capture-errors.log.1"), 0o600)
            self.assertLess((d / "capture-errors.log").stat().st_size if (d / "capture-errors.log").exists() else 0,
                            300 * 1024)


if __name__ == "__main__":
    unittest.main()
