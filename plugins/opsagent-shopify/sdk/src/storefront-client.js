/**
 * @opsagents/shopify-sdk — Storefront API client (re-export from opsagent-core).
 *
 * The Storefront MCP adapter already exists in @opsagent/core. This module
 * re-exports it and adds a thin convenience layer so SDK consumers get a
 * consistent API shape between Admin and Storefront clients.
 *
 * For new integrations, prefer createAdminClient from admin-client.js — the
 * Storefront client is for catalog-only read paths where no admin token exists.
 */

// Re-export the existing Storefront MCP client factory and schemas
// from @opsagent/core if available, otherwise provide a standalone version.

const DEFAULT_API_VERSION = "2025-04";

/**
 * @typedef {Object} StorefrontClientConfig
 * @property {string} shopDomain
 * @property {string} [storefrontToken] Storefront API access token
 * @property {string} [apiVersion]
 * @property {typeof fetch} [fetchImpl]
 */

/**
 * Create a Shopify Storefront API client.
 *
 * Two transport paths:
 * 1. Storefront MCP (JSON-RPC at /api/mcp) — no token required
 * 2. Storefront GraphQL — requires storefrontToken
 *
 * @param {StorefrontClientConfig} config
 */
export function createStorefrontClient(config) {
  if (!config?.shopDomain) throw new Error("shopify-sdk: shopDomain required");

  const apiVersion = config.apiVersion || DEFAULT_API_VERSION;
  const fetchImpl = config.fetchImpl || globalThis.fetch;
  const mcpUrl = `https://${config.shopDomain}/api/mcp`;
  const gqlUrl = `https://${config.shopDomain}/api/${apiVersion}/graphql.json`;

  /**
   * Call Storefront MCP endpoint (no token).
   */
  async function callMcp(method, params = {}) {
    const id = Math.random().toString(36).slice(2) + Date.now().toString(36);
    const res = await fetchImpl(mcpUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id,
        method: "tools/call",
        params: { name: method, arguments: params },
      }),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`shopify-sdk: Storefront MCP ${res.status}: ${text.slice(0, 300)}`);
    }
    const payload = await res.json();
    if (payload.error) throw new Error(`shopify-sdk: MCP error: ${payload.error.message}`);
    return payload.result;
  }

  /**
   * Call Storefront GraphQL (requires token).
   */
  async function graphql(query, variables = {}) {
    if (!config.storefrontToken) {
      throw new Error("shopify-sdk: Storefront GraphQL requires storefrontToken");
    }
    const res = await fetchImpl(gqlUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Shopify-Storefront-Access-Token": config.storefrontToken,
      },
      body: JSON.stringify({ query, variables }),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`shopify-sdk: Storefront GraphQL ${res.status}: ${text.slice(0, 300)}`);
    }
    const payload = await res.json();
    if (payload.errors?.length) {
      throw new Error(`shopify-sdk: ${payload.errors.map(e => e.message).join("; ")}`);
    }
    return payload.data;
  }

  return {
    shopDomain: config.shopDomain,
    callMcp,
    graphql,

    async searchProducts(query, { limit = 10 } = {}) {
      return callMcp("search_shop_catalog", { query, limit });
    },

    async getProduct(handle) {
      const data = await graphql(`
        query($handle: String!) {
          productByHandle(handle: $handle) {
            id title handle description(truncateAt: 500) vendor productType tags
            availableForSale totalInventory
            priceRange { minVariantPrice { amount currencyCode } maxVariantPrice { amount currencyCode } }
            featuredImage { url altText width height }
            variants(first: 10) { nodes { id title availableForSale quantityAvailable price { amount currencyCode } } }
          }
        }
      `, { handle });
      return data.productByHandle;
    },

    async listCollections({ limit = 20 } = {}) {
      const data = await graphql(`
        query($first: Int!) { collections(first: $first) { nodes { id handle title description(truncateAt: 200) } } }
      `, { first: limit });
      return data.collections.nodes;
    },

    async getPolicies() {
      const data = await graphql(`
        query { shop { name shippingPolicy { title body(truncateAt: 2000) } refundPolicy { title body(truncateAt: 2000) } privacyPolicy { title body(truncateAt: 2000) } termsOfService { title body(truncateAt: 2000) } } }
      `);
      return data.shop;
    },

    async getCart(cartId) {
      return callMcp("get_cart", { cart_id: cartId });
    },

    async updateCart(params) {
      return callMcp("update_cart", params);
    },

    async healthCheck() {
      try {
        await callMcp("search_shop_catalog", { query: "test", limit: 1 });
        return { healthy: true, transport: "mcp" };
      } catch (e) {
        return { healthy: false, error: e.message };
      }
    },
  };
}
