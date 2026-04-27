#!/usr/bin/env node
/**
 * opsagent-shopify-mcp — stdio MCP server for multi-tenant Shopify agents.
 *
 * Two API layers:
 *   1. Storefront API (read-only catalog, cart, policies) — no admin token needed
 *   2. Admin API (products CRUD, files, orders, customers, themes, metafields) — needs SHOPIFY_ADMIN_TOKEN
 *
 * Run locally:  node dist/server.js          (after `npm run build`)
 * Inspector:    npm run inspect
 * Claude Desktop: add to claude_desktop_config.json (see README).
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import {
  callStorefrontMcp,
  storefrontGraphQL,
  StorefrontError,
  type ShopContext,
} from "./storefront.js";
import {
  AdminError,
  listProducts,
  getProduct as adminGetProduct,
  createProduct,
  updateProduct,
  deleteProduct,
  listFiles,
  createFiles,
  deleteFiles,
  listOrders,
  getOrder,
  listCustomers,
  listThemes,
  getThemeFiles,
  setMetafields,
  getShopInfo,
} from "./admin.js";

const server = new McpServer({
  name: "opsagent-shopify-mcp",
  version: "0.2.0",
});

/** Every tool accepts this shop context. */
const shopArg = {
  shop: z
    .string()
    .regex(/^[a-z0-9-]+\.myshopify\.com$/i)
    .optional()
    .describe(
      "Shop domain, e.g. mama-sally.myshopify.com. Falls back to SHOPIFY_DEFAULT_SHOP env var."
    ),
};

function asText(data: unknown): { content: { type: "text"; text: string }[] } {
  return {
    content: [
      { type: "text", text: typeof data === "string" ? data : JSON.stringify(data, null, 2) },
    ],
  };
}

function asError(e: unknown): {
  content: { type: "text"; text: string }[];
  isError: true;
} {
  const msg =
    e instanceof StorefrontError
      ? e.message
      : e instanceof AdminError
      ? e.message
      : e instanceof Error
      ? e.message
      : String(e);
  return { content: [{ type: "text", text: `Error: ${msg}` }], isError: true };
}

// =============================================================================
// STOREFRONT API TOOLS (read-only, no admin token needed)
// =============================================================================

server.tool(
  "shopify_search_products",
  "Search a merchant's public catalog. Wraps the Shopify Storefront MCP `search_shop_catalog` tool. Read-only, no token required. Use for: product discovery, recommendation flows, search-bar-style queries.",
  {
    ...shopArg,
    query: z.string().min(1).describe("Free-text search query, e.g. 'wool socks', 'gift under $50'."),
    limit: z.number().int().min(1).max(50).optional().describe("Max results (default 10)."),
  },
  async ({ shop, query, limit }) => {
    try {
      const result = await callStorefrontMcp(
        "search_shop_catalog",
        { query, limit: limit ?? 10 },
        { shop }
      );
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_get_product",
  "Fetch a single product by handle (URL slug) via Storefront GraphQL. Returns title, description, images, variants, price range, and availability. Requires SHOPIFY_STOREFRONT_TOKEN.",
  {
    ...shopArg,
    handle: z.string().min(1).describe("Product handle — the URL slug, e.g. 'merino-crew-socks'."),
  },
  async ({ shop, handle }) => {
    try {
      const data = await storefrontGraphQL<{ productByHandle: unknown }>(
        /* GraphQL */ `
          query ProductByHandle($handle: String!) {
            productByHandle(handle: $handle) {
              id
              title
              handle
              description(truncateAt: 500)
              vendor
              productType
              tags
              availableForSale
              totalInventory
              priceRange {
                minVariantPrice { amount currencyCode }
                maxVariantPrice { amount currencyCode }
              }
              featuredImage { url altText width height }
              variants(first: 10) {
                nodes {
                  id
                  title
                  availableForSale
                  quantityAvailable
                  price { amount currencyCode }
                }
              }
            }
          }
        `,
        { handle },
        { shop }
      );
      if (!data.productByHandle) {
        return asError(`No product found with handle "${handle}".`);
      }
      return asText(data.productByHandle);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_get_cart",
  "Read the current state of a cart by cart ID. Wraps Storefront MCP `get_cart`. Idempotent, read-only.",
  {
    ...shopArg,
    cart_id: z.string().min(1).describe("Cart ID as returned from `shopify_update_cart` (format: gid://shopify/Cart/...)."),
  },
  async ({ shop, cart_id }) => {
    try {
      const result = await callStorefrontMcp("get_cart", { cart_id }, { shop });
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_update_cart",
  "Create a new cart or mutate an existing one — add, update, or remove line items. Wraps Storefront MCP `update_cart`.",
  {
    ...shopArg,
    cart_id: z.string().optional().describe("Existing cart ID to mutate. Omit to create a new cart."),
    add_items: z
      .array(
        z.object({
          product_variant_id: z.string().describe("Variant GID, e.g. gid://shopify/ProductVariant/123"),
          quantity: z.number().int().min(1).default(1),
        })
      )
      .optional()
      .describe("Line items to add."),
    update_items: z
      .array(
        z.object({
          line_id: z.string().describe("Cart line GID to update."),
          quantity: z.number().int().min(0).describe("New quantity. 0 removes the line."),
        })
      )
      .optional()
      .describe("Existing lines to change."),
    remove_line_ids: z.array(z.string()).optional().describe("Line IDs to remove outright."),
  },
  async ({ shop, cart_id, add_items, update_items, remove_line_ids }) => {
    try {
      const args: Record<string, unknown> = {};
      if (cart_id) args.cart_id = cart_id;
      if (add_items) args.add_items = add_items;
      if (update_items) args.update_items = update_items;
      if (remove_line_ids) args.remove_line_ids = remove_line_ids;
      const result = await callStorefrontMcp("update_cart", args, { shop });
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_get_policies",
  "Fetch the shop's legal policies (shipping, refund, privacy, terms). Useful for customer-support agents.",
  { ...shopArg },
  async ({ shop }) => {
    try {
      const data = await storefrontGraphQL<{ shop: unknown }>(
        /* GraphQL */ `
          query Policies {
            shop {
              name
              primaryDomain { url host }
              shippingPolicy { title body(truncateAt: 2000) }
              refundPolicy   { title body(truncateAt: 2000) }
              privacyPolicy  { title body(truncateAt: 2000) }
              termsOfService { title body(truncateAt: 2000) }
            }
          }
        `,
        {},
        { shop }
      );
      return asText(data.shop);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_list_collections",
  "List storefront collections (category pages). Read-only.",
  {
    ...shopArg,
    limit: z.number().int().min(1).max(50).optional().describe("Max collections (default 20)."),
  },
  async ({ shop, limit }) => {
    try {
      const data = await storefrontGraphQL<{ collections: unknown }>(
        /* GraphQL */ `
          query Collections($first: Int!) {
            collections(first: $first) {
              nodes { id handle title description(truncateAt: 200) }
            }
          }
        `,
        { first: limit ?? 20 },
        { shop }
      );
      return asText(data.collections);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_describe_theme",
  "Return metadata about the shop's live storefront (theme name if exposed, shop name, domain). Useful before theme-swap operations like installing Symmetry.",
  { ...shopArg },
  async ({ shop }) => {
    try {
      const data = await storefrontGraphQL<{ shop: unknown }>(
        /* GraphQL */ `
          query ShopInfo {
            shop {
              name
              description
              primaryDomain { url host sslEnabled }
              paymentSettings { currencyCode supportedDigitalWallets }
              brand {
                logo { image { url } }
                colors { primary { foreground background } }
              }
            }
          }
        `,
        {},
        { shop }
      );
      return asText(data.shop);
    } catch (e) {
      return asError(e);
    }
  }
);

// =============================================================================
// ADMIN API TOOLS (require SHOPIFY_ADMIN_TOKEN)
// =============================================================================

// -- Products (Admin) ---------------------------------------------------------

server.tool(
  "shopify_admin_list_products",
  "List products via Admin API with full details (status, inventory, variants, metafields). Supports Shopify search syntax. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    first: z.number().int().min(1).max(50).optional().describe("Max products to return (default 20)."),
    query: z.string().optional().describe("Shopify search query, e.g. 'status:active', 'tag:sale', 'vendor:Nike'. Omit for all products."),
  },
  async ({ shop, first, query }) => {
    try {
      const result = await listProducts({ first, query }, { shop });
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_admin_get_product",
  "Fetch a single product by GID via Admin API. Returns full details: HTML description, all images, all variants with SKU/barcode/inventory, metafields, SEO. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    id: z.string().min(1).describe("Product GID, e.g. gid://shopify/Product/1234567890."),
  },
  async ({ shop, id }) => {
    try {
      const product = await adminGetProduct(id, { shop });
      if (!product) return asError(`Product not found: ${id}`);
      return asText(product);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_admin_create_product",
  "Create a new product via Admin API. Returns the created product's id, title, handle, status. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    title: z.string().min(1).describe("Product title."),
    descriptionHtml: z.string().optional().describe("Product description in HTML."),
    vendor: z.string().optional().describe("Product vendor/brand."),
    productType: z.string().optional().describe("Product type."),
    tags: z.array(z.string()).optional().describe("Product tags."),
    status: z.enum(["ACTIVE", "DRAFT", "ARCHIVED"]).optional().describe("Product status (default DRAFT)."),
    images: z.array(z.object({
      src: z.string().describe("Image URL to import."),
      altText: z.string().optional(),
    })).optional().describe("Product images to attach."),
  },
  async ({ shop, title, descriptionHtml, vendor, productType, tags, status, images }) => {
    try {
      const input: Record<string, unknown> = { title };
      if (descriptionHtml) input.descriptionHtml = descriptionHtml;
      if (vendor) input.vendor = vendor;
      if (productType) input.productType = productType;
      if (tags) input.tags = tags;
      if (status) input.status = status;
      if (images) input.images = images;
      const product = await createProduct(input, { shop });
      return asText(product);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_admin_update_product",
  "Update an existing product via Admin API. Pass the product GID and any fields to change. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    id: z.string().min(1).describe("Product GID to update, e.g. gid://shopify/Product/1234567890."),
    title: z.string().optional().describe("New title."),
    descriptionHtml: z.string().optional().describe("New description in HTML."),
    vendor: z.string().optional().describe("New vendor."),
    productType: z.string().optional().describe("New product type."),
    tags: z.array(z.string()).optional().describe("New tags (replaces all)."),
    status: z.enum(["ACTIVE", "DRAFT", "ARCHIVED"]).optional().describe("New status."),
  },
  async ({ shop, id, title, descriptionHtml, vendor, productType, tags, status }) => {
    try {
      const input: Record<string, unknown> = { id };
      if (title) input.title = title;
      if (descriptionHtml) input.descriptionHtml = descriptionHtml;
      if (vendor) input.vendor = vendor;
      if (productType) input.productType = productType;
      if (tags) input.tags = tags;
      if (status) input.status = status;
      const product = await updateProduct(input, { shop });
      return asText(product);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_admin_delete_product",
  "Delete a product by GID via Admin API. This is permanent. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    id: z.string().min(1).describe("Product GID to delete, e.g. gid://shopify/Product/1234567890."),
  },
  async ({ shop, id }) => {
    try {
      const deletedId = await deleteProduct(id, { shop });
      return asText({ deleted: true, deletedProductId: deletedId });
    } catch (e) {
      return asError(e);
    }
  }
);

// -- Files (Admin) ------------------------------------------------------------

server.tool(
  "shopify_admin_list_files",
  "List files in Shopify Files (CDN-hosted media). Supports search. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    first: z.number().int().min(1).max(50).optional().describe("Max files (default 20)."),
    query: z.string().optional().describe("Search query for files, e.g. 'photo1' or 'media_type:IMAGE'."),
  },
  async ({ shop, first, query }) => {
    try {
      const result = await listFiles({ first, query }, { shop });
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_admin_upload_files",
  "Upload files to Shopify Files by providing public URLs. Shopify will fetch and host them on its CDN. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    files: z.array(z.object({
      originalSource: z.string().url().describe("Public URL of the file to import (Shopify fetches it)."),
      alt: z.string().optional().describe("Alt text for images."),
      contentType: z.enum(["IMAGE", "FILE"]).optional().describe("Content type hint (default IMAGE)."),
    })).min(1).describe("Files to upload. Each needs a publicly accessible URL."),
  },
  async ({ shop, files }) => {
    try {
      const result = await createFiles(files, { shop });
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_admin_delete_files",
  "Delete files from Shopify Files by their GIDs. Permanent. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    file_ids: z.array(z.string().min(1)).min(1).describe("File GIDs to delete, e.g. ['gid://shopify/MediaImage/123']."),
  },
  async ({ shop, file_ids }) => {
    try {
      const deleted = await deleteFiles(file_ids, { shop });
      return asText({ deleted: true, deletedFileIds: deleted });
    } catch (e) {
      return asError(e);
    }
  }
);

// -- Orders (Admin) -----------------------------------------------------------

server.tool(
  "shopify_admin_list_orders",
  "List orders via Admin API. Supports Shopify order search syntax. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    first: z.number().int().min(1).max(50).optional().describe("Max orders (default 20)."),
    query: z.string().optional().describe("Shopify order search, e.g. 'financial_status:paid', 'fulfillment_status:unfulfilled', 'email:customer@example.com'."),
  },
  async ({ shop, first, query }) => {
    try {
      const result = await listOrders({ first, query }, { shop });
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_admin_get_order",
  "Fetch a single order by GID via Admin API. Returns full details including line items, fulfillments, customer, addresses. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    id: z.string().min(1).describe("Order GID, e.g. gid://shopify/Order/1234567890."),
  },
  async ({ shop, id }) => {
    try {
      const order = await getOrder(id, { shop });
      if (!order) return asError(`Order not found: ${id}`);
      return asText(order);
    } catch (e) {
      return asError(e);
    }
  }
);

// -- Customers (Admin) --------------------------------------------------------

server.tool(
  "shopify_admin_list_customers",
  "List customers via Admin API. Supports Shopify customer search syntax. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    first: z.number().int().min(1).max(50).optional().describe("Max customers (default 20)."),
    query: z.string().optional().describe("Shopify customer search, e.g. 'email:*@gmail.com', 'orders_count:>5', 'tag:vip'."),
  },
  async ({ shop, first, query }) => {
    try {
      const result = await listCustomers({ first, query }, { shop });
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

// -- Themes (Admin) -----------------------------------------------------------

server.tool(
  "shopify_admin_list_themes",
  "List all themes on the store (live, unpublished, development). Requires SHOPIFY_ADMIN_TOKEN.",
  { ...shopArg },
  async ({ shop }) => {
    try {
      const themes = await listThemes({ shop });
      return asText(themes);
    } catch (e) {
      return asError(e);
    }
  }
);

server.tool(
  "shopify_admin_get_theme_files",
  "Read specific theme files by filename (e.g. sections/header.liquid, config/settings_data.json). Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    theme_id: z.string().min(1).describe("Theme GID, e.g. gid://shopify/OnlineStoreTheme/144951804013."),
    filenames: z.array(z.string().min(1)).min(1).describe("File paths within the theme, e.g. ['sections/header.liquid', 'config/settings_data.json']."),
  },
  async ({ shop, theme_id, filenames }) => {
    try {
      const result = await getThemeFiles(theme_id, filenames, { shop });
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

// -- Metafields (Admin) -------------------------------------------------------

server.tool(
  "shopify_admin_set_metafields",
  "Set metafields on any Shopify resource (product, customer, order, shop). Creates or updates. Requires SHOPIFY_ADMIN_TOKEN.",
  {
    ...shopArg,
    metafields: z.array(z.object({
      ownerId: z.string().describe("Resource GID, e.g. gid://shopify/Product/123."),
      namespace: z.string().describe("Metafield namespace, e.g. 'custom' or 'opsagent'."),
      key: z.string().describe("Metafield key."),
      value: z.string().describe("Metafield value (JSON-encoded for complex types)."),
      type: z.string().describe("Metafield type, e.g. 'single_line_text_field', 'json', 'number_integer'."),
    })).min(1).describe("Metafields to set."),
  },
  async ({ shop, metafields }) => {
    try {
      const result = await setMetafields(metafields, { shop });
      return asText(result);
    } catch (e) {
      return asError(e);
    }
  }
);

// -- Shop Info (Admin) --------------------------------------------------------

server.tool(
  "shopify_admin_shop_info",
  "Fetch detailed shop info via Admin API — plan, billing address, timezone, currency, domain. More detailed than the Storefront version. Requires SHOPIFY_ADMIN_TOKEN.",
  { ...shopArg },
  async ({ shop }) => {
    try {
      const info = await getShopInfo({ shop });
      return asText(info);
    } catch (e) {
      return asError(e);
    }
  }
);

// -----------------------------------------------------------------------------
// Boot
// -----------------------------------------------------------------------------

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(
    `[opsagent-shopify-mcp] v0.2.0 ready. shop: ${process.env.SHOPIFY_DEFAULT_SHOP || "(unset)"}, admin: ${process.env.SHOPIFY_ADMIN_TOKEN ? "configured" : "not set"}`
  );
}

main().catch((e) => {
  console.error("[opsagent-shopify-mcp] fatal:", e);
  process.exit(1);
});
