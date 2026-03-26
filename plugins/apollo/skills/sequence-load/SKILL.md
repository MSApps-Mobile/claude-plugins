---
name: sequence-load
description: "Find leads matching criteria and bulk-add them to an Apollo outreach sequence. Handles enrichment, contact creation, deduplication, and enrollment in one flow. Pre-configured with MSApps target segments."
user-invocable: true
argument-hint: "[targeting criteria or MSApps segment + sequence name]"
---

# Sequence Load

Find, enrich, and load contacts into an outreach sequence — end to end. The user provides targeting criteria and a sequence name via "$ARGUMENTS".

## About MSApps (Context)

MSApps targets tech companies and enterprises globally for mobile/web development, outsourcing, and team augmentation. Default location filter is **United States, Europe, and Israel**. Default seniority targets are **CEO, CTO, VP Engineering, VP R&D, VP IT, Head of Digital**.

See the Prospect skill for the full list of 15 MSApps target segments (automotive, fintech, healthtech, cyber, retail, proptech, edtech, agritech, logistics, martech, hrtech, cleantech, gaming, startups, enterprises).

## Examples

- `/apollo:sequence-load add 20 CTOs at US cybersecurity companies to "Cyber Outreach Q1"`
- `/apollo:sequence-load segment: fintech, Europe → Cold Outreach`
- `/apollo:sequence-load list sequences` (shows all available sequences)
- `/apollo:sequence-load CEOs at MedTech startups, 30-300 employees → Health Outreach` (searches US, Europe & Israel)
- `/apollo:sequence-load reload 15 more leads into "Enterprise Pipeline"`

## Step 1 — Parse Input

From "$ARGUMENTS", extract:

**Targeting criteria:**
- Job titles → `person_titles` (default: **CEO, CTO, VP Engineering, VP R&D, VP IT, Head of Digital, CIO**)
- Seniority levels → `person_seniorities` (default: **c_suite, vp, director**)
- Industry keywords → `q_organization_keyword_tags`
- Company size → `organization_num_employees_ranges`
- Locations → `person_locations` or `organization_locations` (default: **United States, Europe, Israel** — narrow if user specifies)

**Sequence info:**
- Sequence name (text after "to", "into", or "→")
- Volume — how many contacts to add (default: 10 if not specified)

If the user names an MSApps segment (e.g., "segment: fintech"), map it to the appropriate filters.

If the user just says "list sequences", skip to Step 2 and show all available sequences.

## Step 2 — Find the Sequence

Use `mcp__claude_ai_Apollo_MCP__apollo_emailer_campaigns_search` to find the target sequence:
- Set `q_name` to the sequence name from input

If no match or multiple matches:
- Show all available sequences in a table: | Name | ID | Status |
- Ask the user to pick one

## Step 3 — Get Email Account

Use `mcp__claude_ai_Apollo_MCP__apollo_email_accounts_index` to list linked email accounts.

- If one account → use automatically
- If multiple → show them and ask which to send from (MSApps primary: michal@msapps.mobi)

## Step 4 — Find Matching People

Use `mcp__claude_ai_Apollo_MCP__apollo_mixed_people_api_search` with the targeting criteria.
- Set `per_page` to the requested volume (or 10 by default)

Present the candidates in a preview table:

| # | Name | Title | Company | Location | MSApps Fit |
|---|---|---|---|---|---|

**MSApps Fit** — Quick relevance check: does this person's company operate in a vertical where MSApps has clients or expertise? Is the title a decision-maker for dev partnerships?

Ask: **"Add these [N] contacts to [Sequence Name]? This will consume [N] Apollo credits for enrichment."**

Wait for confirmation before proceeding.

## Step 5 — Enrich and Create Contacts

For each approved lead:

1. **Enrich** — Use `mcp__claude_ai_Apollo_MCP__apollo_people_bulk_match` (batch up to 10 per call) with:
   - `first_name`, `last_name`, `domain` for each person
   - `reveal_personal_emails` set to `true`

2. **Create contacts** — For each enriched person, use `mcp__claude_ai_Apollo_MCP__apollo_contacts_create` with:
   - `first_name`, `last_name`, `email`, `title`, `organization_name`
   - `direct_phone` or `mobile_phone` if available
   - `run_dedupe` set to `true`

Collect all created contact IDs.

## Step 6 — Add to Sequence

Use `mcp__claude_ai_Apollo_MCP__apollo_emailer_campaigns_add_contact_ids` with:
- `id`: the sequence ID
- `emailer_campaign_id`: same sequence ID
- `contact_ids`: array of created contact IDs
- `send_email_from_email_account_id`: the chosen email account ID
- `sequence_active_in_other_campaigns`: `false` (safe default)

## Step 7 — Confirm Enrollment

Show a summary:

---

**Sequence loaded successfully**

| Field | Value |
|---|---|
| Sequence | [Name] |
| Contacts added | [count] |
| Sending from | [email address] |
| Credits used | [count] |
| Segment | [MSApps segment if applicable] |

**Contacts enrolled:**

| Name | Title | Company | Email | MSApps Fit |
|---|---|---|---|---|

---

## Step 8 — Offer Next Actions

Ask the user:

1. **Load more** — Find and add another batch of leads (same or different segment)
2. **Review sequence** — Show sequence details and all enrolled contacts
3. **Also reach out on LinkedIn** — Suggest using the linkedin-outreach skill for a multi-channel approach (MSApps' primary outreach method)
4. **Remove a contact** — Use `mcp__claude_ai_Apollo_MCP__apollo_emailer_campaigns_remove_or_stop_contact_ids` to remove specific contacts
5. **Pause a contact** — Re-add with `status: "paused"` and an `auto_unpause_at` date
6. **Try another segment** — Load leads from a different MSApps target vertical
