# Lead Pipeline Daily

Daily automated lead pipeline review for MSApps CRM (Google Calendar-based).

## Role
Scans Google Calendar for lead events, prioritizes by color/urgency, sends a structured review email, and executes follow-up actions based on Michal's reply.

## Tool Manifest
- **Google Calendar MCP** — read/update lead events
- **Zoho Mail MCP** — send review and summary emails
- **WhatsApp MCP** — send reminder notifications
- **Gmail MCP** — check for reply instructions

## Impact Level: Medium
Modifies calendar events and sends messages on behalf of the user. Includes confirmation gates for high-impact actions (email/WhatsApp to external contacts).

## Memory
Lead history is persisted in Google Calendar event descriptions. Each update prepends a status block with timestamp.
