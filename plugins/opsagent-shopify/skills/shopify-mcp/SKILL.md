---
name: shopify-mcp
description: >
  Use Shopify Storefront MCP tools to search catalogs, inspect products, read
  and mutate carts, fetch policies, and describe shops across any MSApps /
  OpsAgents client store — multi-tenant, no shop hardcoded. Trigger on:
  "shopify", "storefront", "myshopify", "cart", "checkout", "products",
  "catalog", "collection", "shipping policy", "refund policy", "client store",
  "merchant", or any task that needs live data from a Shopify merchant. Also
  use when the user wants to prototype a conversational shopping flow, a
  recommendation agent, or a customer-support bot over a Shopify store.
---

# Shopify MCP — multi-tenant storefront operator

Use this skill whenever Claude needs to act on a Shopify store through the
`opsagent-shopify` MCP server. Prefer these tools over raw `fetch` calls or
the generic `apify-scraping` skill — they are tokened, rate-aware, and
multi-tenant.

## When to trigger

- "What's in `<client-handle>`'s catalog right now?"
- "Find products in shop X under $50 that contain 'linen'."
- "Build me a cart with three of variant ID ..."
- "Read the shipping policy of `foo.myshopify.com`."
- "Describe the storefront of this shop before we swap the theme."
- "Why is `selectModel()` returning undefined on the product page of `<shop>`?"
  → call `shopify_describe_theme` first to confirm which theme + version is
  live before diving into theme JS.

## Mental model

**One install, every store.** Each tool takes an optional `shop` argument of
the form `<handle>.myshopify.com`. If omitted, the server falls back to
`SHOPIFY_DEFAULT_SHOP` (set per-client in the MCP config). Never hardcode a
shop inside the skill — pass it explicitly when the user mentions one.

**Two backends, one surface:**
- Public catalog + cart ops go to Shopify's **Storefront MCP** endpoint
  (`https://{shop}/api/mcp`). No token. Tools: `shopify_search_products`,
  `shopify_get_cart`, `shopify_update_cart`.
- Richer read ops (products by handle, policies, collections, shop metadata)
  go to **Storefront GraphQL**. Needs `SHOPIFY_STOREFRONT_TOKEN`.

If a GraphQL tool errors with "Storefront GraphQL requires a token," surface
that to the user and ask them to paste one into the plugin config — don't
silently degrade.

## Plan → Act → Verify

1. **Plan** — Identify the shop and the intent (read vs cart-mutation vs
   checkout-mutation). Read ops are cheap; cart mutations should be confirmed
   with the user if the cart is real (not a throwaway test cart).
2. **Act** — Call the narrowest tool. Prefer `shopify_search_products` over
   pulling the whole catalog. Prefer `shopify_get_product` for detail pages.
3. **Verify** — For cart mutations, re-fetch with `shopify_get_cart` and show
   the resulting line items. For checkout starts, return the URL and tell the
   user what will happen if they open it.

## Tools at a glance

| Tool | Class | Token? | Purpose |
| --- | --- | --- | --- |
| `shopify_search_products` | read | no  | Search catalog by free text. |
| `shopify_get_product` | read | yes | Product detail by handle. |
| `shopify_get_cart` | read | no  | Cart state by ID. |
| `shopify_update_cart` | cart-mutation | no | Create/add/update/remove lines. |
| `shopify_get_policies` | read | yes | Shipping / refund / privacy / terms. |
| `shopify_list_collections` | read | yes | Category pages. |
| `shopify_describe_theme` | read | yes | Shop + brand + domain metadata. |

## Failure modes to watch

- **No shop configured** → "No shop configured. Pass `shop` argument or set
  SHOPIFY_DEFAULT_SHOP." Ask the user which store, don't guess.
- **Invalid domain format** → reject anything that isn't
  `<handle>.myshopify.com`. Custom vanity domains (e.g. `<brand>.com`) need
  to be resolved to their `myshopify.com` canonical form first.
- **GraphQL 401/403** → Storefront token expired or scoped too narrow.
  Regenerate in Admin → Sales channels → Headless.
- **Rate limits** → Storefront API allows ~60 RPM per shop. If bursting,
  chunk and backoff; never retry blindly.

## Handoff to related skills

- For theme changes (Symmetry install, customizing Liquid), invoke the
  `symmetry-install` skill in this same plugin.
- For Liquid code edits, defer to the `shopify-liquid` reference skill.
- For the app side (OAuth install on a merchant's admin, webhook
  registration), the `opsagent-shopify-mcp` repo README has the CLI flow.

## SOSA notes

- **Supervised** — cart and checkout mutations must be confirmed with the
  user when they touch a real customer cart. Read ops are unsupervised.
- **Secured** — the Storefront token is sensitive and per-shop; never log it
  or include it in tool outputs.
- **Agents** — this skill owns Shopify-facing data ops only. It does NOT
  touch theme files, Liquid, billing, or Partner API — those are other
  skills or the Admin API (not this server).
