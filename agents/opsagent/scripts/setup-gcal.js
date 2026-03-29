#!/usr/bin/env node
/**
 * Google Calendar OAuth Setup
 *
 * Prerequisites:
 * 1. Go to https://console.cloud.google.com/
 * 2. Create a project (or use an existing one)
 * 3. Enable "Google Calendar API" (APIs & Services > Library)
 * 4. Create OAuth 2.0 credentials (APIs & Services > Credentials > Create > OAuth client ID)
 *    - Application type: "Desktop app"
 *    - Download the JSON or copy Client ID + Client Secret
 * 5. Configure OAuth consent screen (if not done):
 *    - User type: External (or Internal if using Workspace)
 *    - Add scope: https://www.googleapis.com/auth/calendar.readonly
 *    - Add your email as a test user
 *
 * Usage:
 *   node scripts/setup-gcal.js <CLIENT_ID> <CLIENT_SECRET>
 *
 * This will open a browser for Google sign-in, then save the refresh token to .env
 */

import { google } from 'googleapis';
import http from 'http';
import { URL } from 'url';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ENV_FILE = path.join(__dirname, '..', '.env');
const SCOPES = ['https://www.googleapis.com/auth/calendar.readonly'];
const REDIRECT_PORT = 3847;
const REDIRECT_URI = `http://localhost:${REDIRECT_PORT}/callback`;

const [,, clientId, clientSecret] = process.argv;

if (!clientId || !clientSecret) {
  console.log(`
📅 Google Calendar OAuth Setup for OpsAgent
============================================

Usage: node scripts/setup-gcal.js <CLIENT_ID> <CLIENT_SECRET>

Steps to get these:
  1. Go to https://console.cloud.google.com/apis/credentials
  2. Click "Create Credentials" > "OAuth client ID"
  3. Application type: "Desktop app"
  4. Copy the Client ID and Client Secret

  (Make sure you've enabled the Google Calendar API first:
   https://console.cloud.google.com/apis/library/calendar-json.googleapis.com)
`);
  process.exit(0);
}

const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, REDIRECT_URI);

const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  scope: SCOPES,
  prompt: 'consent',
});

console.log('\n🔐 Opening browser for Google sign-in...\n');

// Start a local server to catch the OAuth callback
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${REDIRECT_PORT}`);

  if (url.pathname !== '/callback') {
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  const code = url.searchParams.get('code');
  const error = url.searchParams.get('error');

  if (error) {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end('<h1>❌ Authorization denied</h1><p>You can close this tab.</p>');
    console.error('❌ Authorization denied:', error);
    server.close();
    process.exit(1);
  }

  if (!code) {
    res.writeHead(400, { 'Content-Type': 'text/html' });
    res.end('<h1>❌ No authorization code received</h1>');
    return;
  }

  try {
    const { tokens } = await oauth2Client.getToken(code);
    const refreshToken = tokens.refresh_token;

    if (!refreshToken) {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end('<h1>❌ No refresh token received</h1><p>Try revoking access at https://myaccount.google.com/permissions and running again.</p>');
      console.error('❌ No refresh token. Revoke access and try again.');
      server.close();
      process.exit(1);
    }

    // Save to .env
    let envContent = '';
    if (fs.existsSync(ENV_FILE)) {
      envContent = fs.readFileSync(ENV_FILE, 'utf-8');
    }

    // Remove existing Google Calendar entries
    envContent = envContent
      .split('\n')
      .filter(line => !line.startsWith('GOOGLE_CLIENT_ID=') &&
                      !line.startsWith('GOOGLE_CLIENT_SECRET=') &&
                      !line.startsWith('GOOGLE_REFRESH_TOKEN='))
      .join('\n')
      .trimEnd();

    envContent += `\nGOOGLE_CLIENT_ID=${clientId}\nGOOGLE_CLIENT_SECRET=${clientSecret}\nGOOGLE_REFRESH_TOKEN=${refreshToken}\n`;

    fs.writeFileSync(ENV_FILE, envContent);

    // Quick test: list calendars
    oauth2Client.setCredentials(tokens);
    const calendar = google.calendar({ version: 'v3', auth: oauth2Client });
    const calList = await calendar.calendarList.list();
    const calNames = calList.data.items.map(c => c.summary).join(', ');

    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(`<h1>✅ Connected!</h1><p>Calendars found: ${calNames}</p><p>You can close this tab.</p>`);

    console.log('✅ Google Calendar connected!');
    console.log(`   Calendars: ${calNames}`);
    console.log(`   Credentials saved to .env`);
    console.log('\n   You can now run: node src/cli.js msapps lead-pipeline\n');

  } catch (err) {
    res.writeHead(500, { 'Content-Type': 'text/html' });
    res.end(`<h1>❌ Error</h1><pre>${err.message}</pre>`);
    console.error('❌ Token exchange failed:', err.message);
  }

  server.close();
});

server.listen(REDIRECT_PORT, () => {
  // Open browser
  exec(`open "${authUrl}"`);
  console.log(`   If browser doesn't open, visit:\n   ${authUrl}\n`);
  console.log('   Waiting for authorization...\n');
});
