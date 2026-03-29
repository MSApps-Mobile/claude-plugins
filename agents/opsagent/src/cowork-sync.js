#!/usr/bin/env node
/**
 * Cowork Sync — watches ~/.claude/scheduled-tasks/ for changes
 * and syncs the current state to a remote endpoint.
 *
 * Like Google Drive sync but for Cowork task data.
 * Runs as a background daemon on the Mac.
 *
 * Usage:
 *   node src/cowork-sync.js                    # sync to local API
 *   SYNC_URL=https://... node src/cowork-sync.js  # sync to remote
 */

import fs from 'fs';
import path from 'path';
import os from 'os';
import { listCoworkTasks, getCoworkTask } from './cowork-bridge.js';

const TASKS_DIR = path.join(os.homedir(), '.claude', 'scheduled-tasks');
const SYNC_URL = process.env.SYNC_URL || 'http://localhost:4242/api/cowork/sync';
const SYNC_INTERVAL = parseInt(process.env.SYNC_INTERVAL || '30000', 10); // 30s default
const STATE_FILE = path.join(os.homedir(), '.claude', 'cowork-sync-state.json');

let debounceTimer = null;
let lastSyncHash = '';

/**
 * Build a full snapshot of all tasks + their latest output metadata.
 */
function buildSnapshot() {
  const tasks = listCoworkTasks();
  const snapshot = {
    timestamp: new Date().toISOString(),
    hostname: os.hostname(),
    tasksDir: TASKS_DIR,
    taskCount: tasks.length,
    tasks: tasks.map(t => {
      const full = getCoworkTask(t.taskId);
      return {
        ...t,
        prompt: full?.prompt || '',
        recentRuns: full?.recentRuns || [],
      };
    }),
  };
  return snapshot;
}

/**
 * Simple hash to detect changes.
 */
function hashSnapshot(snapshot) {
  const data = JSON.stringify({
    tasks: snapshot.tasks.map(t => ({
      id: t.taskId,
      enabled: t.enabled,
      schedule: t.schedule,
      lastRun: t.lastRun?.timestamp,
      runCount: t.recentRuns?.length,
    })),
  });
  let hash = 0;
  for (let i = 0; i < data.length; i++) {
    hash = ((hash << 5) - hash + data.charCodeAt(i)) | 0;
  }
  return hash.toString(36);
}

/**
 * Save snapshot locally (always works, even if remote is down).
 */
function saveLocal(snapshot) {
  try {
    fs.writeFileSync(STATE_FILE, JSON.stringify(snapshot, null, 2));
  } catch (e) {
    console.warn('[sync] Failed to save local state:', e.message);
  }
}

/**
 * Push snapshot to remote endpoint.
 */
async function pushRemote(snapshot) {
  try {
    const res = await fetch(SYNC_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(snapshot),
    });
    if (!res.ok) {
      console.warn(`[sync] Remote sync failed: ${res.status} ${res.statusText}`);
      return false;
    }
    console.log(`[sync] Pushed ${snapshot.taskCount} tasks to remote`);
    return true;
  } catch (e) {
    console.warn(`[sync] Remote unreachable: ${e.message}`);
    return false;
  }
}

/**
 * Run a sync cycle — build snapshot, compare, push if changed.
 */
async function sync() {
  const snapshot = buildSnapshot();
  const hash = hashSnapshot(snapshot);

  if (hash === lastSyncHash) return; // no changes
  lastSyncHash = hash;

  console.log(`[sync] Change detected — ${snapshot.taskCount} tasks`);
  saveLocal(snapshot);
  await pushRemote(snapshot);
}

/**
 * Debounced sync — waits for filesystem to settle before syncing.
 */
function debouncedSync() {
  if (debounceTimer) clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => sync(), 2000);
}

/**
 * Watch the tasks directory for changes.
 */
function startWatcher() {
  if (!fs.existsSync(TASKS_DIR)) {
    console.error(`[sync] Tasks directory not found: ${TASKS_DIR}`);
    process.exit(1);
  }

  console.log(`[sync] Watching ${TASKS_DIR}`);
  console.log(`[sync] Syncing to ${SYNC_URL}`);
  console.log(`[sync] Interval: ${SYNC_INTERVAL / 1000}s\n`);

  // Initial sync
  sync();

  // Watch for file changes (recursive)
  fs.watch(TASKS_DIR, { recursive: true }, (event, filename) => {
    if (filename && (filename.endsWith('.md') || filename.endsWith('.json'))) {
      console.log(`[sync] File changed: ${filename}`);
      debouncedSync();
    }
  });

  // Periodic sync as fallback (catches changes the watcher might miss)
  setInterval(() => sync(), SYNC_INTERVAL);
}

// ── Main ────────────────────────────────────────────────────────────────────

startWatcher();
