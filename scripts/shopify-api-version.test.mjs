/**
 * Suite for scripts/shopify-api-version.mjs — cards Q0W9KeDW and lONGiMw1.
 *
 * Order matters and is the point:
 *   1. supportWindow is proven against the VERBATIM rows of Shopify's published
 *      release-schedule table. A date formula asserted only against the value it was
 *      derived from proves nothing.
 *   2. A known-NEGATIVE control: the versions this plugin shipped before the fix must
 *      read as unsupported today. If that ever passes, every arm below measures nothing.
 *   3. Executed known-positives: the checker is run against a fixture tree reproducing
 *      each failure mode measured on this plugin, and must FAIL on each.
 *   4. A vacuity control: the same fixture, clean, must PASS — so a checker that simply
 *      always fails cannot pass this suite.
 *   5. Only then, the real repo tree through the CLI: clean must exit 0, and the same
 *      tree with one planted out-of-window version must exit 1.
 *
 * Fixtures are written INLINE or copied from the working tree, never materialised from a
 * git ref: a red-first arm pinned to `origin/main`/`HEAD~N` is green on its PR and red
 * the moment it merges.
 *
 * Run: node --test scripts/shopify-api-version.test.mjs
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, cpSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  supportWindow,
  stripCodeComments,
  auditShopifyApiVersion,
  PLUGIN_DIR,
} from "./shopify-api-version.mjs";

describe("supportWindow — proven against Shopify's published table FIRST", () => {
  // Verbatim rows of the "Shopify API release schedule" table at
  // https://shopify.dev/docs/api/usage/versioning, read 2026-11-17 ("Stable version |
  // Release date | Accessible until"). The release hour is the same page's sentence
  // "Shopify releases a new API version every three months at 5pm UTC on the first day
  // of the quarter".
  const PUBLISHED = [
    ["2025-04", "2025-04-01T17:00:00Z", "2026-04-16T15:00:00Z"], // April 1, 2025 | April 16, 2026 15:00 UTC
    ["2025-07", "2025-07-01T17:00:00Z", "2026-07-16T15:00:00Z"], // July 1, 2025 | July 16, 2026 15:00 UTC
    ["2025-10", "2025-10-01T17:00:00Z", "2026-10-16T15:00:00Z"], // October 1, 2025 | October 16, 2026 15:00 UTC
    ["2026-01", "2026-01-01T17:00:00Z", "2027-01-16T15:00:00Z"], // January 1, 2026 | January 16, 2027 15:00 UTC
    ["2026-04", "2026-04-01T17:00:00Z", "2027-04-16T15:00:00Z"], // April 1, 2026 | April 16, 2027 15:00 UTC
    ["2026-07", "2026-07-01T17:00:00Z", "2027-07-16T15:00:00Z"], // July 1, 2026 | July 16, 2027 15:00 UTC
    ["2026-10", "2026-10-01T17:00:00Z", "2027-10-16T15:00:00Z"], // October 1, 2026 | October 16, 2027 15:00 UTC (Latest stable)
    ["2027-01", "2027-01-01T17:00:00Z", "2028-01-16T15:00:00Z"], // January 1, 2027 | January 16, 2028 15:00 UTC (Release candidate)
  ];

  for (const [version, release, unsupportedAt] of PUBLISHED) {
    it(`reproduces the published window for ${version}`, () => {
      const w = supportWindow(version);
      assert.equal(w.release.toISOString(), new Date(release).toISOString());
      assert.equal(w.unsupportedAt.toISOString(), new Date(unsupportedAt).toISOString());
    });
  }

  it("rejects a string that is not a quarterly release", () => {
    for (const bad of ["2026-05", "2026-7", "26-07", "latest", "unstable", ""]) {
      assert.throws(() => supportWindow(bad), /not a Shopify API version/);
    }
  });

  it("known-NEGATIVE control: the versions this plugin shipped before the fix are unsupported today", () => {
    // 2025-01 went unsupported 2026-01-16. If this ever passes, the guard below is
    // measuring nothing.
    assert.ok(supportWindow("2025-01").unsupportedAt.getTime() < Date.now());
    // 2025-04 — what the install carriers actually shipped — went 2026-04-16.
    assert.ok(supportWindow("2025-04").unsupportedAt.getTime() < Date.now());
  });
});

describe("stripCodeComments — a history note is not a declaration", () => {
  it("drops line and block comments but keeps code and string contents", () => {
        const src = [
      "/* was 2025-01 */",
      'const a = "2026-07"; // and 2025-04 before that',
      "const b = `tpl 2026-07`;",
    ].join("\n");
    const out = stripCodeComments(src);
    assert.ok(!out.includes("2025-01"), "block comment survived");
    assert.ok(!out.includes("2025-04"), "line comment survived");
    assert.equal((out.match(/2026-07/g) ?? []).length, 2, "code/string literals must survive");
  });

  it("does not treat an apostrophe inside a comment as a string opener", () => {
    const out = stripCodeComments("// don't strip past here\nconst x = \"2026-07\";\n");
    assert.ok(out.includes('"2026-07"'));
  });
});

/** Writes a fixture plugin tree and returns its root. `over` patches individual files. */
function fixture(over = {}) {
  const root = mkdtempSync(join(tmpdir(), "shopify-apiver-"));
  const pin = over.pin ?? "2026-07";
  const files = {
    "mcp-server/src/storefront.ts":
      "/* history: this file once shipped 2025-01 */\n" +
      `export const DEFAULT_SHOPIFY_API_VERSION = "${over.mcpPin ?? pin}";\n` +
      "export const url = (shop, v) => `https://${shop}/api/${v}/graphql.json`;\n",
    "sdk/src/api-version.js":
      `export const DEFAULT_SHOPIFY_API_VERSION = "${over.sdkPin ?? pin}";\n`,
    "mcp-server/src/server.ts":
      over.serverTs ?? "const q = `query($handle: String!) { product(handle: $handle) { id } }`;\n",
    "mcp-server/.env.example": `SHOPIFY_API_VERSION=${over.envPin ?? pin}\n`,
    "mcp-server/manifest.json": JSON.stringify(
      { user_config: { shopify_api_version: { default: over.manifestPin ?? pin } } }, null, 2),
    ".claude-plugin/plugin.json": JSON.stringify(
      { mcpServers: { "OpsAgent Shopify": { env: { SHOPIFY_API_VERSION: over.pluginPin ?? pin } } } }, null, 2),
    ...(over.extra ?? {}),
  };
  for (const [rel, body] of Object.entries(files)) {
    const full = join(root, PLUGIN_DIR, rel);
    mkdirSync(join(full, ".."), { recursive: true });
    writeFileSync(full, body);
  }
  return root;
}

function findingsFor(over) {
  const root = fixture(over);
  try {
    return auditShopifyApiVersion({ root }).findings;
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

describe("the checker FAILS on each failure mode measured on this plugin", () => {
  it("an aged-out pin (the arm that goes red with no code change)", () => {
    const f = findingsFor({ pin: "2025-01" });
    assert.ok(f.some((x) => /went UNSUPPORTED/.test(x)), f.join(" | "));
    assert.ok(f.some((x) => /shopify\.dev\/docs\/api\/usage\/versioning/.test(x)),
      "the failure must carry the remedy, not just the verdict");
  });

  it("two package pins that disagree — the real pre-fix state (2025-01 vs 2025-04)", () => {
    const f = findingsFor({ mcpPin: "2025-01", sdkPin: "2025-04" });
    assert.ok(f.some((x) => /disagree/.test(x)), f.join(" | "));
  });

  it("manifest.json default left behind — what an MCPB install actually hands the server", () => {
    const f = findingsFor({ manifestPin: "2025-04" });
    assert.ok(f.some((x) => /manifest\.json/.test(x) && /WINS over the source default/.test(x)), f.join(" | "));
  });

  it(".claude-plugin/plugin.json env left behind — what a plugin install hands the server", () => {
    const f = findingsFor({ pluginPin: "2025-04" });
    assert.ok(f.some((x) => /plugin\.json/.test(x)), f.join(" | "));
  });

  it(".env.example left behind", () => {
    const f = findingsFor({ envPin: "2025-04" });
    assert.ok(f.some((x) => /\.env\.example/.test(x)), f.join(" | "));
  });

  it("a carrier nobody thought of — a stray literal in a file the checker was never told about", () => {
    const f = findingsFor({ extra: { "README.md": "Set `SHOPIFY_API_VERSION=2025-04`.\n" } });
    assert.ok(f.some((x) => /README\.md/.test(x)), f.join(" | "));
  });

  it("the deprecated productByHandle spelling surviving a version bump", () => {
    const f = findingsFor({
      serverTs: "const q = `query($handle: String!) { productByHandle(handle: $handle) { id } }`;\n",
    });
    assert.ok(f.some((x) => /productByHandle/.test(x)), f.join(" | "));
  });

  it("the pin missing entirely (a literal at each use site instead of one constant)", () => {
    const root = fixture();
    writeFileSync(join(root, PLUGIN_DIR, "mcp-server/src/storefront.ts"),
      'const v = process.env.SHOPIFY_API_VERSION || "2026-07";\n');
    try {
      const f = auditShopifyApiVersion({ root }).findings;
      assert.ok(f.some((x) => /no `export const DEFAULT_SHOPIFY_API_VERSION/.test(x)), f.join(" | "));
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});

describe("vacuity control — a checker that always fails cannot pass this", () => {
  it("a clean fixture produces ZERO findings", () => {
    assert.deepEqual(findingsFor({}), []);
  });

  it("a calendar date is not a version: 2026-04-26 must not read as a stray pin", () => {
    assert.deepEqual(findingsFor({ extra: { "NOTES.md": "*Last updated: 2026-04-26.*\n" } }), []);
  });
});

describe("CLI without --root (card EnJ6snwR)", () => {
  const script = join(dirname(fileURLToPath(import.meta.url)), "shopify-api-version.mjs");
  for (const args of [[], ["--root"]]) {
    it(`node shopify-api-version.mjs ${args.join(" ")} prints a one-line usage error naming --root and exits 2`, () => {
      const r = spawnSync(process.execPath, [script, ...args], { encoding: "utf8" });
      assert.equal(r.status, 2, r.stderr);
      assert.match(r.stderr, /--root/);
      assert.equal(r.stderr.trim().split("\n").length, 1, r.stderr);
      assert.doesNotMatch(r.stderr, /ENOENT|\n\s+at /);
    });
  }
});

describe("the real repo tree, through the CLI the workflow runs (card lONGiMw1 AC-3)", () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const script = join(here, "shopify-api-version.mjs");
  const repoRoot = join(here, "..");
  const run = (root) => spawnSync(process.execPath, [script, "--root", root], { encoding: "utf8" });

  /** A throwaway copy of the real plugin, so a planted version never touches the tree. */
  function copyOfRealPlugin() {
    const root = mkdtempSync(join(tmpdir(), "shopify-apiver-real-"));
    cpSync(join(repoRoot, PLUGIN_DIR), join(root, PLUGIN_DIR), {
      recursive: true,
      filter: (src) => !/(^|[\\/])(node_modules|dist)([\\/]|$)/.test(src),
    });
    return root;
  }

  it("the clean tree exits 0 and names the pin", () => {
    const r = run(repoRoot);
    assert.equal(r.status, 0, r.stderr);
    assert.match(r.stdout, /every carrier declares Shopify API 20\d{2}-(01|04|07|10)/);
  });

  it("a copy of the clean tree also exits 0 (the planted arms below differ by ONE edit)", () => {
    const root = copyOfRealPlugin();
    try {
      const r = run(root);
      assert.equal(r.status, 0, r.stderr);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  // Each arm plants an out-of-window version in a file a PR could plausibly touch.
  const PLANTS = [
    ["a new source literal", "mcp-server/src/server.ts",
      (s) => s + '\nexport const LEGACY_API = "2025-04";\n', /server\.ts names Shopify API version\(s\) 2025-04/],
    ["the install carrier .claude-plugin/plugin.json", ".claude-plugin/plugin.json",
      (s) => s.replace(/"SHOPIFY_API_VERSION": "[^"]+"/, '"SHOPIFY_API_VERSION": "2025-01"'), /plugin\.json mcpServers env SHOPIFY_API_VERSION is 2025-01/],
    ["a README instruction", "README.md",
      (s) => s + "\nSet `SHOPIFY_API_VERSION=2025-07`.\n", /README\.md names Shopify API version\(s\) 2025-07/],
    ["both package pins moved together to an aged-out quarter", null, null, /went UNSUPPORTED/],
  ];

  for (const [label, rel, edit, expect] of PLANTS) {
    it(`a planted out-of-window version (${label}) exits 1 and names it`, () => {
      const root = copyOfRealPlugin();
      try {
        const targets = rel ? [[rel, edit]] : [
          ["mcp-server/src/storefront.ts", (s) => s.replace(/(DEFAULT_SHOPIFY_API_VERSION = ")[^"]+"/, '$12025-10"')],
          ["sdk/src/api-version.js", (s) => s.replace(/(DEFAULT_SHOPIFY_API_VERSION = ")[^"]+"/, '$12025-10"')],
        ];
        for (const [file, fn] of targets) {
          const full = join(root, PLUGIN_DIR, file);
          const before = readFileSync(full, "utf8");
          const after = fn(before);
          assert.notEqual(after, before, `the plant did not change ${file}`);
          writeFileSync(full, after);
        }
        const r = run(root);
        assert.equal(r.status, 1, r.stdout + r.stderr);
        assert.match(r.stderr, expect);
      } finally {
        rmSync(root, { recursive: true, force: true });
      }
    });
  }
});
