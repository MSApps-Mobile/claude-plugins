#!/usr/bin/env node

/**
 * Create Client Dashboard Generator
 *
 * Generates a branded dashboard for a new client under:
 *   dashboard/src/app/demo/<client-id>/
 *
 * Usage:
 *   node scripts/create-client-dashboard.js <client-id>
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const CLIENTS_DIR = path.join(ROOT, 'clients');
const DEMO_DIR = path.join(ROOT, 'dashboard', 'src', 'app', 'demo');

const clientId = process.argv[2];
if (!clientId) {
  console.error('Usage: node scripts/create-client-dashboard.js <client-id>');
  process.exit(1);
}

const configPath = path.join(CLIENTS_DIR, clientId + '.json');
if (!fs.existsSync(configPath)) {
  console.error('Client config not found: ' + configPath);
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
const dashboard = config.dashboard || {};
const clientName = config.name || clientId;
const lang = dashboard.language || 'en';
const rtl = dashboard.rtl || false;
const brandColor = dashboard.brand_color || 'blue';
const logoIcon = dashboard.logo_icon || 'Building2';
const pascalName = toPascalCase(clientId);

const outDir = path.join(DEMO_DIR, clientId);
fs.mkdirSync(path.join(outDir, 'agents'), { recursive: true });

const agentEntries = Object.entries(config.agents || {}).map(([name, cfg]) => ({
  id: name,
  name: name.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' '),
  enabled: cfg.enabled,
  schedule: cfg.schedule || '',
}));

const enabledCount = Object.values(config.agents || {}).filter(a => a.enabled).length;

// Helper
const t = (he, en) => lang === 'he' ? he : en;
const dir = rtl ? 'rtl' : 'ltr';
const sideDir = rtl ? 'r' : 'l';
const borderDir = rtl ? 'l' : 'r';

// ── layout.tsx ──────────────────────────────
const layout = [
  "'use client';",
  "",
  "import Link from 'next/link';",
  "import { usePathname } from 'next/navigation';",
  "import { clsx } from 'clsx';",
  "import { useState } from 'react';",
  "import {",
  ...Array.from(new Set(['LayoutDashboard', 'Bot', logoIcon, 'Menu', 'X', 'Zap'])).map(i => "  " + i + ","),
  "} from 'lucide-react';",
  "",
  "const nav = [",
  "  { href: '/demo/" + clientId + "', label: '" + t('סקירה כללית', 'Overview') + "', icon: LayoutDashboard },",
  "  { href: '/demo/" + clientId + "/agents', label: '" + t('סוכני AI', 'AI Agents') + "', icon: Bot },",
  "];",
  "",
  "export default function " + pascalName + "Layout({",
  "  children,",
  "}: {",
  "  children: React.ReactNode;",
  "}) {",
  "  const pathname = usePathname();",
  "  const [open, setOpen] = useState(false);",
  "",
  "  return (",
  '    <div' + (rtl ? ' dir="rtl"' : '') + '>',
  "      {/* Hide parent sidebar */}",
  "      <style dangerouslySetInnerHTML={{ __html: `",
  "        main.lg\\\\:ml-60 { margin-left: 0 !important; padding: 0 !important; }",
  "        main.lg\\\\:ml-60 > .max-w-7xl { max-width: 100% !important; padding: 0 !important; }",
  "        aside.w-60 { display: none !important; }",
  "      `}} />",
  "",
  "      {/* Mobile header */}",
  '      <div className="lg:hidden fixed top-0 left-0 right-0 h-14 bg-surface border-b border-surface-border z-50 flex items-center px-4 gap-3">',
  '        <button onClick={() => setOpen(true)} className="p-1.5 rounded-lg hover:bg-surface-raised">',
  '          <Menu className="w-5 h-5 text-gray-300" />',
  "        </button>",
  '        <div className="flex items-center gap-2">',
  '          <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-' + brandColor + '-500 to-' + brandColor + '-700 flex items-center justify-center">',
  '            <' + logoIcon + ' className="w-3.5 h-3.5 text-white" />',
  "          </div>",
  '          <h1 className="text-sm font-bold text-white">' + clientName + ' AI</h1>',
  "        </div>",
  "      </div>",
  "",
  "      {/* Mobile overlay */}",
  "      {open && (",
  '        <div className="lg:hidden fixed inset-0 bg-black/60 z-50" onClick={() => setOpen(false)} />',
  "      )}",
  "",
  "      {/* Sidebar */}",
  "      <aside",
  "        className={clsx(",
  "          'fixed top-0 h-screen w-64 bg-surface border-" + borderDir + " border-surface-border flex flex-col z-50 transition-transform duration-200',",
  "          'lg:" + sideDir + "-0 lg:translate-x-0',",
  "          open ? '" + sideDir + "-0 translate-x-0' : '" + (rtl ? '' : '-') + "translate-x-full lg:translate-x-0'",
  "        )}",
  "      >",
  '        <div className="p-5 border-b border-surface-border flex items-center justify-between">',
  '          <div className="flex items-center gap-2.5">',
  '            <div className="w-9 h-9 rounded-lg bg-gradient-to-br from-' + brandColor + '-500 to-' + brandColor + '-700 flex items-center justify-center">',
  '              <' + logoIcon + ' className="w-4 h-4 text-white" />',
  "            </div>",
  "            <div>",
  '              <h1 className="text-base font-bold text-white tracking-tight">' + clientName + '</h1>',
  '              <p className="text-[10px] text-gray-500 -mt-0.5">AI Operations Platform</p>',
  "            </div>",
  "          </div>",
  '          <button onClick={() => setOpen(false)} className="lg:hidden p-1 rounded hover:bg-surface-raised">',
  '            <X className="w-4 h-4 text-gray-400" />',
  "          </button>",
  "        </div>",
  "",
  '        <nav className="flex-1 p-3 space-y-1">',
  "          {nav.map(({ href, label, icon: Icon }) => {",
  "            const active = pathname === href;",
  "            return (",
  "              <Link",
  '                key={href}',
  '                href={href}',
  "                onClick={() => setOpen(false)}",
  "                className={clsx(",
  "                  'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all duration-150',",
  "                  active",
  "                    ? 'bg-" + brandColor + "-500/15 text-" + brandColor + "-400'",
  "                    : 'text-gray-400 hover:text-gray-200 hover:bg-surface-raised'",
  "                )}",
  "              >",
  '                <Icon className="w-4 h-4" />',
  "                {label}",
  "              </Link>",
  "            );",
  "          })}",
  "        </nav>",
  "",
  '        <div className="mt-auto p-4 border-t border-surface-border">',
  '          <div className="bg-surface-raised rounded-lg p-3">',
  '            <p className="text-[10px] uppercase tracking-wider text-gray-500 mb-1">' + t('לקוח', 'Client') + '</p>',
  '            <p className="text-sm font-semibold text-white">' + clientName + '</p>',
  '            <p className="text-xs text-gray-500">' + enabledCount + ' ' + t('סוכנים פעילים', 'agents active') + '</p>',
  "          </div>",
  '          <div className="mt-3 flex items-center gap-2">',
  '            <div className="w-6 h-6 rounded bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center">',
  '              <Zap className="w-3 h-3 text-white" />',
  "            </div>",
  "            <div>",
  '              <p className="text-[10px] text-gray-500">Powered by</p>',
  '              <p className="text-xs font-semibold text-gray-300">MSApps OpsAgent</p>',
  "            </div>",
  "          </div>",
  "        </div>",
  "      </aside>",
  "",
  '      <main className="lg:m' + sideDir + '-64 min-h-screen pt-14 lg:pt-0">',
  '        <div className="max-w-7xl mx-auto p-6">',
  "          {children}",
  "        </div>",
  "      </main>",
  "    </div>",
  "  );",
  "}",
].join('\n');

// ── page.tsx (overview) ──────────────────────────────
const overview = [
  "'use client';",
  "",
  "import {",
  "  Activity, CheckCircle2, AlertTriangle, Bot, Target, Users,",
  "} from 'lucide-react';",
  "",
  "const kpiCards = [",
  "  { icon: Target, label: '" + t('סוכנים פעילים', 'Active Agents') + "', value: '" + enabledCount + "', trend: 0, color: 'text-blue-400', bg: 'bg-blue-500/10' },",
  "  { icon: Activity, label: '" + t('ריצות היום', 'Runs Today') + "', value: '0', trend: 0, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },",
  "  { icon: CheckCircle2, label: '" + t('אחוז הצלחה', 'Success Rate') + "', value: '—', trend: 0, color: 'text-green-400', bg: 'bg-green-500/10' },",
  "  { icon: Users, label: '" + t('רצים כרגע', 'Running Now') + "', value: '0', trend: 0, color: 'text-purple-400', bg: 'bg-purple-500/10' },",
  "];",
  "",
  "export default function " + pascalName + "Overview() {",
  "  return (",
  "    <div>",
  '      <div className="mb-8 flex items-start justify-between">',
  "        <div>",
  '          <h1 className="text-2xl font-bold text-white">' + t('סקירה כללית', 'Operations Overview') + ' — ' + clientName + '</h1>',
  '          <p className="text-sm text-gray-500 mt-1">' + t('מרכז שליטה תפעולי מונע AI', 'AI-powered operations center') + '</p>',
  "        </div>",
  '        <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-medium border text-emerald-400 bg-emerald-500/10 border-emerald-500/20">',
  '          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />',
  "          " + t('מערכת פעילה', 'System active'),
  "        </div>",
  "      </div>",
  "",
  '      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">',
  "        {kpiCards.map(kpi => (",
  '          <div key={kpi.label} className="bg-surface-raised border border-surface-border rounded-xl p-4">',
  '            <div className="flex items-center gap-3 mb-2">',
  "              <div className={`w-8 h-8 rounded-lg ${kpi.bg} flex items-center justify-center`}>",
  "                <kpi.icon className={`w-4 h-4 ${kpi.color}`} />",
  "              </div>",
  '              <span className="text-xs text-gray-500">{kpi.label}</span>',
  "            </div>",
  '            <p className="text-2xl font-bold text-white">{kpi.value}</p>',
  "          </div>",
  "        ))}",
  "      </div>",
  "",
  '      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">',
  '        <div className="lg:col-span-3">',
  '          <div className="flex items-center gap-2 mb-4">',
  '            <AlertTriangle className="w-4 h-4 text-yellow-400" />',
  '            <h2 className="text-lg font-semibold text-white">' + t('דורש תשומת לב', 'Needs Attention') + '</h2>',
  "          </div>",
  '          <div className="text-center py-8 text-gray-500 border border-surface-border rounded-xl bg-surface-raised">',
  '            <CheckCircle2 className="w-8 h-8 mx-auto mb-2 text-emerald-400 opacity-60" />',
  '            <p className="text-sm">' + t('הכל מטופל!', 'All clear!') + '</p>',
  '            <p className="text-xs text-gray-600 mt-1">' + t('פריטים יופיעו כאן כשהסוכנים יתחילו לעבוד', 'Items will appear once agents start running') + '</p>',
  "          </div>",
  "        </div>",
  '        <div className="lg:col-span-2">',
  '          <div className="flex items-center gap-2 mb-4">',
  '            <Bot className="w-4 h-4 text-blue-400" />',
  '            <h2 className="text-lg font-semibold text-white">' + t('פעילות אחרונה', 'Recent Activity') + '</h2>',
  "          </div>",
  '          <div className="text-center py-8 text-gray-500 border border-surface-border rounded-xl bg-surface-raised">',
  '            <Activity className="w-8 h-8 mx-auto mb-2 text-blue-400 opacity-60" />',
  '            <p className="text-sm">' + t('אין פעילות עדיין', 'No activity yet') + '</p>',
  "          </div>",
  "        </div>",
  "      </div>",
  "    </div>",
  "  );",
  "}",
].join('\n');

// ── agents/page.tsx ──────────────────────────────
const agentsJson = JSON.stringify(agentEntries, null, 2);
const agents = [
  "'use client';",
  "",
  "import { Bot, Play, Clock, CheckCircle2, XCircle } from 'lucide-react';",
  "",
  "const agents = " + agentsJson + ";",
  "",
  "export default function " + pascalName + "Agents() {",
  "  return (",
  "    <div>",
  '      <div className="mb-8">',
  '        <h1 className="text-2xl font-bold text-white">' + t('סוכני AI', 'AI Agents') + ' — ' + clientName + '</h1>',
  '        <p className="text-sm text-gray-500 mt-1">' + t('ניהול והפעלת סוכנים', 'Manage and run agents') + '</p>',
  "      </div>",
  '      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">',
  "        {agents.map(agent => (",
  "          <div",
  '            key={agent.id}',
  '            className="bg-surface-raised border border-surface-border rounded-xl p-4 hover:border-' + brandColor + '-500/30 transition-all"',
  "          >",
  '            <div className="flex items-center justify-between mb-3">',
  '              <div className="flex items-center gap-2">',
  '                <div className="w-8 h-8 rounded-lg bg-' + brandColor + '-500/10 flex items-center justify-center">',
  '                  <Bot className="w-4 h-4 text-' + brandColor + '-400" />',
  "                </div>",
  '                <span className="text-sm font-semibold text-white">{agent.name}</span>',
  "              </div>",
  "              <span className={`flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full ${",
  "                agent.enabled ? 'text-emerald-400 bg-emerald-500/20' : 'text-gray-500 bg-gray-500/10'",
  "              }`}>",
  '                {agent.enabled ? <CheckCircle2 className="w-3 h-3" /> : <XCircle className="w-3 h-3" />}',
  "                {agent.enabled ? '" + t('פעיל', 'Enabled') + "' : '" + t('מושבת', 'Disabled') + "'}",
  "              </span>",
  "            </div>",
  '            <div className="flex items-center gap-1.5 text-xs text-gray-500 mb-3">',
  '              <Clock className="w-3 h-3" />',
  "              <span>{agent.schedule || '" + t('ידני בלבד', 'Manual only') + "'}</span>",
  "            </div>",
  '            <button className="w-full flex items-center justify-center gap-2 py-2 rounded-lg text-xs font-medium bg-' + brandColor + '-500/15 text-' + brandColor + '-400 hover:bg-' + brandColor + '-500/25 border border-' + brandColor + '-500/20 transition-colors">',
  '              <Play className="w-3 h-3" />',
  "              " + t('הפעל עכשיו', 'Run Now'),
  "            </button>",
  "          </div>",
  "        ))}",
  "      </div>",
  "    </div>",
  "  );",
  "}",
].join('\n');

// Write files
fs.writeFileSync(path.join(outDir, 'layout.tsx'), layout);
fs.writeFileSync(path.join(outDir, 'page.tsx'), overview);
fs.writeFileSync(path.join(outDir, 'agents', 'page.tsx'), agents);

console.log('\nClient dashboard generated for "' + clientName + '" (' + clientId + ')');
console.log('  Location: dashboard/src/app/demo/' + clientId + '/');
console.log('  Files: layout.tsx, page.tsx, agents/page.tsx');
console.log('  Route: /demo/' + clientId);
console.log('  Language: ' + lang + ' | RTL: ' + rtl + ' | Brand: ' + brandColor);
console.log();

function toPascalCase(str) {
  return str.split(/[-_]/).map(w => w.charAt(0).toUpperCase() + w.slice(1)).join('');
}
