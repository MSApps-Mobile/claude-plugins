---
name: prospect
description: "Full ICP-to-leads pipeline for MSApps. Describe your ideal customer in plain English — or pick from MSApps' proven segments — and get a ranked table of enriched decision-maker leads with emails and phone numbers."
user-invocable: true
argument-hint: "[describe your ideal customer or pick a segment]"
---

# Prospect

Go from an ICP description to a ranked, enriched lead list in one shot. The user describes their ideal customer via "$ARGUMENTS".

## About MSApps (Context for Relevance Scoring)

MSApps is a boutique Israeli full-stack & mobile development company founded in 2010 by Michal Shatz. ~40 developers, designers, PMs — 100% Israeli team (no offshore). Core services: mobile apps (iOS/Android/React Native/Flutter), complex web applications, IoT & smart systems, AI integration, outsourcing & team augmentation, and consulting.

**Key clients:** Phoenix (insurance), Union Motors (Toyota/Lexus/Geely/Zeekr apps), Assuta Hospital (IVF app), Fox Group (Dream Card loyalty), Cynet (cybersecurity), Riskified, Theranica (MedTech), Isracard, Wolf Guard (security), AppCharge, AiOmed, Viventium (HR/Payroll).

**Key differentiators:** 100% Israeli team, 15+ years experience, end-to-end service (ideation → maintenance), senior+junior model for quality at competitive cost, "we don't disappear after launch", AI integration capabilities.

## MSApps Proven Target Segments

When the user doesn't specify a detailed ICP, suggest these segments that MSApps actively targets:

1. **Startups (Series A-C)** — CEOs, CTOs, VP Engineering needing dev team augmentation or MVP builds
2. **Enterprises** — CTOs, VP IT, Heads of Digital at large companies needing mobile/web solutions or outsourcing
3. **Automotive / Mobility** — CTOs, Innovation leads at car importers, leasing companies, fleet management
4. **FinTech / InsurTech** — CEOs, CTOs at payments, lending, insurance tech companies (50-500 employees)
5. **Digital Health / MedTech** — CEOs, CTOs at health tech startups needing patient apps, medical device connectivity, compliance
6. **Retail / E-commerce** — CTOs, Heads of Digital at retail chains, loyalty programs, e-commerce platforms
7. **Cybersecurity** — CEOs, CTOs at growing cyber companies needing to augment dev teams quickly
8. **PropTech / ConsTech** — CEOs, CTOs at real estate tech, construction tech companies
9. **EdTech / LearningTech** — CEOs, CTOs at educational technology companies
10. **AgriTech / FoodTech** — CEOs, CTOs at agriculture and food technology companies
11. **LogisticsTech / Supply Chain** — CEOs, CTOs at logistics, maritime, supply chain tech companies
12. **MarTech / AdTech** — CEOs, CTOs at marketing technology and advertising platforms
13. **HRTech / WorkTech** — CEOs, CTOs at HR platforms, payroll, workforce management
14. **CleanTech / EnergyTech** — CEOs, CTOs at climate tech, energy, sustainability companies
15. **GamingTech / SportsTech** — CEOs, CTOs at gaming studios, sports technology companies

## Default Geographic Markets

MSApps targets clients globally, with focus on three regions:
- **United States** — Primary international market
- **Europe** — UK, Germany, Netherlands, France, Nordics, and broader EU
- **Israel** — Home market

When the user doesn't specify a location, search across **all three regions**. The user can narrow to a specific region or country at any time.

## Examples

- `/apollo:prospect CTOs at FinTech startups in the US, Series A+, 50-500 employees`
- `/apollo:prospect VP Engineering at cybersecurity companies in Europe, 100-1000 employees`
- `/apollo:prospect CEOs at MedTech startups` (searches US, Europe & Israel by default)
- `/apollo:prospect Heads of Digital at retail chains in the UK and Germany`
- `/apollo:prospect CTOs at PropTech companies in Israel, 30-300 employees`
- `/apollo:prospect segment: automotive, US only`
- `/apollo:prospect segment: fintech` (searches all default regions)

## Step 1 — Parse the ICP

Extract structured filters from the natural language description in "$ARGUMENTS":

**Company filters:**
- Industry/vertical keywords → `q_organization_keyword_tags`
- Employee count ranges → `organization_num_employees_ranges`
- Company locations → `organization_locations` (default: **United States, Europe, Israel** — narrow if user specifies a region)
- Specific domains → `q_organization_domains_list`

**Person filters:**
- Job titles → `person_titles` (default targets: **CEO, CTO, VP Engineering, VP R&D, VP IT, Head of Digital, CIO**)
- Seniority levels → `person_seniorities` (default: **c_suite, vp, director**)
- Person locations → `person_locations`

If the user names a segment (e.g., "segment: fintech" or just "fintech"), map it to the corresponding filters from the MSApps Proven Target Segments above.

If the ICP is vague, ask 1-2 clarifying questions before proceeding. At minimum, you need a title/role and an industry or company size.

## Step 2 — Search for Companies

Use `mcp__claude_ai_Apollo_MCP__apollo_mixed_companies_search` with the company filters:
- `q_organization_keyword_tags` for industry/vertical
- `organization_num_employees_ranges` for size
- `organization_locations` for geography
- Set `per_page` to 25

## Step 3 — Enrich Top Companies

Use `mcp__claude_ai_Apollo_MCP__apollo_organizations_bulk_enrich` with the domains from the top 10 results. This reveals revenue, funding, headcount, and firmographic data to help rank companies.

## Step 4 — Find Decision Makers

Use `mcp__claude_ai_Apollo_MCP__apollo_mixed_people_api_search` with:
- `person_titles` and `person_seniorities` from the ICP
- `q_organization_domains_list` scoped to the enriched company domains
- `per_page` set to 25

## Step 5 — Enrich Top Leads

> **Credit warning**: Tell the user exactly how many credits will be consumed before proceeding.

Use `mcp__claude_ai_Apollo_MCP__apollo_people_bulk_match` to enrich up to 10 leads per call with:
- `first_name`, `last_name`, `domain` for each person
- `reveal_personal_emails` set to `true`

If more than 10 leads, batch into multiple calls.

## Step 6 — Present the Lead Table

Show results in a ranked table:

### Leads matching: [ICP Summary]

| # | Name | Title | Company | Employees | Revenue | Email | Phone | MSApps Fit |
|---|---|---|---|---|---|---|---|---|

**MSApps Fit** scoring (considers relevance to MSApps services):
- **Strong** — Company likely needs mobile/web dev, outsourcing, or team augmentation AND title is a decision maker. Bonus if in a vertical where MSApps has proven clients (automotive, health, finance, retail, cyber).
- **Good** — 3 of 4 criteria match (title, seniority, company size, industry relevance)
- **Partial** — 2 of 4 criteria match

**Summary**: Found X leads across Y companies. Z credits consumed.

## Step 7 — Offer Next Actions

Ask the user:

1. **Save all to Apollo** — Bulk-create contacts via `mcp__claude_ai_Apollo_MCP__apollo_contacts_create` with `run_dedupe: true` for each lead
2. **Load into a sequence** — Ask which sequence and run the sequence-load flow for these contacts
3. **Send via LinkedIn** — Suggest using the linkedin-outreach skill to message these leads directly on LinkedIn (MSApps' primary outreach channel)
4. **Deep-dive a company** — Run `/apollo:enrich-lead` on any person from the list for full details
5. **Try another segment** — Pick a different MSApps target segment to prospect
6. **Export** — Format leads as a CSV-style table for easy copy-paste
