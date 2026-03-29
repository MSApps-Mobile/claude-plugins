#!/usr/bin/env node
import 'dotenv/config';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { runAgent } from './runner.js';
import { saveLog, listLogs } from './logger.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CLIENTS_DIR = path.join(__dirname, '..', 'clients');
const AGENTS_DIR = path.join(__dirname, '..', 'agents');

function loadClient(clientId) {
  const file = path.join(CLIENTS_DIR, `${clientId}.json`);
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf-8'));
}

function listClients() {
  if (!fs.existsSync(CLIENTS_DIR)) return [];
  return fs.readdirSync(CLIENTS_DIR)
    .filter(f => f.endsWith('.json') && f !== 'template.json')
    .map(f => f.replace('.json', ''));
}

function listAgents() {
  if (!fs.existsSync(AGENTS_DIR)) return [];
  return fs.readdirSync(AGENTS_DIR)
    .filter(f => f.endsWith('.md'))
    .map(f => f.replace('.md', ''));
}

// Usage: node src/cli.js [clientId] [agentName]
const [, , clientId, agentName] = process.argv;

if (!clientId || !agentName) {
  console.log('\nUsage: node src/cli.js <clientId> <agentName>\n');
  console.log('Clients:', listClients().join(', ') || '(none)');
  console.log('Agents: ', listAgents().join(', ') || '(none)');
  console.log('\nExample: node src/cli.js msapps lead-pipeline\n');
  process.exit(0);
}

const clientConfig = loadClient(clientId);
if (!clientConfig) {
  console.error(`Client not found: ${clientId}`);
  console.error('Available:', listClients().join(', '));
  process.exit(1);
}

const agentFile = path.join(AGENTS_DIR, `${agentName}.md`);
if (!fs.existsSync(agentFile)) {
  console.error(`Agent not found: ${agentName}`);
  console.error('Available:', listAgents().join(', '));
  process.exit(1);
}

console.log(`\n🤖 Running [${clientId}] ${agentName}...\n`);

try {
  const result = await runAgent(clientConfig, agentName);
  const logFile = saveLog(result);
  console.log(`\n${'─'.repeat(60)}`);
  console.log(result.output);
  console.log(`${'─'.repeat(60)}`);
  console.log(`\n✅ Saved to: ${logFile}`);
  console.log(`   Tokens: ${result.usage.input_tokens} in / ${result.usage.output_tokens} out\n`);
} catch (err) {
  console.error('\n❌ Error:', err.message);
  process.exit(1);
}
