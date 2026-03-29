/**
 * Google Calendar data fetcher for OpsAgent.
 * Fetches lead/event data and returns it as structured text
 * that can be injected into agent prompts.
 */

import { google } from 'googleapis';

/**
 * Create an authenticated Google Calendar client.
 * Uses GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN from env.
 */
function createCalendarClient() {
  const { GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN } = process.env;

  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET || !GOOGLE_REFRESH_TOKEN) {
    return null;
  }

  const oauth2Client = new google.auth.OAuth2(GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET);
  oauth2Client.setCredentials({ refresh_token: GOOGLE_REFRESH_TOKEN });

  return google.calendar({ version: 'v3', auth: oauth2Client });
}

/**
 * Fetch events from Google Calendar for a given time range.
 * Returns formatted markdown text with event details.
 */
export async function fetchCalendarEvents({ calendarId = 'primary', daysBack = 30, daysForward = 14, query = null, timezone = 'Asia/Jerusalem' } = {}) {
  const calendar = createCalendarClient();
  if (!calendar) {
    return null; // No credentials configured
  }

  const now = new Date();
  const timeMin = new Date(now);
  timeMin.setDate(timeMin.getDate() - daysBack);
  const timeMax = new Date(now);
  timeMax.setDate(timeMax.getDate() + daysForward);

  const params = {
    calendarId,
    timeMin: timeMin.toISOString(),
    timeMax: timeMax.toISOString(),
    singleEvents: true,
    orderBy: 'startTime',
    maxResults: 250,
    timeZone: timezone,
  };

  if (query) {
    params.q = query;
  }

  const allEvents = [];
  let pageToken = null;

  do {
    if (pageToken) params.pageToken = pageToken;
    const response = await calendar.events.list(params);
    const events = response.data.items || [];
    allEvents.push(...events);
    pageToken = response.data.nextPageToken;
  } while (pageToken);

  return allEvents;
}

/**
 * Format calendar events as markdown for agent consumption.
 */
export function formatEventsAsMarkdown(events) {
  if (!events || events.length === 0) {
    return '_No events found._';
  }

  const lines = events.map(event => {
    const start = event.start?.dateTime || event.start?.date || 'unknown';
    const date = new Date(start).toLocaleDateString('en-US', {
      weekday: 'short', month: 'short', day: 'numeric',
    });
    const time = event.start?.dateTime
      ? new Date(start).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false })
      : 'all-day';
    const summary = event.summary || '(no title)';
    const description = (event.description || '').replace(/\n/g, ' ').substring(0, 200);
    const attendees = (event.attendees || []).map(a => a.email).join(', ');

    let line = `- **${summary}** — ${date} ${time}`;
    if (description) line += `\n  Description: ${description}`;
    if (attendees) line += `\n  Attendees: ${attendees}`;
    return line;
  });

  return lines.join('\n');
}

/**
 * Fetch and format calendar data for injection into an agent prompt.
 * Returns null if Google Calendar is not configured.
 */
export async function getCalendarContext({ calendarId = 'primary', daysBack = 30, daysForward = 14, timezone = 'Asia/Jerusalem' } = {}) {
  try {
    const events = await fetchCalendarEvents({ calendarId, daysBack, daysForward, timezone });
    if (events === null) return null;

    return `## Live Calendar Data (${events.length} events)\n\n${formatEventsAsMarkdown(events)}`;
  } catch (err) {
    return `## Calendar Error\n\nFailed to fetch calendar data: ${err.message}`;
  }
}
