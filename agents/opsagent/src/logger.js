import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const LOGS_DIR = path.join(__dirname, '..', 'logs');

export function saveLog(result) {
  const { clientId, agentName, timestamp, output, usage } = result;
  const date = timestamp.slice(0, 10); // YYYY-MM-DD
  const dir = path.join(LOGS_DIR, clientId, agentName);

  fs.mkdirSync(dir, { recursive: true });

  const file = path.join(dir, `${date}.md`);
  const header = `# ${agentName} — ${clientId} — ${timestamp}\n\n` +
    `> Tokens: ${usage.input_tokens} in / ${usage.output_tokens} out\n\n---\n\n`;

  fs.writeFileSync(file, header + output);
  return file;
}

export function listLogs(clientId, agentName) {
  const dir = path.join(LOGS_DIR, clientId || '', agentName || '');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith('.md')).sort().reverse();
}

export function readLog(clientId, agentName, date) {
  const file = path.join(LOGS_DIR, clientId, agentName, `${date}.md`);
  return fs.existsSync(file) ? fs.readFileSync(file, 'utf-8') : null;
}
