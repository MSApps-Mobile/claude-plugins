---
name: enrich-lead
description: "Instant lead enrichment for MSApps sales. Drop a name, company, LinkedIn URL, or email and get the full contact card with email, phone, title, company intel, MSApps relevance assessment, and next actions."
user-invocable: true
argument-hint: "[name, company, LinkedIn URL, or email]"
---

# Enrich Lead

Turn any identifier into a full contact dossier with MSApps relevance scoring. The user provides identifying info via "$ARGUMENTS".

## About MSApps (Context for Relevance Assessment)

MSApps is a boutique Israeli full-stack & mobile development company (est. 2010, ~40 team, 100% Israeli). Services: mobile apps, web apps, IoT, AI integration, outsourcing & team augmentation. Key verticals: automotive, fintech, healthtech, retail, cybersecurity, proptech, enterprise.

**Notable clients:** Phoenix, Union Motors (Toyota/Lexus/Geely/Zeekr), Assuta, Fox Group (Dream Card), Cynet, Riskified, Theranica, Isracard, Wolf Guard, AppCharge, AiOmed, Viventium.

## Examples

- `/apollo:enrich-lead Orr Danon at Hailo`
- `/apollo:enrich-lead https://www.linkedin.com/in/someone`
- `/apollo:enrich-lead CEO of Wiz`
- `/apollo:enrich-lead Ronni Zehavi, HiBob`
- `/apollo:enrich-lead michal@somecompany.com`

## Step 1 — Parse Input

From "$ARGUMENTS", extract every identifier available:
- First name, last name
- Company name or domain
- LinkedIn URL
- Email address
- Job title (use as a matching hint)

If the input is ambiguous (e.g. just "CEO of Figma"), first use `mcp__claude_ai_Apollo_MCP__apollo_mixed_people_api_search` with relevant title and domain filters to identify the person, then proceed to enrichment.

## Step 2 — Enrich the Person

> **Credit warning**: Tell the user enrichment consumes 1 Apollo credit before calling.

Use `mcp__claude_ai_Apollo_MCP__apollo_people_match` with all available identifiers:
- `first_name`, `last_name` if name is known
- `domain` or `organization_name` if company is known
- `linkedin_url` if LinkedIn is provided
- `email` if email is provided
- Set `reveal_personal_emails` to `true`

If the match fails, try `mcp__claude_ai_Apollo_MCP__apollo_mixed_people_api_search` with looser filters and present the top 3 candidates. Ask the user to pick one, then re-enrich.

## Step 3 — Enrich Their Company

Use `mcp__claude_ai_Apollo_MCP__apollo_organizations_enrich` with the person's company domain to pull firmographic context.

## Step 4 — Present the Contact Card

Format the output exactly like this:

---

**[Full Name]** | [Title]
[Company Name] · [Industry] · [Employee Count] employees

| Field | Detail |
|---|---|
| Email (work) | ... |
| Email (personal) | ... (if revealed) |
| Phone (direct) | ... |
| Phone (mobile) | ... |
| Phone (corporate) | ... |
| Location | City, State, Country |
| LinkedIn | URL |
| Company Domain | ... |
| Company Revenue | Range |
| Company Funding | Total raised |
| Company HQ | Location |

### MSApps Relevance Assessment

Based on the enriched data, provide a brief assessment:
- **Industry match**: Does this company operate in a vertical where MSApps has experience? (automotive, health, finance, retail, cyber, proptech, edtech, agritech, logistics, martech, hrtech, cleantech, gaming)
- **Service fit**: Could this company benefit from MSApps services? (mobile app development, web development, outsourcing/team augmentation, IoT, AI integration)
- **Size fit**: Is the company at a stage where they'd hire external dev teams? (Startups post-funding, growing companies 30-1000 employees, enterprises with digital transformation needs)
- **Decision maker**: Is this person in a position to approve dev partnerships? (CEO, CTO, VP Eng, VP R&D, VP IT, Head of Digital)
- **Overall**: 🟢 Strong fit / 🟡 Potential fit / 🔴 Low fit — with a one-line explanation

### Suggested Outreach Angle

Based on the enrichment data, suggest which MSApps message template would work best for this lead:
- If automotive → mention Toyota/Lexus/Geely/Zeekr apps
- If health/medtech → mention Assuta IVF app, Theranica
- If fintech/insurtech → mention Phoenix, Dream Card, Isracard
- If cybersecurity → mention Cynet, outsourcing for rapid scaling
- If retail → mention Fox Group Dream Card, customer engagement apps
- If startup needing dev → mention MVP expertise, senior+junior model
- If enterprise → mention outsourcing model, 15 years experience, managed teams
- Otherwise → use the general "boutique dev partner" angle

---

## Step 5 — Offer Next Actions

Ask the user which action to take:

1. **Save to Apollo** — Create this person as a contact via `mcp__claude_ai_Apollo_MCP__apollo_contacts_create` with `run_dedupe: true`
2. **Add to a sequence** — Ask which sequence, then run the sequence-load flow
3. **Draft LinkedIn message** — Generate a personalized outreach message using the suggested angle above, in MSApps' conversational founder-to-founder tone (from Michal Shatz)
4. **Find colleagues** — Search for more people at the same company using `mcp__claude_ai_Apollo_MCP__apollo_mixed_people_api_search` with `q_organization_domains_list` set to this company
5. **Find similar people** — Search for people with the same title/seniority at other companies in the same segment
