# @opsagents/shopify-sdk

Typed contracts and HTTP clients for Shopify Admin + Storefront APIs. The public, hire-readable SDK surface that OpsAgent apps, dashboards, and MCP servers consume.

## Install

```bash
npm install @opsagents/shopify-sdk
```

## Usage

### Admin API Client

```js
import { createAdminClient } from "@opsagents/shopify-sdk";

const admin = createAdminClient({
  shopDomain: "your-store.myshopify.com",
  accessToken: "shpat_xxxxx",
});

// List products
const { products } = await admin.listProducts({ first: 10, query: "status:active" });

// Upload a file
const files = await admin.uploadFiles([
  { originalSource: "https://example.com/image.jpg", alt: "Product photo" }
]);

// Create a product
const product = await admin.createProduct({ title: "New Product", status: "DRAFT" });

// Health check
const health = await admin.healthCheck();
```

### Storefront Client

```js
import { createStorefrontClient } from "@opsagents/shopify-sdk";

const storefront = createStorefrontClient({
  shopDomain: "your-store.myshopify.com",
  storefrontToken: "your-storefront-token",
});

const results = await storefront.searchProducts("wool socks");
const product = await storefront.getProduct("merino-crew-socks");
```

### Type Schemas (Zod)

```js
import { ProductSchema, OrderSchema, StoreSummarySchema } from "@opsagents/shopify-sdk/types";

const product = ProductSchema.parse(rawData);
```

### MCP Tool Contracts

```js
import { ALL_TOOLS, getRequiredScopes } from "@opsagents/shopify-sdk/mcp-contracts";

// What scopes do I need?
const scopes = getRequiredScopes(["shopify_admin_create_product", "shopify_admin_upload_files"]);
// → ["write_products", "write_files"]
```

## Architecture

```
@opsagents/shopify-sdk (this package — public, typed contracts)
    ↑ consumed by
opsagent-shopify-core (private — token vault, audit classifier, AI prompts)
    ↑ consumed by
opsagent-shopify-mcp (MCP server)
shopify-admin-dashboard (dashboard)
opsagent-shopify-app (Shopify app)
```

## License

MIT — Michal Shatz / MSApps
