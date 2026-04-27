# opsagent-shopify — plugin notes

A full-stack Shopify plugin for AI agents — Admin API CRUD, Storefront MCP, theme management, and partner marketing.

## MCP Server (v0.2.0)

The `mcp-server/` directory contains a stdio MCP server with **22 tools** across two API layers:

### Storefront API (no admin token needed)

- `shopify_search_products` — Search public catalog
- `shopify_get_product` — Get product by handle
- `shopify_get_cart` / `shopify_update_cart` — Cart operations
- `shopify_get_policies` — Legal policies
- `shopify_list_collections` — Collections
- `shopify_describe_theme` — Shop + theme metadata

### Admin API (requires SHOPIFY_ADMIN_TOKEN)

- **Products**: `shopify_admin_list_products`, `shopify_admin_get_product`, `shopify_admin_create_product`, `shopify_admin_update_product`, `shopify_admin_delete_product`
- **Files**: `shopify_admin_list_files`, `shopify_admin_upload_files`, `shopify_admin_delete_files`
- **Orders**: `shopify_admin_list_orders`, `shopify_admin_get_order`
- **Customers**: `shopify_admin_list_customers`
- **Themes**: `shopify_admin_list_themes`, `shopify_admin_get_theme_files`
- **Metafields**: `shopify_admin_set_metafields`
- **Shop**: `shopify_admin_shop_info`

## SDK (`sdk/`)

`@opsagents/shopify-sdk` — typed contracts (Zod schemas) and HTTP clients for both Admin and Storefront APIs. Public, hire-readable surface consumed by MCP server, dashboard, and Shopify app.

## Skills

- `shopify-partner-marketing` — Shopify Academy partner-marketing course as a skill (positioning, ICP, campaigns, ABM, SEO, events, attribution).

## Setup

Set env vars in plugin config or `.env`:

```
SHOPIFY_DEFAULT_SHOP=your-store.myshopify.com
SHOPIFY_ADMIN_TOKEN=shpat_xxxxx
SHOPIFY_STOREFRONT_TOKEN=your-storefront-token
```
