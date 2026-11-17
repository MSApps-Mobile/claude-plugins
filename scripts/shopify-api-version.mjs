#!/usr/bin/env node
/**
 * shopify-api-version.mjs — the guard that makes the NEXT Shopify API version bump a
 * RED BUILD instead of a silent outage in a plugin third parties install.
 *
 * Cards Q0W9KeDW and lONGiMw1. `plugins/opsagent-shopify` declared its Shopify API
 * version as a string literal in SEVEN separate carriers, they did not agree with each
 * other, and every one of them was already past Shopify's 12-month support window:
 *
 *   mcp-server/src/storefront.ts        2025-01   (unsupported since 2026-01-16)
 *   mcp-server/src/admin.ts             2025-04   (unsupported since 2026-04-16)
 *   sdk/src/storefront-client.js        2025-04
 *   sdk/src/admin-client.js             2025-04
 *   mcp-server/manifest.json            2025-04   (what an MCPB install hands the server)
 *   mcp-server/.env.example             2025-04
 *   .claude-plugin/plugin.json          2025-04   (what a plugin install hands the server)
 *
 * The last three are the reason "fix the one literal in the source" would have shipped
 * broken: `SHOPIFY_API_VERSION` from an install carrier WINS over the source default at
 * runtime, so the version a reader finds in the source was never the version the plugin
 * sent.
 *
 * The fix is one pin, `DEFAULT_SHOPIFY_API_VERSION`, declared once per shipped package
 * (the MCP server and the SDK are packaged separately, so neither can import the other):
 * `mcp-server/src/storefront.ts` and `sdk/src/api-version.js`. Every other carrier must
 * declare that same value, and this checker fails the build when any of them does not.
 *
 * Shopify's contract (https://shopify.dev/docs/api/usage/versioning, read 2026-11-17):
 * "Shopify releases a new API version every three months at 5pm UTC on the first day of
 * the quarter" and each stable version is accessible until 15:00 UTC on the 16th of the
 * same month one year later. The formula below is proven against the VERBATIM rows of
 * that page's release table in scripts/shopify-api-version.test.mjs before it is trusted
 * for anything — a formula asserted only against the value it was derived from proves
 * nothing.
 *
 * Usage:  node scripts/shopify-api-version.mjs --root <repo root>   (required; no --root exits 2)
 * Exit 0 = every carrier agrees on one pin, that pin is supported today, and no
 *          deprecated query spelling survived the bump.
 * Exit 1 = findings, each naming the file and the remedy.
 * Exit 2 = usage error.
 *
 * Self-contained on purpose: Node built-ins only, no install step in CI.
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { join, relative, resolve } from "node:path";

export const PLUGIN_DIR = join("plugins", "opsagent-shopify");

/** A Shopify quarterly version, NOT a calendar date: `2026-04-26` must not match. */
const VERSION_RE = /\b(20\d{2}-(?:01|04|07|10))\b(?!-\d)/g;

/** Release instant and end-of-support instant for a `YYYY-MM` Shopify version. */
export function supportWindow(version) {
  const m = /^(\d{4})-(01|04|07|10)$/.exec(version);
  if (!m) throw new Error(`not a Shopify API version: ${version}`);
  const [year, month] = [Number(m[1]), Number(m[2])];
  return {
    release: new Date(Date.UTC(year, month - 1, 1, 17, 0, 0)),
    unsupportedAt: new Date(Date.UTC(year + 1, month - 1, 16, 15, 0, 0)),
  };
}

/**
 * Strip `//` and block comments from JS/TS source.
 *
 * Load-bearing, not cosmetic: a fix may record the OLD versions in a doctrine comment so
 * the next reader knows what went wrong. A scanner that cannot tell a comment from a
 * declaration would go red on its own history note, and the cheapest way to silence it
 * would be to delete the history.
 */
export function stripCodeComments(source) {
  let out = "";
  let i = 0;
  let mode = "code"; // code | line | block | sq | dq | tpl
  while (i < source.length) {
    const c = source[i];
    const n = source[i + 1];
    if (mode === "code") {
      if (c === "/" && n === "/") { mode = "line"; i += 2; continue; }
      if (c === "/" && n === "*") { mode = "block"; i += 2; continue; }
      if (c === "'") mode = "sq";
      else if (c === '"') mode = "dq";
      else if (c === "`") mode = "tpl";
      out += c; i += 1; continue;
    }
    if (mode === "line") {
      if (c === "\n") { mode = "code"; out += c; }
      i += 1; continue;
    }
    if (mode === "block") {
      if (c === "*" && n === "/") { mode = "code"; i += 2; continue; }
      if (c === "\n") out += c;   // keep line numbering usable
      i += 1; continue;
    }
    // inside a string / template literal
    if (c === "\\") { out += c + (n ?? ""); i += 2; continue; }
    if ((mode === "sq" && c === "'") || (mode === "dq" && c === '"') || (mode === "tpl" && c === "`")) mode = "code";
    out += c; i += 1;
  }
  return out;
}

function walk(dir, acc = []) {
  for (const entry of readdirSync(dir)) {
    if (entry === "node_modules" || entry === ".git" || entry === "dist") continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full, acc);
    else acc.push(full);
  }
  return acc;
}

const SCANNABLE = /\.(ts|js|mjs|json|md)$|(^|\/)\.env\.example$/;

/**
 * @param {{root: string, now?: number}} opts
 * @returns {{findings: string[], pin: string|null}}
 */
export function auditShopifyApiVersion({ root, now = Date.now() }) {
  const pluginRoot = join(root, PLUGIN_DIR);
  const findings = [];
  const read = (rel) => readFileSync(join(pluginRoot, rel), "utf8");
  const declared = (rel, re) => {
    const m = re.exec(read(rel));
    return m ? m[1] : null;
  };

  // 1. The two package constants, and they must be the SAME: `SHOPIFY_API_VERSION` is
  //    one env var feeding both the MCP server and the SDK, so two pins can never both
  //    be honoured — one of them is decoration.
  const mcpPin = declared("mcp-server/src/storefront.ts",
    /export const DEFAULT_SHOPIFY_API_VERSION\s*=\s*"(20\d{2}-(?:01|04|07|10))"/);
  const sdkPin = declared("sdk/src/api-version.js",
    /export const DEFAULT_SHOPIFY_API_VERSION\s*=\s*"(20\d{2}-(?:01|04|07|10))"/);

  if (!mcpPin) findings.push("mcp-server/src/storefront.ts: no `export const DEFAULT_SHOPIFY_API_VERSION = \"YYYY-MM\"` found — the pin must be ONE readable constant, not a literal at each use site.");
  if (!sdkPin) findings.push("sdk/src/api-version.js: no `export const DEFAULT_SHOPIFY_API_VERSION = \"YYYY-MM\"` found.");
  if (mcpPin && sdkPin && mcpPin !== sdkPin) {
    findings.push(`the mcp-server pin (${mcpPin}) and the sdk pin (${sdkPin}) disagree — SHOPIFY_API_VERSION is a single env var for both, so only one of these is ever honoured.`);
  }
  const pin = mcpPin ?? sdkPin;
  if (!pin) return { findings, pin: null };

  // 2. The pin is released, and still supported TODAY. This is the arm that goes red
  //    on its own with no code change, which is the whole point of the guard.
  const { release, unsupportedAt } = supportWindow(pin);
  if (release.getTime() > now) {
    findings.push(`pin ${pin} has not been released yet (release ${release.toISOString()}) — pin the current latest STABLE version, not a future quarter.`);
  }
  if (unsupportedAt.getTime() <= now) {
    findings.push(
      `Shopify API ${pin} went UNSUPPORTED at ${unsupportedAt.toISOString()}. ` +
      `Bump DEFAULT_SHOPIFY_API_VERSION in ${PLUGIN_DIR}/mcp-server/src/storefront.ts AND ` +
      `${PLUGIN_DIR}/sdk/src/api-version.js to the current latest stable release, re-verify the ` +
      `queries in mcp-server/src/server.ts, mcp-server/src/admin.ts and the sdk clients against ` +
      `that version's release notes, then re-run this checker — it names every other carrier ` +
      `that has to follow. https://shopify.dev/docs/api/usage/versioning`
    );
  }

  // 3. Every INSTALL carrier agrees. These are what an installer actually consumes, and
  //    they override the source default — a bump that misses one ships the old version.
  const envExample = read("mcp-server/.env.example");
  if (!envExample.includes(`SHOPIFY_API_VERSION=${pin}`)) {
    findings.push(`mcp-server/.env.example does not declare SHOPIFY_API_VERSION=${pin}.`);
  }
  const manifest = JSON.parse(read("mcp-server/manifest.json"));
  const manifestDefault = manifest?.user_config?.shopify_api_version?.default;
  if (manifestDefault !== pin) {
    findings.push(`mcp-server/manifest.json user_config.shopify_api_version.default is ${JSON.stringify(manifestDefault)}, not ${pin} — this is the value an MCPB install hands the server, so it WINS over the source default.`);
  }
  const pluginJson = JSON.parse(read(".claude-plugin/plugin.json"));
  const pluginEnvs = Object.values(pluginJson?.mcpServers ?? {})
    .map((s) => s?.env?.SHOPIFY_API_VERSION)
    .filter((v) => v !== undefined);
  if (pluginEnvs.length === 0) {
    findings.push(".claude-plugin/plugin.json declares no SHOPIFY_API_VERSION for any mcpServers entry.");
  }
  for (const v of pluginEnvs) {
    if (v !== pin) findings.push(`.claude-plugin/plugin.json mcpServers env SHOPIFY_API_VERSION is ${v}, not ${pin} — this is the value a plugin install hands the server.`);
  }

  // 4. No file in the plugin still NAMES a different quarterly version outside a comment.
  //    This is what catches the carrier nobody thought of, and a PR that adds one.
  for (const full of walk(pluginRoot)) {
    const rel = relative(pluginRoot, full);
    if (!SCANNABLE.test(rel)) continue;
    let text = readFileSync(full, "utf8");
    if (/\.(ts|js|mjs)$/.test(rel)) text = stripCodeComments(text);
    const stray = [...text.matchAll(VERSION_RE)].map((m) => m[1]).filter((v) => v !== pin);
    if (stray.length) {
      findings.push(`${rel} names Shopify API version(s) ${[...new Set(stray)].join(", ")} — every shipped carrier must declare ${pin}.`);
    }
  }

  // 5. No deprecated query spelling survived the bump. `productByHandle` is deprecated in
  //    favour of the top-level `product(handle:)`; leaving it behind a version bump is how
  //    the same package produced three cards.
  for (const full of walk(pluginRoot)) {
    if (!/\.(ts|js|mjs)$/.test(full)) continue;
    const rel = relative(pluginRoot, full);
    if (/productByHandle\s*\(/.test(stripCodeComments(readFileSync(full, "utf8")))) {
      findings.push(`${rel} still calls the DEPRECATED productByHandle(...) — use the top-level product(handle: ...) query.`);
    }
  }

  return { findings, pin };
}

const isMain = process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  const i = process.argv.indexOf("--root");
  const root = i > -1 ? process.argv[i + 1] : undefined;
  if (!root || root.startsWith("--")) {
    console.error("usage error: --root <path to a checkout carrying plugins/opsagent-shopify> is required.");
    process.exit(2);
  }
  const { findings, pin } = auditShopifyApiVersion({ root });
  if (findings.length === 0) {
    const { unsupportedAt } = supportWindow(pin);
    console.log(`✓ ${PLUGIN_DIR}: every carrier declares Shopify API ${pin}, supported until ${unsupportedAt.toISOString()}.`);
    process.exit(0);
  }
  console.error(`✗ ${PLUGIN_DIR}: ${findings.length} finding(s)`);
  for (const f of findings) console.error(`  · ${f}`);
  process.exit(1);
}
