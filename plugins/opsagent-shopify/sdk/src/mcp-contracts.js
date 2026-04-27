/**
 * @opsagents/shopify-sdk — MCP Tool Contracts.
 *
 * Declares the exact tool name, input schema, output schema, and side-effect
 * classification for every Shopify MCP tool. Used by:
 *   - The MCP server to register tools
 *   - The dashboard to display available capabilities
 *   - Agent task configs to declare required tools
 *   - Health checks to verify tool availability
 */

import { z } from "zod";

/**
 * Tool side-effect classification — drives retry policy and audit logging.
 * @typedef {"read" | "write-low" | "write-medium" | "write-high" | "cart-mutation"} SideEffect
 */

/**
 * @typedef {Object} McpToolContract
 * @property {string} name
 * @property {string} description
 * @property {z.ZodTypeAny} input
 * @property {z.ZodTypeAny} output
 * @property {SideEffect} sideEffect
 * @property {string} apiLayer "storefront" | "admin"
 * @property {string[]} requiredScopes
 */

const ShopArg = z.object({
  shop: z.string().regex(/^[a-z0-9-]+\.myshopify\.com$/i).optional(),
});

// ---------------------------------------------------------------------------
// Storefront tools
// ---------------------------------------------------------------------------

export const STOREFRONT_TOOLS = {
  shopify_search_products: {
    name: "shopify_search_products",
    description: "Search a merchant's public catalog.",
    input: ShopArg.extend({
      query: z.string().min(1),
      limit: z.number().int().min(1).max(50).optional(),
    }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "storefront",
    requiredScopes: [],
  },
  shopify_get_product: {
    name: "shopify_get_product",
    description: "Fetch a single product by handle via Storefront GraphQL.",
    input: ShopArg.extend({ handle: z.string().min(1) }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "storefront",
    requiredScopes: [],
  },
  shopify_get_cart: {
    name: "shopify_get_cart",
    description: "Read cart by ID.",
    input: ShopArg.extend({ cart_id: z.string().min(1) }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "storefront",
    requiredScopes: [],
  },
  shopify_update_cart: {
    name: "shopify_update_cart",
    description: "Create or mutate a cart.",
    input: ShopArg.extend({
      cart_id: z.string().optional(),
      add_items: z.array(z.object({ product_variant_id: z.string(), quantity: z.number() })).optional(),
      update_items: z.array(z.object({ line_id: z.string(), quantity: z.number() })).optional(),
      remove_line_ids: z.array(z.string()).optional(),
    }),
    output: z.unknown(),
    sideEffect: "cart-mutation",
    apiLayer: "storefront",
    requiredScopes: [],
  },
  shopify_get_policies: {
    name: "shopify_get_policies",
    description: "Fetch shop legal policies.",
    input: ShopArg,
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "storefront",
    requiredScopes: [],
  },
  shopify_list_collections: {
    name: "shopify_list_collections",
    description: "List storefront collections.",
    input: ShopArg.extend({ limit: z.number().int().min(1).max(50).optional() }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "storefront",
    requiredScopes: [],
  },
  shopify_describe_theme: {
    name: "shopify_describe_theme",
    description: "Shop + theme metadata.",
    input: ShopArg,
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "storefront",
    requiredScopes: [],
  },
};

// ---------------------------------------------------------------------------
// Admin tools
// ---------------------------------------------------------------------------

export const ADMIN_TOOLS = {
  shopify_admin_list_products: {
    name: "shopify_admin_list_products",
    description: "List products via Admin API with full details.",
    input: ShopArg.extend({
      first: z.number().int().min(1).max(50).optional(),
      query: z.string().optional(),
    }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "admin",
    requiredScopes: ["read_products"],
  },
  shopify_admin_get_product: {
    name: "shopify_admin_get_product",
    description: "Get product by GID with full admin data.",
    input: ShopArg.extend({ id: z.string().min(1) }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "admin",
    requiredScopes: ["read_products"],
  },
  shopify_admin_create_product: {
    name: "shopify_admin_create_product",
    description: "Create a new product.",
    input: ShopArg.extend({
      title: z.string().min(1),
      descriptionHtml: z.string().optional(),
      vendor: z.string().optional(),
      productType: z.string().optional(),
      tags: z.array(z.string()).optional(),
      status: z.enum(["ACTIVE", "DRAFT", "ARCHIVED"]).optional(),
    }),
    output: z.unknown(),
    sideEffect: "write-medium",
    apiLayer: "admin",
    requiredScopes: ["write_products"],
  },
  shopify_admin_update_product: {
    name: "shopify_admin_update_product",
    description: "Update an existing product.",
    input: ShopArg.extend({
      id: z.string().min(1),
      title: z.string().optional(),
      descriptionHtml: z.string().optional(),
      vendor: z.string().optional(),
      tags: z.array(z.string()).optional(),
      status: z.enum(["ACTIVE", "DRAFT", "ARCHIVED"]).optional(),
    }),
    output: z.unknown(),
    sideEffect: "write-medium",
    apiLayer: "admin",
    requiredScopes: ["write_products"],
  },
  shopify_admin_delete_product: {
    name: "shopify_admin_delete_product",
    description: "Delete a product (permanent).",
    input: ShopArg.extend({ id: z.string().min(1) }),
    output: z.unknown(),
    sideEffect: "write-high",
    apiLayer: "admin",
    requiredScopes: ["write_products"],
  },
  shopify_admin_list_files: {
    name: "shopify_admin_list_files",
    description: "List files in Shopify Files.",
    input: ShopArg.extend({
      first: z.number().int().min(1).max(50).optional(),
      query: z.string().optional(),
    }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "admin",
    requiredScopes: ["read_files"],
  },
  shopify_admin_upload_files: {
    name: "shopify_admin_upload_files",
    description: "Upload files by URL to Shopify CDN.",
    input: ShopArg.extend({
      files: z.array(z.object({
        originalSource: z.string().url(),
        alt: z.string().optional(),
        contentType: z.enum(["IMAGE", "FILE"]).optional(),
      })).min(1),
    }),
    output: z.unknown(),
    sideEffect: "write-low",
    apiLayer: "admin",
    requiredScopes: ["write_files"],
  },
  shopify_admin_delete_files: {
    name: "shopify_admin_delete_files",
    description: "Delete files from Shopify Files.",
    input: ShopArg.extend({
      file_ids: z.array(z.string().min(1)).min(1),
    }),
    output: z.unknown(),
    sideEffect: "write-medium",
    apiLayer: "admin",
    requiredScopes: ["write_files"],
  },
  shopify_admin_list_orders: {
    name: "shopify_admin_list_orders",
    description: "List/search orders.",
    input: ShopArg.extend({
      first: z.number().int().min(1).max(50).optional(),
      query: z.string().optional(),
    }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "admin",
    requiredScopes: ["read_orders"],
  },
  shopify_admin_get_order: {
    name: "shopify_admin_get_order",
    description: "Get full order details.",
    input: ShopArg.extend({ id: z.string().min(1) }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "admin",
    requiredScopes: ["read_orders"],
  },
  shopify_admin_list_customers: {
    name: "shopify_admin_list_customers",
    description: "List/search customers.",
    input: ShopArg.extend({
      first: z.number().int().min(1).max(50).optional(),
      query: z.string().optional(),
    }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "admin",
    requiredScopes: ["read_customers"],
  },
  shopify_admin_list_themes: {
    name: "shopify_admin_list_themes",
    description: "List all themes on the store.",
    input: ShopArg,
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "admin",
    requiredScopes: ["read_themes"],
  },
  shopify_admin_get_theme_files: {
    name: "shopify_admin_get_theme_files",
    description: "Read theme file contents.",
    input: ShopArg.extend({
      theme_id: z.string().min(1),
      filenames: z.array(z.string().min(1)).min(1),
    }),
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "admin",
    requiredScopes: ["read_themes"],
  },
  shopify_admin_set_metafields: {
    name: "shopify_admin_set_metafields",
    description: "Set metafields on any resource.",
    input: ShopArg.extend({
      metafields: z.array(z.object({
        ownerId: z.string(),
        namespace: z.string(),
        key: z.string(),
        value: z.string(),
        type: z.string(),
      })).min(1),
    }),
    output: z.unknown(),
    sideEffect: "write-low",
    apiLayer: "admin",
    requiredScopes: ["write_content"],
  },
  shopify_admin_shop_info: {
    name: "shopify_admin_shop_info",
    description: "Detailed shop info (Admin).",
    input: ShopArg,
    output: z.unknown(),
    sideEffect: "read",
    apiLayer: "admin",
    requiredScopes: [],
  },
};

/** All tool contracts merged. */
export const ALL_TOOLS = { ...STOREFRONT_TOOLS, ...ADMIN_TOOLS };

/** Get required scopes for a set of tool names. */
export function getRequiredScopes(toolNames) {
  const scopes = new Set();
  for (const name of toolNames) {
    const tool = ALL_TOOLS[name];
    if (tool?.requiredScopes) {
      tool.requiredScopes.forEach(s => scopes.add(s));
    }
  }
  return [...scopes];
}

/** Get all tools for a given API layer. */
export function getToolsByLayer(layer) {
  return Object.values(ALL_TOOLS).filter(t => t.apiLayer === layer);
}
