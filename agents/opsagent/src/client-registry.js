import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CLIENTS_DIR = path.join(__dirname, '..', 'clients');

/**
 * Client Registry — manages multi-client state and VM connections.
 * Each client has a tunnel_url pointing to their virtual Mac's API.
 */

// In-memory cache of client configs + connection status
const clientStates = new Map();

/**
 * Load all client configs from clients/ directory.
 * Excludes template.json.
 */
export function loadAllClients() {
  if (!fs.existsSync(CLIENTS_DIR)) return [];
  return fs.readdirSync(CLIENTS_DIR)
    .filter(f => f.endsWith('.json') && f !== 'template.json')
    .map(f => {
      const config = JSON.parse(fs.readFileSync(path.join(CLIENTS_DIR, f), 'utf-8'));
      // Initialize state if not tracked yet
      if (!clientStates.has(config.id)) {
        clientStates.set(config.id, {
          connected: false,
          lastHealthCheck: null,
          lastError: null,
        });
      }
      return config;
    });
}

/**
 * Get a single client by ID.
 */
export function getClient(clientId) {
  const clients = loadAllClients();
  return clients.find(c => c.id === clientId) || null;
}

/**
 * Get client connection state.
 */
export function getClientState(clientId) {
  return clientStates.get(clientId) || { connected: false, lastHealthCheck: null, lastError: null };
}

/**
 * Check if a client's VM is reachable via its tunnel_url.
 * Returns { connected, latencyMs, error }.
 */
export async function checkClientHealth(clientId) {
  const client = getClient(clientId);
  if (!client) return { connected: false, latencyMs: null, error: 'Client not found' };
  if (!client.tunnel_url) return { connected: false, latencyMs: null, error: 'No tunnel_url configured' };

  const start = Date.now();
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    const res = await fetch(`${client.tunnel_url}/api/status`, { signal: controller.signal });
    clearTimeout(timeout);
    const latencyMs = Date.now() - start;
    const connected = res.ok;

    clientStates.set(clientId, {
      connected,
      lastHealthCheck: new Date().toISOString(),
      lastError: connected ? null : `HTTP ${res.status}`,
    });

    return { connected, latencyMs, error: connected ? null : `HTTP ${res.status}` };
  } catch (err) {
    const latencyMs = Date.now() - start;
    clientStates.set(clientId, {
      connected: false,
      lastHealthCheck: new Date().toISOString(),
      lastError: err.message,
    });
    return { connected: false, latencyMs, error: err.message };
  }
}

/**
 * Check health of all clients. Returns array of { clientId, ...healthResult }.
 */
export async function checkAllClientsHealth() {
  const clients = loadAllClients();
  const results = await Promise.all(
    clients.map(async (c) => ({
      clientId: c.id,
      clientName: c.name,
      tunnelUrl: c.tunnel_url || null,
      vmId: c.vm_id || null,
      ...(await checkClientHealth(c.id)),
    }))
  );
  return results;
}

/**
 * Get summary of all clients for the dashboard.
 */
export function getClientsSummary() {
  const clients = loadAllClients();
  return clients.map(c => {
    const state = getClientState(c.id);
    const enabledAgents = Object.values(c.agents || {}).filter(a => a.enabled).length;
    const totalAgents = Object.keys(c.agents || {}).length;
    return {
      id: c.id,
      name: c.name,
      industry: c.industry,
      timezone: c.timezone,
      tunnelUrl: c.tunnel_url || null,
      vmId: c.vm_id || null,
      dashboard: c.dashboard || null,
      connected: state.connected,
      lastHealthCheck: state.lastHealthCheck,
      lastError: state.lastError,
      enabledAgents,
      totalAgents,
    };
  });
}

/**
 * Save/update a client config.
 */
export function saveClient(clientConfig) {
  const filePath = path.join(CLIENTS_DIR, `${clientConfig.id}.json`);
  fs.writeFileSync(filePath, JSON.stringify(clientConfig, null, 2));
  return filePath;
}

/**
 * Delete a client config.
 */
export function deleteClient(clientId) {
  const filePath = path.join(CLIENTS_DIR, `${clientId}.json`);
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
    clientStates.delete(clientId);
    return true;
  }
  return false;
}
