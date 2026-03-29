/**
 * Tunnel Proxy — forwards API requests from the central dashboard
 * to the correct client's virtual Mac via their Cloudflare Tunnel URL.
 *
 * For the POC, this acts as a transparent proxy:
 *   Dashboard → /api/proxy/:clientId/... → tunnel_url/api/...
 */

import { getClient, getClientState } from './client-registry.js';

/**
 * Proxy a request to a client's VM.
 * @param {string} clientId - Client ID
 * @param {string} apiPath - API path after /api/ (e.g., "status", "logs/social-posts")
 * @param {object} options - { method, body, headers }
 * @returns {{ status, data, error }}
 */
export async function proxyToClient(clientId, apiPath, options = {}) {
  const client = getClient(clientId);
  if (!client) {
    return { status: 404, data: null, error: 'Client not found' };
  }
  if (!client.tunnel_url) {
    return { status: 503, data: null, error: 'No tunnel_url configured for this client' };
  }

  const state = getClientState(clientId);
  const url = `${client.tunnel_url}/api/${apiPath}`;
  const method = options.method || 'GET';

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000); // 30s timeout

    const fetchOptions = {
      method,
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        'X-OpsAgent-Client': clientId,
        ...(options.headers || {}),
      },
    };

    if (options.body && method !== 'GET') {
      fetchOptions.body = typeof options.body === 'string'
        ? options.body
        : JSON.stringify(options.body);
    }

    const res = await fetch(url, fetchOptions);
    clearTimeout(timeout);

    const contentType = res.headers.get('content-type') || '';
    let data;
    if (contentType.includes('application/json')) {
      data = await res.json();
    } else {
      data = await res.text();
    }

    return { status: res.status, data, error: null };
  } catch (err) {
    return {
      status: 502,
      data: null,
      error: `Tunnel proxy error: ${err.message}`,
    };
  }
}

/**
 * Create an SSE proxy — forwards SSE events from a client's VM to the dashboard.
 * Used for streaming agent runs.
 * @param {string} clientId
 * @param {string} apiPath
 * @param {import('express').Response} clientRes - Express response to stream to
 */
export async function proxySSEToClient(clientId, apiPath, clientRes) {
  const client = getClient(clientId);
  if (!client?.tunnel_url) {
    clientRes.status(503).json({ error: 'Client VM not reachable' });
    return;
  }

  const url = `${client.tunnel_url}/api/${apiPath}`;

  try {
    const controller = new AbortController();
    const res = await fetch(url, {
      signal: controller.signal,
      headers: { 'Accept': 'text/event-stream' },
    });

    if (!res.ok) {
      clientRes.status(res.status).json({ error: `VM returned ${res.status}` });
      return;
    }

    // Set SSE headers on client response
    clientRes.setHeader('Content-Type', 'text/event-stream');
    clientRes.setHeader('Cache-Control', 'no-cache');
    clientRes.setHeader('Connection', 'keep-alive');

    // Pipe the SSE stream
    const reader = res.body.getReader();
    const decoder = new TextDecoder();

    const pump = async () => {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        const chunk = decoder.decode(value, { stream: true });
        clientRes.write(chunk);
      }
      clientRes.end();
    };

    // Clean up on client disconnect
    clientRes.on('close', () => {
      controller.abort();
    });

    await pump();
  } catch (err) {
    if (!clientRes.headersSent) {
      clientRes.status(502).json({ error: `SSE proxy error: ${err.message}` });
    } else {
      clientRes.end();
    }
  }
}
