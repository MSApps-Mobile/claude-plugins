import 'dotenv/config';
import express from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { runAgent } from './runner.js';
import { saveLog, listLogs, readLog } from './logger.js';
import { parseAgentOutput, buildExecutionLog } from './output-parser.js';
import {
  loadAllClients,
  getClient,
  getClientsSummary,
  checkClientHealth,
  checkAllClientsHealth,
  saveClient,
  deleteClient,
} from './client-registry.js';
import { proxyToClient, proxySSEToClient } from './tunnel-proxy.js';
import {
  listCoworkTasks,
  getCoworkTask,
  getCoworkTaskOutput,
  updateCoworkTaskMeta,
} from './cowork-bridge.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CLIENTS_DIR = path.join(__dirname, '..', 'clients');
const AGENTS_DIR = path.join(__dirname, '..', 'agents');
const LOGS_DIR = path.join(__dirname, '..', 'logs');
const PORT = process.env.DASHBOARD_PORT || 4242;

const app = express();
app.use(express.json());

// CORS — allow the Netlify dashboard to call this API
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// Track running agents for stop functionality
const runningAgents = new Map();

// ── API ──────────────────────────────────────────────────────────────────────

// Use the client registry for loading clients (backward compat wrapper)
function loadClients() {
  return loadAllClients();
}

function getLastRun(clientId, agentName) {
  const logs = listLogs(clientId, agentName);
  if (!logs.length) return null;
  const date = logs[0].replace('.md', '');
  const content = readLog(clientId, agentName, date);
  const tsMatch = content?.match(/^# .+ — (.+)$/m);
  const tokensMatch = content?.match(/Tokens: (\d+) in \/ (\d+) out/);
  return {
    date,
    timestamp: tsMatch?.[1] ?? date,
    tokensIn: tokensMatch ? parseInt(tokensMatch[1]) : null,
    tokensOut: tokensMatch ? parseInt(tokensMatch[2]) : null,
    preview: content?.slice(content.indexOf('---\n\n') + 5, 300) ?? '',
  };
}

app.get('/api/status', (req, res) => {
  const clients = loadClients();
  const agents = fs.existsSync(AGENTS_DIR)
    ? fs.readdirSync(AGENTS_DIR).filter(f => f.endsWith('.md')).map(f => f.replace('.md', ''))
    : [];

  const data = clients.map(client => ({
    id: client.id,
    name: client.name,
    timezone: client.timezone,
    industry: client.industry,
    agents: Object.entries(client.agents ?? {}).map(([name, cfg]) => ({
      name,
      enabled: cfg.enabled ?? false,
      schedule: cfg.schedule ?? null,
      lastRun: getLastRun(client.id, name),
      logCount: listLogs(client.id, name).length,
    })),
  }));

  res.json({ clients: data, availableAgents: agents });
});

app.get('/api/logs/:clientId/:agentName', (req, res) => {
  const { clientId, agentName } = req.params;
  const logs = listLogs(clientId, agentName);
  res.json({ logs });
});

app.get('/api/logs/:clientId/:agentName/:date', (req, res) => {
  const { clientId, agentName, date } = req.params;
  const content = readLog(clientId, agentName, date);
  if (!content) return res.status(404).json({ error: 'Log not found' });
  res.json({ content });
});

// Run agent — streams progress via SSE
app.get('/api/run/:clientId/:agentName', async (req, res) => {
  const { clientId, agentName } = req.params;

  const clients = loadClients();
  const client = clients.find(c => c.id === clientId);
  if (!client) return res.status(404).end();

  // SSE headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const send = (event, data) => res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);

  const runKey = `${clientId}:${agentName}`;
  const controller = new AbortController();
  runningAgents.set(runKey, controller);

  send('start', { clientId, agentName, timestamp: new Date().toISOString() });

  try {
    send('log', { message: `Launching agent for ${client.name}...` });

    const onProgress = (event) => {
      if (event.type === 'init') {
        send('log', { message: `Session started: ${event.sessionId ?? '(local)'}` });
      } else if (event.type === 'tool') {
        send('log', { message: `Using tool: ${event.name}` });
      } else if (event.type === 'text') {
        send('log', { message: `Working... (${event.text.slice(0, 60)}${event.text.length > 60 ? '...' : ''})` });
      }
    };

    const result = await runAgent(client, agentName, onProgress);
    const logFile = saveLog(result);
    send('log', { message: `Completed in ${result.elapsed}s — saved to ${path.basename(logFile)}` });
    send('done', { output: result.output, usage: result.usage, elapsed: result.elapsed, logFile });
  } catch (err) {
    send('error', { message: err.message });
  }

  runningAgents.delete(runKey);
  res.end();
});

// Stop a running agent
app.post('/api/stop/:clientId/:agentName', (req, res) => {
  const key = `${req.params.clientId}:${req.params.agentName}`;
  const controller = runningAgents.get(key);
  if (controller) {
    controller.abort();
    runningAgents.delete(key);
    res.json({ stopped: true });
  } else {
    res.json({ stopped: false, message: 'Agent is not currently running' });
  }
});

// Update agent schedule
app.put('/api/schedule/:clientId/:agentName', (req, res) => {
  const { clientId, agentName } = req.params;
  const { schedule, enabled } = req.body;
  const configPath = path.join(CLIENTS_DIR, `${clientId}.json`);

  if (!fs.existsSync(configPath)) return res.status(404).json({ error: 'Client not found' });

  const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
  if (!config.agents?.[agentName]) return res.status(404).json({ error: 'Agent not found' });

  if (schedule !== undefined) config.agents[agentName].schedule = schedule;
  if (enabled !== undefined) config.agents[agentName].enabled = enabled;

  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  res.json({ updated: true, agent: config.agents[agentName] });
});

// Get parsed/structured output for a specific log
app.get('/api/logs/:clientId/:agentName/:date/parsed', (req, res) => {
  const { clientId, agentName, date } = req.params;
  const content = readLog(clientId, agentName, date);
  if (!content) return res.status(404).json({ error: 'Log not found' });

  const executionLog = buildExecutionLog(clientId, agentName, date, content);
  res.json(executionLog);
});

// Get all parsed execution logs for a client (history)
app.get('/api/history/:clientId', (req, res) => {
  const { clientId } = req.params;
  const client = loadClients().find(c => c.id === clientId);
  if (!client) return res.status(404).json({ error: 'Client not found' });

  const logs = [];
  for (const agentName of Object.keys(client.agents ?? {})) {
    const dates = listLogs(clientId, agentName);
    for (const file of dates.slice(0, 5)) { // last 5 per agent
      const date = file.replace('.md', '');
      const content = readLog(clientId, agentName, date);
      if (content) {
        const entry = buildExecutionLog(clientId, agentName, date, content);
        if (entry) logs.push(entry);
      }
    }
  }

  // Sort by date descending
  logs.sort((a, b) => b.startedAt.localeCompare(a.startedAt));
  res.json({ logs });
});

// Documents endpoint — list generated documents from agent outputs
app.get('/api/documents/:clientId', (req, res) => {
  const { clientId } = req.params;
  const client = loadClients().find(c => c.id === clientId);
  if (!client) return res.status(404).json({ error: 'Client not found' });

  const documents = [];
  for (const agentName of Object.keys(client.agents ?? {})) {
    const dates = listLogs(clientId, agentName);
    for (const file of dates.slice(0, 10)) {
      const date = file.replace('.md', '');
      const content = readLog(clientId, agentName, date);
      if (content) {
        const parsed = parseAgentOutput(content, agentName);
        const docSection = parsed.find(s => s.type === 'documents');
        if (docSection?.items.length > 0) {
          for (const doc of docSection.items) {
            documents.push({
              ...doc,
              agentName,
              date,
              id: `${clientId}-${agentName}-${date}-${documents.length}`,
            });
          }
        }
      }
    }
  }

  res.json({ documents });
});

// ── Approvals ────────────────────────────────────────────────────────────────

// In-memory approval queue (persists in process lifetime)
const approvalQueue = [];
let approvalIdCounter = 1;

// List pending approvals
app.get('/api/approvals/:clientId', (req, res) => {
  const { clientId } = req.params;
  const { status } = req.query; // 'pending' | 'approved' | 'denied' | 'all'
  let filtered = approvalQueue.filter(a => a.clientId === clientId);
  if (status && status !== 'all') {
    filtered = filtered.filter(a => a.status === status);
  }
  filtered.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  res.json({ approvals: filtered });
});

// Create an approval request (called by agent runner)
app.post('/api/approvals/:clientId', (req, res) => {
  const { clientId } = req.params;
  const { agentName, action, description, riskLevel, estimatedCost } = req.body;

  const approval = {
    id: `apr-${approvalIdCounter++}`,
    clientId,
    agentName,
    action,
    description,
    riskLevel: riskLevel || 'medium', // 'low' | 'medium' | 'high'
    estimatedCost: estimatedCost || null,
    status: 'pending',
    createdAt: new Date().toISOString(),
    resolvedAt: null,
    resolvedBy: null,
  };

  approvalQueue.push(approval);
  res.json(approval);
});

// Approve or deny
app.post('/api/approvals/:clientId/:approvalId/:decision', (req, res) => {
  const { clientId, approvalId, decision } = req.params;
  if (!['approve', 'deny'].includes(decision)) {
    return res.status(400).json({ error: 'Decision must be approve or deny' });
  }

  const approval = approvalQueue.find(a => a.id === approvalId && a.clientId === clientId);
  if (!approval) return res.status(404).json({ error: 'Approval not found' });

  approval.status = decision === 'approve' ? 'approved' : 'denied';
  approval.resolvedAt = new Date().toISOString();
  approval.resolvedBy = 'dashboard-user';

  res.json(approval);
});

// List running agents
app.get('/api/running', (req, res) => {
  const running = [];
  for (const [key] of runningAgents) {
    const [clientId, agentName] = key.split(':');
    running.push({ clientId, agentName });
  }
  res.json({ running });
});

// ── Client Management API ────────────────────────────────────────────────────

// List all clients with connection status
app.get('/api/clients', (req, res) => {
  const summary = getClientsSummary();
  res.json({ clients: summary });
});

// Get a single client's full config
app.get('/api/clients/:clientId', (req, res) => {
  const client = getClient(req.params.clientId);
  if (!client) return res.status(404).json({ error: 'Client not found' });
  res.json(client);
});

// Create or update a client
app.put('/api/clients/:clientId', (req, res) => {
  const clientConfig = { ...req.body, id: req.params.clientId };
  const filePath = saveClient(clientConfig);
  res.json({ saved: true, path: filePath });
});

// Delete a client
app.delete('/api/clients/:clientId', (req, res) => {
  const deleted = deleteClient(req.params.clientId);
  res.json({ deleted });
});

// Health check for a single client's VM
app.get('/api/clients/:clientId/health', async (req, res) => {
  const result = await checkClientHealth(req.params.clientId);
  res.json(result);
});

// Health check for all clients' VMs
app.get('/api/health', async (req, res) => {
  const results = await checkAllClientsHealth();
  res.json({ clients: results });
});

// ── Cowork Sync + Tasks API ─────────────────────────────────────────────────

// Last synced snapshot from the Mac (received via cowork-sync.js)
let coworkSnapshot = null;

// Receive sync push from the Mac's cowork-sync daemon
app.post('/api/cowork/sync', (req, res) => {
  coworkSnapshot = req.body;
  coworkSnapshot.receivedAt = new Date().toISOString();
  console.log(`[sync] Received snapshot: ${coworkSnapshot.taskCount} tasks from ${coworkSnapshot.hostname}`);
  res.json({ ok: true, taskCount: coworkSnapshot.taskCount });
});

// Get the last synced snapshot (for dashboard when Mac is offline)
app.get('/api/cowork/snapshot', (req, res) => {
  if (!coworkSnapshot) {
    // Try to read from local bridge as fallback
    const tasks = listCoworkTasks();
    return res.json({ tasks, source: 'local', timestamp: new Date().toISOString() });
  }
  res.json({ ...coworkSnapshot, source: 'sync' });
});

// List all Cowork scheduled tasks (prefers synced snapshot, falls back to local)
app.get('/api/cowork/tasks', (req, res) => {
  if (coworkSnapshot) {
    return res.json({ tasks: coworkSnapshot.tasks, source: 'sync' });
  }
  const tasks = listCoworkTasks();
  res.json({ tasks, source: 'local' });
});

// Get a single task with full details
app.get('/api/cowork/tasks/:taskId', (req, res) => {
  const task = getCoworkTask(req.params.taskId);
  if (!task) return res.status(404).json({ error: 'Task not found' });
  res.json(task);
});

// Get task output (latest or specific session)
app.get('/api/cowork/tasks/:taskId/output', (req, res) => {
  const output = getCoworkTaskOutput(req.params.taskId, req.query.sessionId);
  if (!output) return res.json({ sessionId: null, files: {} });
  res.json(output);
});

// Update task metadata (enable/disable, schedule)
app.put('/api/cowork/tasks/:taskId', (req, res) => {
  const updated = updateCoworkTaskMeta(req.params.taskId, req.body);
  if (!updated) return res.status(404).json({ error: 'Task not found' });
  res.json(updated);
});

// ── Tunnel Proxy ─────────────────────────────────────────────────────────────

// Proxy any API call to a client's VM
// GET /api/proxy/:clientId/status → VM's /api/status
app.get('/api/proxy/:clientId/*', async (req, res) => {
  const { clientId } = req.params;
  const apiPath = req.params[0]; // everything after /api/proxy/:clientId/

  // Special case: SSE streams for agent runs
  if (apiPath.startsWith('run/')) {
    return proxySSEToClient(clientId, apiPath, res);
  }

  const result = await proxyToClient(clientId, apiPath);
  res.status(result.status).json(result.data || { error: result.error });
});

// Proxy POST/PUT to client VM
app.post('/api/proxy/:clientId/*', async (req, res) => {
  const { clientId } = req.params;
  const apiPath = req.params[0];
  const result = await proxyToClient(clientId, apiPath, { method: 'POST', body: req.body });
  res.status(result.status).json(result.data || { error: result.error });
});

app.put('/api/proxy/:clientId/*', async (req, res) => {
  const { clientId } = req.params;
  const apiPath = req.params[0];
  const result = await proxyToClient(clientId, apiPath, { method: 'PUT', body: req.body });
  res.status(result.status).json(result.data || { error: result.error });
});

// ── HTML UI ──────────────────────────────────────────────────────────────────

app.get('/', (req, res) => res.send(HTML));

app.listen(PORT, () => {
  console.log(`\n🤖 OpsAgent Dashboard → http://localhost:${PORT}\n`);
});

// ── Embedded Dashboard HTML ───────────────────────────────────────────────────

const HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>OpsAgent Dashboard</title>
<meta name="description" content="AI-powered operations automation platform">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🤖</text></svg>">
<style>
:root {
  --bg: #0F172A;
  --surface: #1E293B;
  --surface2: #263548;
  --border: rgba(255,255,255,0.07);
  --primary: #6C3AED;
  --primary-light: #8B5CF6;
  --accent: #10B981;
  --accent-dark: #059669;
  --text: #F1F5F9;
  --muted: rgba(255,255,255,0.45);
  --red: #EF4444;
}
* { margin:0; padding:0; box-sizing:border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Inter', sans-serif; background: var(--bg); color: var(--text); min-height:100vh; }

/* NAV */
nav { background: rgba(30,41,59,0.9); backdrop-filter: blur(12px); border-bottom: 1px solid var(--border); padding: 0 2rem; height: 56px; display:flex; align-items:center; justify-content:space-between; position:sticky; top:0; z-index:50; }
.nav-logo { font-size:1.1rem; font-weight:800; display:flex; align-items:center; gap:.5rem; }
.nav-logo .dot { width:10px; height:10px; background:var(--accent); border-radius:50%; animation: pulse 2s infinite; }
.nav-right { font-size:.8rem; color:var(--muted); }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.4} }

/* LAYOUT */
.container { max-width:1200px; margin:0 auto; padding:2rem; }
h1 { font-size:1.5rem; font-weight:700; margin-bottom:.25rem; }
.subtitle { color:var(--muted); font-size:.9rem; margin-bottom:2rem; }

/* CLIENT CARD */
.client { background: var(--surface); border:1px solid var(--border); border-radius:16px; padding:1.5rem; margin-bottom:1.5rem; }
.client-header { display:flex; align-items:center; justify-content:space-between; margin-bottom:1rem; }
.client-name { font-size:1.1rem; font-weight:700; }
.client-meta { font-size:.8rem; color:var(--muted); }
.agents-grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(280px,1fr)); gap:.75rem; }

/* AGENT CARD */
.agent { background: var(--surface2); border:1px solid var(--border); border-radius:12px; padding:1rem; transition:border-color .2s; cursor:pointer; }
.agent:hover { border-color: rgba(139,92,246,.4); }
.agent-top { display:flex; align-items:center; justify-content:space-between; margin-bottom:.75rem; }
.agent-name { font-weight:600; font-size:.9rem; display:flex; align-items:center; gap:.5rem; }
.badge { font-size:.7rem; font-weight:700; padding:.2rem .5rem; border-radius:100px; }
.badge-on  { background: rgba(16,185,129,.15); color:var(--accent); }
.badge-off { background: rgba(255,255,255,.06); color:var(--muted); }
.agent-schedule { font-size:.75rem; color:var(--muted); font-family: monospace; }
.agent-last { font-size:.75rem; color:var(--muted); margin-top:.5rem; }
.agent-last span { color:var(--text); }
.run-btn { margin-top:.75rem; width:100%; padding:.45rem; background: rgba(108,58,237,.2); border:1px solid rgba(108,58,237,.3); color:var(--primary-light); border-radius:8px; font-size:.8rem; font-weight:600; cursor:pointer; transition:all .2s; }
.run-btn:hover { background:var(--primary); color:#fff; border-color:var(--primary); }
.run-btn:disabled { opacity:.4; cursor:not-allowed; }
.run-btn.running { background: rgba(16,185,129,.15); border-color:rgba(16,185,129,.3); color:var(--accent); }

/* MODAL */
.overlay { display:none; position:fixed; inset:0; background:rgba(0,0,0,.7); z-index:100; align-items:center; justify-content:center; }
.overlay.open { display:flex; }
.modal { background:var(--surface); border:1px solid var(--border); border-radius:20px; width:min(800px,95vw); max-height:85vh; display:flex; flex-direction:column; }
.modal-header { padding:1.25rem 1.5rem; border-bottom:1px solid var(--border); display:flex; align-items:center; justify-content:space-between; }
.modal-title { font-weight:700; font-size:1rem; }
.modal-close { background:none; border:none; color:var(--muted); cursor:pointer; font-size:1.25rem; }
.modal-body { padding:1.5rem; overflow-y:auto; flex:1; }
.log-tabs { display:flex; gap:.5rem; margin-bottom:1rem; flex-wrap:wrap; }
.log-tab { padding:.3rem .75rem; border-radius:8px; font-size:.8rem; cursor:pointer; border:1px solid var(--border); background:none; color:var(--muted); }
.log-tab.active { background:var(--primary); color:#fff; border-color:var(--primary); }
.log-content { background:var(--bg); border-radius:8px; padding:1rem; font-size:.82rem; line-height:1.7; white-space:pre-wrap; overflow-x:auto; max-height:500px; overflow-y:auto; }
.stream-output { background:var(--bg); border-radius:8px; padding:1rem; font-size:.82rem; line-height:1.7; font-family:monospace; max-height:400px; overflow-y:auto; white-space:pre-wrap; }
.stream-line { color:var(--accent); }
.stream-done { color:var(--text); margin-top:.5rem; border-top:1px solid var(--border); padding-top:.5rem; }
.stream-error { color:var(--red); }

/* EMPTY */
.empty { text-align:center; padding:4rem 2rem; color:var(--muted); }
.empty h3 { font-size:1.1rem; margin-bottom:.5rem; }

/* LOADING */
.loading { color:var(--muted); font-size:.85rem; text-align:center; padding:3rem; }
.spinner { display:inline-block; width:20px; height:20px; border:2px solid var(--border); border-top-color:var(--primary); border-radius:50%; animation: spin .7s linear infinite; margin-right:.5rem; vertical-align:middle; }
@keyframes spin { to { transform:rotate(360deg); } }

/* RESPONSIVE */
@media(max-width:600px) { .container{padding:1rem;} }
</style>
</head>
<body>

<nav>
  <div class="nav-logo">
    <div class="dot"></div>
    OpsAgent
  </div>
  <div class="nav-right" id="nav-time">—</div>
</nav>

<div class="container">
  <h1>Operations Dashboard</h1>
  <p class="subtitle">All clients · All agents · Phase 1 — supervised mode</p>
  <div id="main"><div class="loading"><span class="spinner"></span>Loading...</div></div>
</div>

<!-- Modal -->
<div class="overlay" id="overlay" onclick="if(event.target===this)closeModal()">
  <div class="modal">
    <div class="modal-header">
      <div class="modal-title" id="modal-title">—</div>
      <button class="modal-close" onclick="closeModal()">✕</button>
    </div>
    <div class="modal-body" id="modal-body"></div>
  </div>
</div>

<script>
let statusData = null;

async function load() {
  try {
    const res = await fetch('/api/status');
    statusData = await res.json();
    render(statusData);
  } catch(e) {
    document.getElementById('main').innerHTML = '<div class="empty"><h3>Failed to load</h3><p>'+e.message+'</p></div>';
  }
}

function render(data) {
  const main = document.getElementById('main');
  if (!data.clients.length) {
    main.innerHTML = '<div class="empty"><h3>No clients yet</h3><p>Add a JSON file to clients/ to get started.</p></div>';
    return;
  }
  main.innerHTML = data.clients.map(client => renderClient(client)).join('');
}

function renderClient(client) {
  const agentCards = client.agents.map(a => renderAgent(client.id, a)).join('');
  return \`<div class="client">
    <div class="client-header">
      <div>
        <div class="client-name">\${client.name}</div>
        <div class="client-meta">\${client.industry || ''} · \${client.timezone || ''}</div>
      </div>
      <div class="client-meta">\${client.agents.filter(a=>a.enabled).length} / \${client.agents.length} agents active</div>
    </div>
    <div class="agents-grid">\${agentCards}</div>
  </div>\`;
}

function renderAgent(clientId, agent) {
  const last = agent.lastRun;
  const lastText = last
    ? \`Last run: <span>\${last.date}</span> · \${last.tokensOut ? last.tokensOut + ' tokens out' : ''}\`
    : 'Never run';
  const schedText = agent.schedule ? \`<div class="agent-schedule">\${agent.schedule}</div>\` : '';

  return \`<div class="agent" onclick="openLogs('\${clientId}','\${agent.name}')">
    <div class="agent-top">
      <div class="agent-name">
        \${iconFor(agent.name)}
        \${agent.name}
      </div>
      <span class="badge \${agent.enabled ? 'badge-on' : 'badge-off'}">\${agent.enabled ? 'ON' : 'OFF'}</span>
    </div>
    \${schedText}
    <div class="agent-last">\${lastText}</div>
    <button class="run-btn" id="btn-\${clientId}-\${agent.name}"
      onclick="event.stopPropagation(); runAgent('\${clientId}','\${agent.name}')">
      ▶ Run Now
    </button>
  </div>\`;
}

function iconFor(name) {
  const icons = { 'lead-pipeline':'📊', 'linkedin-outreach':'💼', 'social-posts':'📝', 'receipts':'🧾', 'invoicing':'💰', 'recruiter':'🎯' };
  return icons[name] || '🤖';
}

async function openLogs(clientId, agentName) {
  document.getElementById('modal-title').textContent = iconFor(agentName) + ' ' + agentName + ' — ' + clientId;
  document.getElementById('modal-body').innerHTML = '<div class="loading"><span class="spinner"></span>Loading logs...</div>';
  document.getElementById('overlay').classList.add('open');

  const res = await fetch(\`/api/logs/\${clientId}/\${agentName}\`);
  const { logs } = await res.json();

  if (!logs.length) {
    document.getElementById('modal-body').innerHTML = '<div class="empty"><h3>No logs yet</h3><p>Run this agent to see output here.</p></div>';
    return;
  }

  renderLogView(clientId, agentName, logs, logs[0].replace('.md',''));
}

async function renderLogView(clientId, agentName, logs, activeDate) {
  const tabs = logs.map(f => {
    const d = f.replace('.md','');
    return \`<button class="log-tab \${d===activeDate?'active':''}" onclick="renderLogView('\${clientId}','\${agentName}',\${JSON.stringify(logs)},'\${d}')">\${d}</button>\`;
  }).join('');

  document.getElementById('modal-body').innerHTML = \`<div class="log-tabs">\${tabs}</div><div class="log-content" id="log-text"><span class="spinner"></span></div>\`;

  const res = await fetch(\`/api/logs/\${clientId}/\${agentName}/\${activeDate}\`);
  const { content } = await res.json();
  // strip frontmatter header, show content
  const body = content.replace(/^#.+\\n\\n>.*\\n\\n---\\n\\n/, '');
  document.getElementById('log-text').textContent = body;
}

function closeModal() {
  document.getElementById('overlay').classList.remove('open');
}

async function runAgent(clientId, agentName) {
  const btn = document.getElementById(\`btn-\${clientId}-\${agentName}\`);
  btn.disabled = true;
  btn.textContent = '⏳ Running...';
  btn.classList.add('running');

  document.getElementById('modal-title').textContent = iconFor(agentName) + ' ' + agentName + ' — running...';
  document.getElementById('modal-body').innerHTML = '<div class="stream-output" id="stream"></div>';
  document.getElementById('overlay').classList.add('open');

  const stream = document.getElementById('stream');
  const append = (cls, text) => {
    const div = document.createElement('div');
    div.className = cls;
    div.textContent = text;
    stream.appendChild(div);
    stream.scrollTop = stream.scrollHeight;
  };

  try {
    const es = new EventSource(\`/api/run/\${clientId}/\${agentName}\`);

    es.addEventListener('start', e => { const d = JSON.parse(e.data); append('stream-line', '▶ Starting ' + d.agentName + ' for ' + d.clientId + '...'); });
    es.addEventListener('log',   e => { const d = JSON.parse(e.data); append('stream-line', '  ' + d.message); });
    es.addEventListener('done',  e => {
      const d = JSON.parse(e.data);
      append('stream-done', '✅ Done · ' + d.usage.output_tokens + ' tokens out');
      stream.innerHTML += '<hr style="border-color:var(--border);margin:.75rem 0"><div style="white-space:pre-wrap;font-size:.82rem;line-height:1.7">' + escHtml(d.output) + '</div>';
      es.close();
      btn.disabled = false;
      btn.textContent = '▶ Run Now';
      btn.classList.remove('running');
      document.getElementById('modal-title').textContent = iconFor(agentName) + ' ' + agentName + ' — ' + clientId;
      load(); // refresh status
    });
    es.addEventListener('error', e => {
      try { const d = JSON.parse(e.data); append('stream-error', '❌ ' + d.message); } catch {}
      es.close();
      btn.disabled = false;
      btn.textContent = '▶ Run Now';
      btn.classList.remove('running');
    });
  } catch(e) {
    append('stream-error', '❌ ' + e.message);
    btn.disabled = false;
    btn.textContent = '▶ Run Now';
    btn.classList.remove('running');
  }
}

function escHtml(t) {
  return t.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

// Clock
function tick() {
  document.getElementById('nav-time').textContent = new Date().toLocaleString('en-IL', { timeZone:'Asia/Jerusalem', hour:'2-digit', minute:'2-digit', weekday:'short', month:'short', day:'numeric' });
}
tick();
setInterval(tick, 30000);

load();
</script>
</body>
</html>`;

export default app;
