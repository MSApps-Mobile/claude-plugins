#!/usr/bin/env node

/**
 * Client Provisioning Script
 *
 * Full onboarding workflow for a new OpsAgent client:
 *   1. Creates client config in clients/<client-id>.json
 *   2. Generates branded dashboard pages
 *   3. Outputs next steps (VM setup, tunnel, MCP servers)
 *
 * Usage:
 *   node scripts/provision-client.js --id <client-id> --name "Client Name" [options]
 *
 * Options:
 *   --id          Client ID (required, lowercase, no spaces)
 *   --name        Client display name (required)
 *   --email       Contact email
 *   --timezone    Timezone (default: Asia/Jerusalem)
 *   --industry    Industry description
 *   --size        Company size
 *   --language    Dashboard language: en or he (default: en)
 *   --rtl         Enable RTL layout (auto-enabled for 'he')
 *   --color       Brand color for dashboard (default: blue)
 *   --icon        Lucide icon name for logo (default: Building2)
 *   --tunnel      Tunnel URL for the client's VM
 *   --agents      Comma-separated agent names to enable (default: social-posts,lead-pipeline)
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const CLIENTS_DIR = path.join(ROOT, 'clients');

// Parse args
const args = {};
for (let i = 2; i < process.argv.length; i++) {
  if (process.argv[i].startsWith('--')) {
    const key = process.argv[i].slice(2);
    const val = process.argv[i + 1] && !process.argv[i + 1].startsWith('--')
      ? process.argv[++i]
      : 'true';
    args[key] = val;
  }
}

if (!args.id || !args.name) {
  console.error('Usage: node scripts/provision-client.js --id <client-id> --name "Client Name"');
  console.error('\nOptions:');
  console.error('  --email       Contact email');
  console.error('  --timezone    Timezone (default: Asia/Jerusalem)');
  console.error('  --industry    Industry description');
  console.error('  --size        Company size');
  console.error('  --language    Dashboard language: en or he (default: en)');
  console.error('  --rtl         Enable RTL layout');
  console.error('  --color       Brand color (default: blue)');
  console.error('  --icon        Lucide icon name (default: Building2)');
  console.error('  --tunnel      Tunnel URL for VM');
  console.error('  --agents      Comma-separated agents to enable (default: social-posts,lead-pipeline)');
  process.exit(1);
}

const clientId = args.id;
const language = args.language || 'en';
const rtl = args.rtl === 'true' || language === 'he';
const enabledAgents = (args.agents || 'social-posts,lead-pipeline').split(',').map(a => a.trim());

// Check if client already exists
const configPath = path.join(CLIENTS_DIR, clientId + '.json');
if (fs.existsSync(configPath)) {
  console.error('Client already exists: ' + configPath);
  console.error('Delete it first if you want to re-provision.');
  process.exit(1);
}

// Build client config
const allAgents = ['lead-pipeline', 'linkedin-outreach', 'social-posts', 'receipts', 'invoicing', 'recruiter'];
const agentsConfig = {};
for (const name of allAgents) {
  const enabled = enabledAgents.includes(name);
  const schedules = {
    'lead-pipeline': '0 8 * * 0-4',
    'linkedin-outreach': '0 9 * * 0-4',
    'social-posts': '0 7 * * 0-4',
    'receipts': '0 8 * * 1',
    'invoicing': '0 9 1 * *',
    'recruiter': '0 10 * * 1',
  };
  agentsConfig[name] = {
    enabled,
    schedule: schedules[name] || '0 9 * * 1-5',
    context: {},
  };
}

const clientConfig = {
  id: clientId,
  name: args.name,
  contact_email: args.email || '',
  timezone: args.timezone || 'Asia/Jerusalem',
  industry: args.industry || '',
  company_size: args.size || '',
  tunnel_url: args.tunnel || '',
  vm_id: 'vm-' + clientId + '-001',
  dashboard: {
    route: '/demo/' + clientId,
    language,
    rtl,
    brand_color: args.color || 'blue',
    logo_icon: args.icon || 'Building2',
  },
  agents: agentsConfig,
};

// Step 1: Save client config
console.log('\n=== Provisioning client: ' + args.name + ' (' + clientId + ') ===\n');

fs.writeFileSync(configPath, JSON.stringify(clientConfig, null, 2));
console.log('[1/3] Client config created: clients/' + clientId + '.json');

// Step 2: Generate dashboard
try {
  execSync('node scripts/create-client-dashboard.js ' + clientId, { cwd: ROOT, stdio: 'inherit' });
  console.log('[2/3] Dashboard generated: /demo/' + clientId);
} catch (err) {
  console.error('[2/3] Dashboard generation failed:', err.message);
}

// Step 3: Print next steps
console.log('\n[3/3] Next steps:\n');
console.log('  VM Setup:');
console.log('    1. Provision a virtual Mac VM (vm-' + clientId + '-001)');
console.log('    2. Install Claude Desktop on the VM');
console.log('    3. Configure MCP servers for client integrations');
console.log('    4. Set up Cloudflare Tunnel and update tunnel_url in config');
console.log('');
console.log('  Dashboard:');
console.log('    - Local: npm run dev, then visit /demo/' + clientId);
console.log('    - Customize: edit dashboard/src/app/demo/' + clientId + '/');
console.log('    - Deploy: npx netlify deploy --dir=out --prod');
console.log('');
console.log('  Agent Context:');
console.log('    - Edit clients/' + clientId + '.json to fill in agent context');
console.log('    - Each agent needs domain-specific context (CRM, email, etc.)');
console.log('');
console.log('=== Provisioning complete ===\n');
