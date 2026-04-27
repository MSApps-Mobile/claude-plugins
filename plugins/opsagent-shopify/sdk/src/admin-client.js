/**
 * @opsagents/shopify-sdk — Admin API client.
 *
 * Thin, typed wrapper around Shopify Admin GraphQL. Handles:
 * - Cost-based rate limiting with exponential backoff
 * - Automatic retry on 429/5xx
 * - Pre-shaped responses matching SDK type contracts
 *
 * This is the public SDK surface — no moat code (token vault, audit classifier,
 * AI prompts) lives here. Those stay in opsagent-shopify-core (private).
 */

import { z } from "zod";

const DEFAULT_API_VERSION = "2025-04";
const MAX_RETRIES = 3;
const RETRY_BASE_MS = 500;
const RETRYABLE_HTTP = new Set([408, 429, 500, 502, 503, 504]);

/**
 * @typedef {Object} AdminClientConfig
 * @property {string} shopDomain
 * @property {string} accessToken Admin API access token
 * @property {string} [apiVersion]
 * @property {typeof fetch} [fetchImpl]
 * @property {{ debug?: Function, warn?: Function, error?: Function }} [logger]
 */

/**
 * Create a Shopify Admin API client for a single shop.
 *
 * @param {AdminClientConfig} config
 */
export function createAdminClient(config) {
  if (!config?.shopDomain) throw new Error("shopify-sdk: shopDomain required");
  if (!config?.accessToken) throw new Error("shopify-sdk: accessToken required");

  const apiVersion = config.apiVersion || DEFAULT_API_VERSION;
  const fetchImpl = config.fetchImpl || globalThis.fetch;
  const logger = config.logger || {};
  const baseUrl = `https://${config.shopDomain}/admin/api/${apiVersion}/graphql.json`;

  /**
   * Execute a GraphQL query/mutation with retry logic.
   * @template T
   * @param {string} query
   * @param {Record<string, unknown>} [variables]
   * @returns {Promise<T>}
   */
  async function graphql(query, variables = {}) {
    let lastError;

    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      if (attempt > 0) {
        const delay = RETRY_BASE_MS * Math.pow(2, attempt - 1) * (0.5 + Math.random() * 0.5);
        await new Promise(r => setTimeout(r, delay));
      }

      try {
        const res = await fetchImpl(baseUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Shopify-Access-Token": config.accessToken,
          },
          body: JSON.stringify({ query, variables }),
        });

        if (res.status === 429) {
          const retryAfter = parseFloat(res.headers.get("Retry-After") || "2");
          logger.warn?.(`shopify-sdk: 429 rate limited, retry after ${retryAfter}s`);
          await new Promise(r => setTimeout(r, retryAfter * 1000));
          continue;
        }

        if (!res.ok) {
          const text = await res.text().catch(() => "");
          const err = new Error(`shopify-sdk: Admin API ${res.status}: ${text.slice(0, 300)}`);
          err.statusCode = res.status;
          if (RETRYABLE_HTTP.has(res.status) && attempt < MAX_RETRIES) {
            lastError = err;
            continue;
          }
          throw err;
        }

        const payload = await res.json();

        // Log cost for observability
        if (payload.extensions?.cost) {
          const c = payload.extensions.cost;
          logger.debug?.(`shopify-sdk: cost ${c.actualQueryCost}/${c.throttleStatus?.currentlyAvailable}`);
        }

        if (payload.errors?.length) {
          const throttled = payload.errors.some(e => e.extensions?.code === "THROTTLED");
          if (throttled && attempt < MAX_RETRIES) continue;
          throw new Error(`shopify-sdk: GraphQL errors: ${payload.errors.map(e => e.message).join("; ")}`);
        }

        return payload.data;
      } catch (e) {
        lastError = e;
        if (e.statusCode && RETRYABLE_HTTP.has(e.statusCode) && attempt < MAX_RETRIES) continue;
        if (attempt >= MAX_RETRIES) throw e;
      }
    }

    throw lastError || new Error("shopify-sdk: Admin GraphQL failed");
  }

  // -------------------------------------------------------------------------
  // Products
  // -------------------------------------------------------------------------

  async function listProducts({ first = 20, query: q } = {}) {
    const data = await graphql(`
      query($first: Int!, $query: String) {
        products(first: $first, query: $query) {
          edges { node { id title handle status vendor productType tags totalInventory createdAt updatedAt
            featuredImage { url altText }
            variants(first: 5) { edges { node { id title price inventoryQuantity sku } } }
            priceRangeV2 { minVariantPrice { amount currencyCode } maxVariantPrice { amount currencyCode } }
          } }
          pageInfo { hasNextPage endCursor }
        }
      }
    `, { first, query: q });
    return {
      products: data.products.edges.map(e => e.node),
      pageInfo: data.products.pageInfo,
    };
  }

  async function getProduct(id) {
    const data = await graphql(`
      query($id: ID!) {
        product(id: $id) {
          id title handle descriptionHtml status vendor productType tags totalInventory createdAt updatedAt
          seo { title description }
          featuredImage { url altText width height }
          images(first: 20) { edges { node { id url altText width height } } }
          variants(first: 50) { edges { node { id title price compareAtPrice sku barcode inventoryQuantity weight weightUnit selectedOptions { name value } } } }
          metafields(first: 20) { edges { node { id namespace key value type } } }
        }
      }
    `, { id });
    return data.product;
  }

  async function createProduct(input) {
    const data = await graphql(`
      mutation($input: ProductInput!) {
        productCreate(input: $input) {
          product { id title handle status }
          userErrors { field message }
        }
      }
    `, { input });
    if (data.productCreate.userErrors.length) {
      throw new Error(`shopify-sdk: ${data.productCreate.userErrors.map(e => e.message).join("; ")}`);
    }
    return data.productCreate.product;
  }

  async function updateProduct(input) {
    const data = await graphql(`
      mutation($input: ProductInput!) {
        productUpdate(input: $input) {
          product { id title handle status updatedAt }
          userErrors { field message }
        }
      }
    `, { input });
    if (data.productUpdate.userErrors.length) {
      throw new Error(`shopify-sdk: ${data.productUpdate.userErrors.map(e => e.message).join("; ")}`);
    }
    return data.productUpdate.product;
  }

  async function deleteProduct(id) {
    const data = await graphql(`
      mutation($input: ProductDeleteInput!) {
        productDelete(input: $input) {
          deletedProductId
          userErrors { field message }
        }
      }
    `, { input: { id } });
    if (data.productDelete.userErrors.length) {
      throw new Error(`shopify-sdk: ${data.productDelete.userErrors.map(e => e.message).join("; ")}`);
    }
    return data.productDelete.deletedProductId;
  }

  // -------------------------------------------------------------------------
  // Files
  // -------------------------------------------------------------------------

  async function listFiles({ first = 20, query: q } = {}) {
    const data = await graphql(`
      query($first: Int!, $query: String) {
        files(first: $first, query: $query) {
          edges { node {
            ... on MediaImage { id alt image { url width height } createdAt }
            ... on GenericFile { id url mimeType createdAt }
          } }
          pageInfo { hasNextPage endCursor }
        }
      }
    `, { first, query: q });
    return { files: data.files.edges.map(e => e.node), pageInfo: data.files.pageInfo };
  }

  async function uploadFiles(files) {
    const data = await graphql(`
      mutation($files: [FileCreateInput!]!) {
        fileCreate(files: $files) {
          files { ... on MediaImage { id alt image { url } } ... on GenericFile { id url } }
          userErrors { field message }
        }
      }
    `, { files });
    if (data.fileCreate.userErrors.length) {
      throw new Error(`shopify-sdk: ${data.fileCreate.userErrors.map(e => e.message).join("; ")}`);
    }
    return data.fileCreate.files;
  }

  async function deleteFiles(fileIds) {
    const data = await graphql(`
      mutation($fileIds: [ID!]!) {
        fileDelete(fileIds: $fileIds) {
          deletedFileIds
          userErrors { field message }
        }
      }
    `, { fileIds });
    if (data.fileDelete.userErrors.length) {
      throw new Error(`shopify-sdk: ${data.fileDelete.userErrors.map(e => e.message).join("; ")}`);
    }
    return data.fileDelete.deletedFileIds;
  }

  // -------------------------------------------------------------------------
  // Orders
  // -------------------------------------------------------------------------

  async function listOrders({ first = 20, query: q } = {}) {
    const data = await graphql(`
      query($first: Int!, $query: String) {
        orders(first: $first, query: $query) {
          edges { node {
            id name createdAt displayFinancialStatus displayFulfillmentStatus
            totalPriceSet { shopMoney { amount currencyCode } }
            customer { id email firstName lastName }
            lineItems(first: 5) { edges { node { title quantity } } }
          } }
          pageInfo { hasNextPage endCursor }
        }
      }
    `, { first, query: q });
    return { orders: data.orders.edges.map(e => e.node), pageInfo: data.orders.pageInfo };
  }

  async function getOrder(id) {
    const data = await graphql(`
      query($id: ID!) {
        order(id: $id) {
          id name createdAt displayFinancialStatus displayFulfillmentStatus
          totalPriceSet { shopMoney { amount currencyCode } }
          subtotalPriceSet { shopMoney { amount currencyCode } }
          customer { id email firstName lastName phone }
          shippingAddress { address1 address2 city province country zip }
          lineItems(first: 50) { edges { node { title quantity originalUnitPriceSet { shopMoney { amount currencyCode } } variant { id title sku } } } }
          fulfillments { status trackingInfo { number url } }
          note tags
        }
      }
    `, { id });
    return data.order;
  }

  // -------------------------------------------------------------------------
  // Customers
  // -------------------------------------------------------------------------

  async function listCustomers({ first = 20, query: q } = {}) {
    const data = await graphql(`
      query($first: Int!, $query: String) {
        customers(first: $first, query: $query) {
          edges { node { id email firstName lastName phone ordersCount totalSpent createdAt tags state } }
          pageInfo { hasNextPage endCursor }
        }
      }
    `, { first, query: q });
    return { customers: data.customers.edges.map(e => e.node), pageInfo: data.customers.pageInfo };
  }

  // -------------------------------------------------------------------------
  // Themes
  // -------------------------------------------------------------------------

  async function listThemes() {
    const data = await graphql(`
      query { themes(first: 20) { nodes { id name role createdAt updatedAt } } }
    `);
    return data.themes.nodes;
  }

  async function getThemeFiles(themeId, filenames) {
    const data = await graphql(`
      query($themeId: ID!, $filenames: [String!]!) {
        theme(id: $themeId) {
          id name
          files(filenames: $filenames) { nodes { filename size contentType body { ... on OnlineStoreThemeFileBodyText { content } } } }
        }
      }
    `, { themeId, filenames });
    return data.theme;
  }

  // -------------------------------------------------------------------------
  // Metafields
  // -------------------------------------------------------------------------

  async function setMetafields(metafields) {
    const data = await graphql(`
      mutation($metafields: [MetafieldsSetInput!]!) {
        metafieldsSet(metafields: $metafields) {
          metafields { id namespace key value type }
          userErrors { field message }
        }
      }
    `, { metafields });
    if (data.metafieldsSet.userErrors.length) {
      throw new Error(`shopify-sdk: ${data.metafieldsSet.userErrors.map(e => e.message).join("; ")}`);
    }
    return data.metafieldsSet.metafields;
  }

  // -------------------------------------------------------------------------
  // Shop info
  // -------------------------------------------------------------------------

  async function getShopInfo() {
    const data = await graphql(`
      query {
        shop {
          id name email myshopifyDomain
          primaryDomain { url host }
          plan { displayName }
          currencyCode
          billingAddress { country countryCodeV2 province city }
          timezoneAbbreviation ianaTimezone unitSystem weightUnit
        }
      }
    `);
    return data.shop;
  }

  // -------------------------------------------------------------------------
  // Health check
  // -------------------------------------------------------------------------

  async function healthCheck() {
    try {
      const data = await graphql(`query { shop { name } }`);
      return { healthy: true, shop: data.shop.name };
    } catch (e) {
      return { healthy: false, error: e.message };
    }
  }

  return {
    shopDomain: config.shopDomain,
    graphql,
    // Products
    listProducts,
    getProduct,
    createProduct,
    updateProduct,
    deleteProduct,
    // Files
    listFiles,
    uploadFiles,
    deleteFiles,
    // Orders
    listOrders,
    getOrder,
    // Customers
    listCustomers,
    // Themes
    listThemes,
    getThemeFiles,
    // Metafields
    setMetafields,
    // Shop
    getShopInfo,
    // Health
    healthCheck,
  };
}
