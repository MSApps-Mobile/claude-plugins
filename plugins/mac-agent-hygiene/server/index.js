#!/usr/bin/env node
// mac-agent-hygiene MCP server — stdio, newline-delimited JSON-RPC 2.0, zero dependencies.
// Four tools: hygiene_status (read-only), hygiene_plan (dry run), hygiene_apply (plan_id + confirm),
// hygiene_schedule (LaunchAgent install/status/uninstall). All work is done by scripts/hygiene.sh and
// scripts/install-launchd.sh; this file only frames the protocol and enforces the plan→confirm gate.
'use strict';
const { spawnSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');

const SCRIPTS = path.resolve(__dirname, '..', 'scripts');
const HYGIENE = path.join(SCRIPTS, 'hygiene.sh');
const LAUNCHD = path.join(SCRIPTS, 'install-launchd.sh');
const PLAN_TTL_MS = 30 * 60 * 1000;
const plans = new Map(); // plan_id → { at, items }

const TOOLS = [
  {
    name: 'hygiene_status',
    description: 'Read-only snapshot: disk free, Xcode DerivedData size, leftover plugin clone count, Playwright profile count (locked / in use), stale worktree census, Xcode build state, LaunchAgent state, last log lines. Never changes anything.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'hygiene_plan',
    description: 'Dry run. Lists every candidate path with action remove|keep, size in KB and the reason (e.g. dirty-uncommitted-work, profile-in-use, pushed). Returns a plan_id valid for 30 minutes that hygiene_apply requires. Deletes nothing.',
    inputSchema: {
      type: 'object',
      properties: {
        categories: { type: 'array', items: { type: 'string', enum: ['derived-data', 'plugin-clones', 'browser-caches', 'model-caches', 'worktrees'] }, description: 'Restrict the plan to these categories (default: all).' },
        worktree_age_days: { type: 'integer', minimum: 1, description: 'Override HYG_WT_AGE_DAYS for this plan (default 7).' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'hygiene_apply',
    description: 'Removes ONLY the items a fresh hygiene_plan marked remove, after re-checking each one at apply time (anything that became dirty, in-use or touched is refused). Requires the plan_id and confirm=true. Returns per-item outcome and MB freed.',
    inputSchema: {
      type: 'object',
      properties: { plan_id: { type: 'string' }, confirm: { type: 'boolean', const: true } },
      required: ['plan_id', 'confirm'],
      additionalProperties: false,
    },
  },
  {
    name: 'hygiene_schedule',
    description: 'Manage the daily LaunchAgent (com.msapps.mac-agent-hygiene). action=status reads it; install renders the plist from this plugin path and the current $HOME, unloads a legacy com.opsagents.dev-cache-cleanup agent if present, bootstraps and verifies; uninstall removes only this agent.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['status', 'install', 'uninstall'] },
        hour: { type: 'integer', minimum: 0, maximum: 23 }, minute: { type: 'integer', minimum: 0, maximum: 59 },
      },
      required: ['action'],
      additionalProperties: false,
    },
  },
];

function sh(file, args, env) {
  const r = spawnSync('/bin/bash', [file, ...args], { encoding: 'utf8', env: { ...process.env, ...env }, maxBuffer: 64 * 1024 * 1024 });
  if (r.error) throw r.error;
  return r;
}
const tsv = (out) => out.split('\n').filter(Boolean).map((l) => l.split('\t'));
const planItems = (out) => tsv(out).map(([category, action, kb, reason, p]) => ({ category, action, kb: Number(kb) || 0, reason, path: p }));
const planId = (items) => createHash('sha1').update(items.filter((i) => i.action === 'remove').map((i) => i.category + '\t' + i.path).sort().join('\n')).digest('hex').slice(0, 16);
const mb = (kb) => Math.round(kb / 1024);

function toolStatus() {
  const r = sh(HYGIENE, ['status']);
  const o = {}; const tail = [];
  for (const [k, v] of tsv(r.stdout)) { if (k === 'log_tail') tail.push(v); else o[k] = v; }
  o.log_tail = tail;
  return o;
}
function toolPlan(args = {}) {
  const env = {};
  if (args.worktree_age_days) env.HYG_WT_AGE_DAYS = String(args.worktree_age_days);
  const r = sh(HYGIENE, ['plan'], env);
  let items = planItems(r.stdout);
  if (args.categories && args.categories.length) items = items.filter((i) => args.categories.includes(i.category));
  const id = planId(items);
  plans.set(id, { at: Date.now(), items, env });
  for (const [k, v] of plans) if (Date.now() - v.at > PLAN_TTL_MS) plans.delete(k);
  const remove = items.filter((i) => i.action === 'remove');
  const byCat = {};
  for (const i of items) { byCat[i.category] ||= { remove: 0, keep: 0, remove_mb: 0 }; byCat[i.category][i.action] += 1; if (i.action === 'remove') byCat[i.category].remove_mb += mb(i.kb); }
  return { plan_id: id, expires_in_minutes: 30, would_remove: remove.length, would_free_mb: mb(remove.reduce((s, i) => s + i.kb, 0)), kept: items.length - remove.length, by_category: byCat, items, note: 'Nothing was deleted. Call hygiene_apply with this plan_id and confirm=true to remove the "remove" items; each is re-checked first.' };
}
function toolApply(args = {}) {
  if (args.confirm !== true) return { isError: true, text: 'Refused: confirm must be true.' };
  const plan = plans.get(args.plan_id);
  if (!plan) return { isError: true, text: 'Refused: unknown or expired plan_id — call hygiene_plan again and pass its plan_id.' };
  if (Date.now() - plan.at > PLAN_TTL_MS) { plans.delete(args.plan_id); return { isError: true, text: 'Refused: plan expired (30 min). Call hygiene_plan again.' }; }
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'mac-agent-hygiene-')), 'plan.tsv');
  fs.writeFileSync(file, plan.items.filter((i) => i.action === 'remove').map((i) => i.category + '\t' + i.path).join('\n') + '\n', { mode: 0o600 });
  try {
    const r = sh(HYGIENE, ['apply', file], plan.env);
    const rows = planItems(r.stdout);
    const summary = rows.find((x) => x.category === 'summary');
    const results = rows.filter((x) => x.category !== 'summary');
    plans.delete(args.plan_id);
    return { removed: results.filter((x) => x.action === 'removed').length, refused: results.filter((x) => x.action === 'refused').length, freed_mb: summary ? mb(summary.kb) : 0, disk_after: summary ? summary.path : undefined, results, stderr: r.stderr.trim() || undefined };
  } finally { fs.rmSync(path.dirname(file), { recursive: true, force: true }); }
}
function toolSchedule(args = {}) {
  const a = ['hour', 'minute'].flatMap((k) => (args[k] !== undefined ? [`--${k}`, String(args[k])] : []));
  const r = sh(LAUNCHD, [args.action, ...a]);
  const o = {}; for (const [k, v] of tsv(r.stdout)) o[k] = v;
  if (r.status !== 0) return { isError: true, text: (r.stderr || r.stdout || 'failed').trim(), partial: o };
  return o;
}

function handle(msg) {
  const { id, method, params } = msg;
  const reply = (result) => ({ jsonrpc: '2.0', id, result });
  const error = (code, message) => ({ jsonrpc: '2.0', id, error: { code, message } });
  switch (method) {
    case 'initialize':
      return reply({ protocolVersion: (params && params.protocolVersion) || '2024-11-05', capabilities: { tools: {} }, serverInfo: { name: 'mac-agent-hygiene', version: '0.1.0' } });
    case 'ping': return reply({});
    case 'tools/list': return reply({ tools: TOOLS });
    case 'tools/call': {
      const name = params && params.name; const args = (params && params.arguments) || {};
      let out;
      try {
        if (name === 'hygiene_status') out = toolStatus();
        else if (name === 'hygiene_plan') out = toolPlan(args);
        else if (name === 'hygiene_apply') out = toolApply(args);
        else if (name === 'hygiene_schedule') out = toolSchedule(args);
        else return error(-32602, `Unknown tool: ${name}`);
      } catch (e) { return reply({ content: [{ type: 'text', text: `error: ${e.message}` }], isError: true }); }
      if (out && out.isError) return reply({ content: [{ type: 'text', text: out.text + (out.partial ? '\n' + JSON.stringify(out.partial) : '') }], isError: true });
      return reply({ content: [{ type: 'text', text: JSON.stringify(out, null, 2) }] });
    }
    default:
      if (id === undefined || id === null) return null; // notification (e.g. notifications/initialized)
      return error(-32601, `Method not found: ${method}`);
  }
}

let buf = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  buf += chunk;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!line) continue;
    let msg; try { msg = JSON.parse(line); } catch { process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } }) + '\n'); continue; }
    const res = handle(msg);
    if (res) process.stdout.write(JSON.stringify(res) + '\n');
  }
});
process.stdin.on('end', () => process.exit(0));
