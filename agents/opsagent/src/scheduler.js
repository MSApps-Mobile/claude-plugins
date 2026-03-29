import cron from 'node-cron';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { runAgent } from './runner.js';
import { saveLog } from './logger.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CLIENTS_DIR = path.join(__dirname, '..', 'clients');

function loadClients() {
  if (!fs.existsSync(CLIENTS_DIR)) return [];
  return fs.readdirSync(CLIENTS_DIR)
    .filter(f => f.endsWith('.json') && f !== 'template.json')
    .map(f => {
      try {
        return JSON.parse(fs.readFileSync(path.join(CLIENTS_DIR, f), 'utf-8'));
      } catch (e) {
        console.error(`Failed to load client config ${f}:`, e.message);
        return null;
      }
    })
    .filter(Boolean);
}

export function startScheduler() {
  const clients = loadClients();

  if (clients.length === 0) {
    console.log('No client configs found in clients/. Add a client JSON to get started.');
    return;
  }

  let jobCount = 0;

  for (const client of clients) {
    const agents = client.agents ?? {};

    for (const [agentName, agentConfig] of Object.entries(agents)) {
      if (!agentConfig.enabled) continue;
      if (!agentConfig.schedule) continue;

      if (!cron.validate(agentConfig.schedule)) {
        console.warn(`Invalid cron for ${client.id}/${agentName}: "${agentConfig.schedule}"`);
        continue;
      }

      cron.schedule(agentConfig.schedule, async () => {
        console.log(`\n⚡ Scheduled run: [${client.id}] ${agentName}`);
        try {
          const result = await runAgent(client, agentName);
          const logFile = saveLog(result);
          console.log(`  ✅ Saved → ${logFile}`);
        } catch (err) {
          console.error(`  ❌ Failed [${client.id}] ${agentName}:`, err.message);
        }
      }, { timezone: client.timezone ?? 'Asia/Jerusalem' });

      console.log(`  ✓ Scheduled [${client.id}] ${agentName} @ ${agentConfig.schedule}`);
      jobCount++;
    }
  }

  console.log(`\n${jobCount} job(s) scheduled across ${clients.length} client(s). Waiting...\n`);
}
