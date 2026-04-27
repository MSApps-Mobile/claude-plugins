# opsagent-shopify

MSApps / OpsAgents plugin — Shopify operating skills bundle.

## Skills

- **`shopify-mcp`** — when and how to use the seven Storefront MCP tools (`shopify_search_products`, `shopify_get_product`, `shopify_get_cart`, `shopify_update_cart`, `shopify_get_policies`, `shopify_list_collections`, `shopify_describe_theme`). Source for this skill currently ships in the rpm plugin distribution; will be folded in here in a future PR.
- **`symmetry-install`** — merchant playbook for adding the Symmetry theme (or any paid Theme Store theme): Admin UI path, CLI path, Chrome-automation path, with safety checklists. Same source-mirroring caveat as above.
- **`shopify-partner-marketing`** — full Shopify Academy *Marketing Your Shopify Services as a Partner* playbook, plus public Partner Program leverage. Covers positioning, ICP/audience, multi-touch campaigns, ABM, digital marketing, SEO, event marketing, attribution, and assessment prep.

## When to use this plugin

Install this plugin if you are:

- An agency or freelancer who is (or wants to be) a Shopify Partner and needs to **market their own services** — not their merchants'.
- Operating one or more Shopify storefronts and need MCP tools to read/write catalog, cart, and theme data.
- Helping a merchant install the Symmetry theme (or any Theme Store theme) without breaking their live storefront.
- Preparing for or taking the Shopify Academy *Marketing Your Shopify Services as a Partner* assessment to earn a Verified Skill badge.

## Install

This plugin is part of the MSApps marketplace at https://github.com/MSApps-Mobile/claude-plugins. Install via the marketplace listing.

The companion `opsagent-shopify-mcp` desktop extension provides the Storefront MCP tools (the seven `shopify_*` tools). Without those tools active, `shopify-mcp` and `symmetry-install` still produce useful guidance, but action calls won't have backing tools to fire.

## SOSA

- **Supervised** — destructive merchant actions (publishing themes, starting checkouts) require explicit user confirmation.
- **Orchestrated** — every skill follows Plan → Act → Verify.
- **Secured** — Storefront tokens are sensitive; never logged.
- **Agents** — clear scope per skill (no Admin API, no Partner API write, no Liquid edits).

## License

MIT — see top-level LICENSE in the claude-plugins repo.
