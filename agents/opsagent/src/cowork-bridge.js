/**
 * Cowork Bridge — reads and controls Cowork scheduled tasks from disk.
 *
 * Cowork stores tasks as skill files in ~/.claude/scheduled-tasks/{taskId}/SKILL.md
 * Task metadata is in the SKILL.md frontmatter (YAML between --- markers).
 * Task run logs are in ~/.claude/scheduled-tasks/{taskId}/sessions/
 */

import fs from 'fs';
import path from 'path';
import os from 'os';

const TASKS_DIR = path.join(os.homedir(), '.claude', 'scheduled-tasks');

/**
 * List all Cowork scheduled tasks with their metadata.
 */
export function listCoworkTasks() {
  if (!fs.existsSync(TASKS_DIR)) return [];

  const taskDirs = fs.readdirSync(TASKS_DIR, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  return taskDirs.map(taskId => {
    const skillPath = path.join(TASKS_DIR, taskId, 'SKILL.md');
    if (!fs.existsSync(skillPath)) return null;

    const content = fs.readFileSync(skillPath, 'utf-8');
    const meta = parseSkillFrontmatter(content);
    const prompt = extractPromptBody(content);
    const lastRun = getLastRunInfo(taskId);

    return {
      taskId,
      description: meta.description || taskId,
      schedule: meta.cron_expression || meta.fire_at || 'manual',
      cronExpression: meta.cron_expression || null,
      fireAt: meta.fire_at || null,
      enabled: meta.enabled !== 'false' && meta.enabled !== false,
      lastRun,
      prompt: prompt.substring(0, 500), // preview only
    };
  }).filter(Boolean);
}

/**
 * Get full details for a single task including full prompt.
 */
export function getCoworkTask(taskId) {
  const skillPath = path.join(TASKS_DIR, taskId, 'SKILL.md');
  if (!fs.existsSync(skillPath)) return null;

  const content = fs.readFileSync(skillPath, 'utf-8');
  const meta = parseSkillFrontmatter(content);
  const prompt = extractPromptBody(content);
  const lastRun = getLastRunInfo(taskId);
  const recentRuns = getRecentRuns(taskId, 10);

  return {
    taskId,
    description: meta.description || taskId,
    schedule: meta.cron_expression || meta.fire_at || 'manual',
    cronExpression: meta.cron_expression || null,
    fireAt: meta.fire_at || null,
    enabled: meta.enabled !== 'false' && meta.enabled !== false,
    lastRun,
    recentRuns,
    prompt,
    raw: content,
  };
}

/**
 * Get the output/log from a specific task run.
 */
export function getCoworkTaskOutput(taskId, sessionId) {
  const sessionsDir = path.join(TASKS_DIR, taskId, 'sessions');
  if (!fs.existsSync(sessionsDir)) return null;

  // If no sessionId, get the latest
  if (!sessionId) {
    const sessions = listSessionDirs(taskId);
    if (!sessions.length) return null;
    sessionId = sessions[0].name;
  }

  const sessionDir = path.join(sessionsDir, sessionId);
  if (!fs.existsSync(sessionDir)) return null;

  // Read conversation log if it exists
  const logFiles = fs.readdirSync(sessionDir)
    .filter(f => f.endsWith('.md') || f.endsWith('.json') || f.endsWith('.log'));

  const output = {};
  for (const file of logFiles) {
    const filePath = path.join(sessionDir, file);
    output[file] = fs.readFileSync(filePath, 'utf-8');
  }

  return { sessionId, files: output };
}

/**
 * Update a task's SKILL.md — only the frontmatter fields.
 * Does NOT update the prompt body (that requires the Cowork MCP).
 */
export function updateCoworkTaskMeta(taskId, updates) {
  const skillPath = path.join(TASKS_DIR, taskId, 'SKILL.md');
  if (!fs.existsSync(skillPath)) return null;

  const content = fs.readFileSync(skillPath, 'utf-8');
  const meta = parseSkillFrontmatter(content);
  const body = extractPromptBody(content);

  // Apply updates
  if (updates.enabled !== undefined) meta.enabled = updates.enabled;
  if (updates.cronExpression !== undefined) meta.cron_expression = updates.cronExpression;
  if (updates.description !== undefined) meta.description = updates.description;

  // Rebuild the file
  const newContent = buildSkillFile(meta, body);
  fs.writeFileSync(skillPath, newContent);

  return getCoworkTask(taskId);
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function parseSkillFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return {};

  const meta = {};
  for (const line of match[1].split('\n')) {
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;
    const key = line.substring(0, colonIdx).trim();
    let value = line.substring(colonIdx + 1).trim();
    // Remove quotes
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    meta[key] = value;
  }
  return meta;
}

function extractPromptBody(content) {
  const match = content.match(/^---\n[\s\S]*?\n---\n*([\s\S]*)$/);
  return match ? match[1].trim() : content;
}

function buildSkillFile(meta, body) {
  const lines = Object.entries(meta)
    .map(([k, v]) => `${k}: ${typeof v === 'string' && v.includes(' ') ? `"${v}"` : v}`);
  return `---\n${lines.join('\n')}\n---\n\n${body}\n`;
}

function listSessionDirs(taskId) {
  const sessionsDir = path.join(TASKS_DIR, taskId, 'sessions');
  if (!fs.existsSync(sessionsDir)) return [];

  return fs.readdirSync(sessionsDir, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => ({
      name: d.name,
      mtime: fs.statSync(path.join(sessionsDir, d.name)).mtime,
    }))
    .sort((a, b) => b.mtime - a.mtime);
}

function getLastRunInfo(taskId) {
  const sessions = listSessionDirs(taskId);
  if (!sessions.length) return null;

  const latest = sessions[0];
  return {
    sessionId: latest.name,
    timestamp: latest.mtime.toISOString(),
    date: latest.mtime.toISOString().split('T')[0],
  };
}

function getRecentRuns(taskId, limit = 10) {
  const sessions = listSessionDirs(taskId);
  return sessions.slice(0, limit).map(s => ({
    sessionId: s.name,
    timestamp: s.mtime.toISOString(),
    date: s.mtime.toISOString().split('T')[0],
  }));
}
