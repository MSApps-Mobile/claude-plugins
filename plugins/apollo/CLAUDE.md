# Apollo

Apollo.io B2B prospecting and lead enrichment integration. Convert ideal customer profiles into ranked, verified leads with full contact data.

## Available Tools/Skills

- **enrich-lead** - Take name/LinkedIn/email and return complete contact card (phone, company, job title, decision-making authority, emails, LinkedIn URLs)
- **prospect** - Describe your ICP (industry, title, company size, etc.) and get ranked list of qualified leads
- **sequence-load** - Combined workflow: find prospects → enrich each → load directly into outreach sequence (email/SMS)

## Configuration

- **Authentication**: OAuth via `/mcp` command in Claude
- **Credentials**: Secure token-based, scoped to Apollo.io account
- **Server**: HTTP MCP server

## Common Workflows

1. **Enrich a Single Lead**
   - Use `enrich-lead` with any single identifier (name + company, LinkedIn URL, or email)
   - Returns: full contact data, company info, decision-making indicators

2. **Find Prospects for Campaign**
   - Use `prospect` with detailed ICP description
   - Returns: ranked list with LinkedIn URLs, emails, seniority
   - Pick top N for outreach or load into CRM

3. **End-to-End Sequence Creation**
   - Use `sequence-load` once
   - Specify ICP criteria and outreach sequence template
   - Returns: prospects found, enriched, and automatically loaded into sequence

## Best Practices

- **Enrich before outreach** - Always enrich contacts to verify current role/company before reaching out
- **Watch credit usage** - Each person enrichment costs 1 Apollo credit. Preview prospects first before enriching all.
- **Use decision-maker filters** - When prospecting, filter for decision-makers (titles like VP, C-level, department lead)
- **Combine with multi-channel** - Loaded sequences support email and SMS for higher response rates
- **Verify LinkedIn first** - Check LinkedIn profiles for recent activity before prioritizing in outreach
- **Monitor enrichment success rate** - Some records have incomplete data; plan for ~85-90% full enrichment rate
