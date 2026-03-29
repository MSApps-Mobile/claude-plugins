# OpsAgent — AI Operations Platform

## Objective
Run autonomous AI agents for SMB operations: lead management, outreach, invoicing, recruiting, social media, and receipts collection.

**Impact Level:** High (sends emails, messages, modifies CRM data)

## Triggers
Use this agent when running any OpsAgent workflow: lead pipeline, LinkedIn outreach, receipts collection, invoicing, recruiting, or social media posting.

## Plan Phase

### Step 1: Load Client Configuration
- Read client config from `clients/<client>.json`
- Load agent definitions from `agents/<agent>.md`
- Initialize MCP server connections

### Step 2: Select Agent & Build Plan
- Match requested task to agent definition
- Validate required MCP servers are available
- Build execution plan with preconditions

## Act Phase

### Step 3: Execute Agent Workflow
- Run agent through Claude Code with structured prompts
- Each agent follows its own Plan-Act-Verify loop
- **Human approval required** for: bulk emails, financial operations, public posts
- Log all actions with timestamps and token usage

### Step 4: Handle Outputs
- Parse structured output from agent execution
- Store logs in `logs/<client>/<agent>/<date>.md`
- Update dashboards and notification channels

## Verify Phase

### Step 5: Validate & Report
- Compare results against success criteria from agent definition
- Generate completion summary with metrics (actions taken, tokens used)
- Escalate failures or anomalies to human operator
- Feed results into trust gradient for autonomy adjustment

## Tool Manifest
- Google Calendar MCP (CRM / lead events)
- Zoho Mail MCP (email operations)
- WhatsApp MCP (messaging)
- Apollo MCP (lead enrichment)
- Notion MCP (knowledge base)
- LinkedIn Scraper MCP (profile data)
- Apify MCP (web scraping)

## Security
- Credentials stored in `mcp-servers.json` (gitignored, never committed)
- Environment variables for sensitive config (`GOOGLE_REFRESH_TOKEN`, etc.)
- Each agent runs with scoped tool access — only the MCPs it needs
- All actions logged with immutable audit trail

## Boundaries
- Never execute financial transactions without human approval
- Never send bulk messages (>5) without confirmation
- Never modify client data outside the designated client scope
- Escalate errors and anomalies — don't retry silently
