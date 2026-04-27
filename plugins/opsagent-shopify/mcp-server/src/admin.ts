/**
 * Shopify Admin API client — handles Admin GraphQL for write operations:
 * products CRUD, file uploads, orders, customers, themes, metafields.
 *
 * Authentication: requires SHOPIFY_ADMIN_TOKEN (Admin API access token).
 * For custom apps: Admin → Settings → Apps → Develop apps → Admin API access token.
 * For public apps: use OAuth offline token stored per-shop.
 *
 * Rate limiting: Shopify Admin GraphQL uses cost-based throttling.
 * Bucket: 2000 points, restore: 100 points/sec. This client implements
 * exponential backoff on 429s and cost-aware retry.
 */

export interface AdminContext {
  shop: string;            // e.g. u5rtvy-0a.myshopify.com
  adminToken: string;      // Admin API access token
  apiVersion?: string;     // default 2025-04
}

export class AdminError extends Error {
  constructor(
    message: string,
    public readonly statusCode?: number,
    public readonly graphqlErrors?: Array<{ message: string; extensions?: Record<string, unknown> }>,
    public readonly cause?: unknown
  ) {
    super(message);
    this.name = "AdminError";
  }
}

const DEFAULT_API_VERSION = "2025-04";
const MAX_RETRIES = 3;
const RETRY_BASE_MS = 500;

function resolveAdminContext(partial: Partial<AdminContext>): AdminContext {
  const shop = partial.shop || process.env.SHOPIFY_DEFAULT_SHOP;
  if (!shop) {
    throw new AdminError("No shop configured. Pass `shop` argument or set SHOPIFY_DEFAULT_SHOP.");
  }
  const adminToken = partial.adminToken || process.env.SHOPIFY_ADMIN_TOKEN;
  if (!adminToken) {
    throw new AdminError(
      "Admin API requires an access token. Set SHOPIFY_ADMIN_TOKEN env var or pass `adminToken`. " +
      "Get one from Admin → Settings → Apps → Develop apps → Admin API access token."
    );
  }
  return {
    shop,
    adminToken,
    apiVersion: partial.apiVersion || process.env.SHOPIFY_API_VERSION || DEFAULT_API_VERSION,
  };
}

/**
 * Execute a Shopify Admin GraphQL query/mutation with retries and cost-aware backoff.
 */
export async function adminGraphQL<T = unknown>(
  query: string,
  variables: Record<string, unknown> = {},
  ctx: Partial<AdminContext> = {}
): Promise<T> {
  const { shop, adminToken, apiVersion } = resolveAdminContext(ctx);
  const url = `https://${shop}/admin/api/${apiVersion}/graphql.json`;

  let lastError: Error | undefined;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    if (attempt > 0) {
      const delay = RETRY_BASE_MS * Math.pow(2, attempt - 1) * (0.5 + Math.random() * 0.5);
      await new Promise(r => setTimeout(r, delay));
    }

    try {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Shopify-Access-Token": adminToken,
        },
        body: JSON.stringify({ query, variables }),
      });

      if (res.status === 429) {
        const retryAfter = parseFloat(res.headers.get("Retry-After") || "2");
        await new Promise(r => setTimeout(r, retryAfter * 1000));
        continue;
      }

      if (!res.ok) {
        const text = await res.text().catch(() => "");
        throw new AdminError(
          `Admin API ${res.status}: ${text.slice(0, 500)}`,
          res.status
        );
      }

      const payload = await res.json() as {
        data?: T;
        errors?: Array<{ message: string; extensions?: Record<string, unknown> }>;
        extensions?: { cost?: { requestedQueryCost: number; actualQueryCost: number; throttleStatus: { maximumAvailable: number; currentlyAvailable: number; restoreRate: number } } };
      };

      // Log cost for observability
      if (payload.extensions?.cost) {
        const c = payload.extensions.cost;
        console.error(
          `[admin-gql] cost: ${c.actualQueryCost}/${c.throttleStatus.currentlyAvailable} available, restore ${c.throttleStatus.restoreRate}/s`
        );
      }

      if (payload.errors?.length) {
        const throttled = payload.errors.some(e =>
          e.extensions?.code === "THROTTLED"
        );
        if (throttled && attempt < MAX_RETRIES) {
          continue;
        }
        throw new AdminError(
          `Admin GraphQL errors: ${payload.errors.map(e => e.message).join("; ")}`,
          undefined,
          payload.errors
        );
      }

      return payload.data as T;
    } catch (e) {
      if (e instanceof AdminError) {
        lastError = e;
        if (e.statusCode && [500, 502, 503, 504].includes(e.statusCode) && attempt < MAX_RETRIES) {
          continue;
        }
        throw e;
      }
      lastError = e instanceof Error ? e : new Error(String(e));
      if (attempt < MAX_RETRIES) continue;
    }
  }

  throw lastError || new AdminError("Admin GraphQL failed after retries");
}

// ---------------------------------------------------------------------------
// Admin GraphQL Queries & Mutations
// ---------------------------------------------------------------------------

export const ADMIN_QUERIES = {
  // Products
  PRODUCTS_LIST: `
    query Products($first: Int!, $query: String) {
      products(first: $first, query: $query) {
        edges {
          node {
            id
            title
            handle
            status
            vendor
            productType
            tags
            totalInventory
            createdAt
            updatedAt
            featuredImage { url altText }
            variants(first: 5) {
              edges {
                node {
                  id
                  title
                  price
                  inventoryQuantity
                  sku
                }
              }
            }
            priceRangeV2 {
              minVariantPrice { amount currencyCode }
              maxVariantPrice { amount currencyCode }
            }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  `,

  PRODUCT_GET: `
    query Product($id: ID!) {
      product(id: $id) {
        id
        title
        handle
        descriptionHtml
        status
        vendor
        productType
        tags
        totalInventory
        createdAt
        updatedAt
        seo { title description }
        featuredImage { url altText width height }
        images(first: 20) {
          edges { node { id url altText width height } }
        }
        variants(first: 50) {
          edges {
            node {
              id
              title
              price
              compareAtPrice
              sku
              barcode
              inventoryQuantity
              weight
              weightUnit
              selectedOptions { name value }
            }
          }
        }
        metafields(first: 20) {
          edges { node { id namespace key value type } }
        }
      }
    }
  `,

  PRODUCT_CREATE: `
    mutation ProductCreate($input: ProductInput!) {
      productCreate(input: $input) {
        product {
          id
          title
          handle
          status
        }
        userErrors { field message }
      }
    }
  `,

  PRODUCT_UPDATE: `
    mutation ProductUpdate($input: ProductInput!) {
      productUpdate(input: $input) {
        product {
          id
          title
          handle
          status
          updatedAt
        }
        userErrors { field message }
      }
    }
  `,

  PRODUCT_DELETE: `
    mutation ProductDelete($input: ProductDeleteInput!) {
      productDelete(input: $input) {
        deletedProductId
        userErrors { field message }
      }
    }
  `,

  // Files
  FILES_LIST: `
    query Files($first: Int!, $query: String) {
      files(first: $first, query: $query) {
        edges {
          node {
            ... on MediaImage {
              id
              alt
              image { url width height }
              createdAt
            }
            ... on GenericFile {
              id
              url
              mimeType
              createdAt
            }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  `,

  FILE_CREATE: `
    mutation fileCreate($files: [FileCreateInput!]!) {
      fileCreate(files: $files) {
        files {
          ... on MediaImage {
            id
            alt
            image { url }
          }
          ... on GenericFile {
            id
            url
          }
        }
        userErrors { field message }
      }
    }
  `,

  FILE_DELETE: `
    mutation fileDelete($fileIds: [ID!]!) {
      fileDelete(fileIds: $fileIds) {
        deletedFileIds
        userErrors { field message }
      }
    }
  `,

  // Orders
  ORDERS_LIST: `
    query Orders($first: Int!, $query: String) {
      orders(first: $first, query: $query) {
        edges {
          node {
            id
            name
            createdAt
            displayFinancialStatus
            displayFulfillmentStatus
            totalPriceSet { shopMoney { amount currencyCode } }
            customer { id email firstName lastName }
            lineItems(first: 5) {
              edges { node { title quantity } }
            }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  `,

  ORDER_GET: `
    query Order($id: ID!) {
      order(id: $id) {
        id
        name
        createdAt
        displayFinancialStatus
        displayFulfillmentStatus
        totalPriceSet { shopMoney { amount currencyCode } }
        subtotalPriceSet { shopMoney { amount currencyCode } }
        totalShippingPriceSet { shopMoney { amount currencyCode } }
        totalTaxSet { shopMoney { amount currencyCode } }
        customer { id email firstName lastName phone }
        shippingAddress { address1 address2 city province country zip }
        lineItems(first: 50) {
          edges {
            node {
              title
              quantity
              originalUnitPriceSet { shopMoney { amount currencyCode } }
              variant { id title sku }
            }
          }
        }
        fulfillments { status trackingInfo { number url } }
        note
        tags
      }
    }
  `,

  // Customers
  CUSTOMERS_LIST: `
    query Customers($first: Int!, $query: String) {
      customers(first: $first, query: $query) {
        edges {
          node {
            id
            email
            firstName
            lastName
            phone
            ordersCount
            totalSpent
            createdAt
            tags
            state
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  `,

  // Themes
  THEMES_LIST: `
    query Themes {
      themes(first: 20) {
        nodes {
          id
          name
          role
          createdAt
          updatedAt
        }
      }
    }
  `,

  THEME_FILES_LIST: `
    query ThemeFiles($themeId: ID!, $filenames: [String!]!) {
      theme(id: $themeId) {
        id
        name
        files(filenames: $filenames) {
          nodes {
            filename
            size
            contentType
            body {
              ... on OnlineStoreThemeFileBodyText {
                content
              }
            }
          }
        }
      }
    }
  `,

  // Metafields
  METAFIELDS_SET: `
    mutation MetafieldsSet($metafields: [MetafieldsSetInput!]!) {
      metafieldsSet(metafields: $metafields) {
        metafields {
          id
          namespace
          key
          value
          type
        }
        userErrors { field message }
      }
    }
  `,

  // Shop info (Admin version — more detailed than Storefront)
  SHOP_INFO: `
    query ShopInfo {
      shop {
        id
        name
        email
        myshopifyDomain
        primaryDomain { url host }
        plan { displayName }
        currencyCode
        billingAddress { country countryCodeV2 province city }
        timezoneAbbreviation
        ianaTimezone
        unitSystem
        weightUnit
      }
    }
  `,
} as const;

// ---------------------------------------------------------------------------
// Convenience wrappers that return pre-shaped data
// ---------------------------------------------------------------------------

export async function listProducts(
  opts: { first?: number; query?: string } = {},
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{ products: { edges: Array<{ node: unknown }>; pageInfo: unknown } }>(
    ADMIN_QUERIES.PRODUCTS_LIST,
    { first: opts.first ?? 20, query: opts.query },
    ctx
  );
  return {
    products: data.products.edges.map(e => e.node),
    pageInfo: data.products.pageInfo,
  };
}

export async function getProduct(id: string, ctx: Partial<AdminContext> = {}) {
  const data = await adminGraphQL<{ product: unknown }>(
    ADMIN_QUERIES.PRODUCT_GET,
    { id },
    ctx
  );
  return data.product;
}

export async function createProduct(
  input: Record<string, unknown>,
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{
    productCreate: { product: unknown; userErrors: Array<{ field: string[]; message: string }> };
  }>(
    ADMIN_QUERIES.PRODUCT_CREATE,
    { input },
    ctx
  );
  if (data.productCreate.userErrors.length > 0) {
    throw new AdminError(
      `Product create failed: ${data.productCreate.userErrors.map(e => e.message).join("; ")}`
    );
  }
  return data.productCreate.product;
}

export async function updateProduct(
  input: Record<string, unknown>,
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{
    productUpdate: { product: unknown; userErrors: Array<{ field: string[]; message: string }> };
  }>(
    ADMIN_QUERIES.PRODUCT_UPDATE,
    { input },
    ctx
  );
  if (data.productUpdate.userErrors.length > 0) {
    throw new AdminError(
      `Product update failed: ${data.productUpdate.userErrors.map(e => e.message).join("; ")}`
    );
  }
  return data.productUpdate.product;
}

export async function deleteProduct(
  id: string,
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{
    productDelete: { deletedProductId: string; userErrors: Array<{ field: string[]; message: string }> };
  }>(
    ADMIN_QUERIES.PRODUCT_DELETE,
    { input: { id } },
    ctx
  );
  if (data.productDelete.userErrors.length > 0) {
    throw new AdminError(
      `Product delete failed: ${data.productDelete.userErrors.map(e => e.message).join("; ")}`
    );
  }
  return data.productDelete.deletedProductId;
}

export async function listFiles(
  opts: { first?: number; query?: string } = {},
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{ files: { edges: Array<{ node: unknown }>; pageInfo: unknown } }>(
    ADMIN_QUERIES.FILES_LIST,
    { first: opts.first ?? 20, query: opts.query },
    ctx
  );
  return {
    files: data.files.edges.map(e => e.node),
    pageInfo: data.files.pageInfo,
  };
}

export async function createFiles(
  files: Array<{ originalSource: string; alt?: string; contentType?: string }>,
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{
    fileCreate: { files: unknown[]; userErrors: Array<{ field: string[]; message: string }> };
  }>(
    ADMIN_QUERIES.FILE_CREATE,
    { files },
    ctx
  );
  if (data.fileCreate.userErrors.length > 0) {
    throw new AdminError(
      `File create failed: ${data.fileCreate.userErrors.map(e => e.message).join("; ")}`
    );
  }
  return data.fileCreate.files;
}

export async function deleteFiles(
  fileIds: string[],
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{
    fileDelete: { deletedFileIds: string[]; userErrors: Array<{ field: string[]; message: string }> };
  }>(
    ADMIN_QUERIES.FILE_DELETE,
    { fileIds },
    ctx
  );
  if (data.fileDelete.userErrors.length > 0) {
    throw new AdminError(
      `File delete failed: ${data.fileDelete.userErrors.map(e => e.message).join("; ")}`
    );
  }
  return data.fileDelete.deletedFileIds;
}

export async function listOrders(
  opts: { first?: number; query?: string } = {},
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{ orders: { edges: Array<{ node: unknown }>; pageInfo: unknown } }>(
    ADMIN_QUERIES.ORDERS_LIST,
    { first: opts.first ?? 20, query: opts.query },
    ctx
  );
  return {
    orders: data.orders.edges.map(e => e.node),
    pageInfo: data.orders.pageInfo,
  };
}

export async function getOrder(id: string, ctx: Partial<AdminContext> = {}) {
  const data = await adminGraphQL<{ order: unknown }>(
    ADMIN_QUERIES.ORDER_GET,
    { id },
    ctx
  );
  return data.order;
}

export async function listCustomers(
  opts: { first?: number; query?: string } = {},
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{ customers: { edges: Array<{ node: unknown }>; pageInfo: unknown } }>(
    ADMIN_QUERIES.CUSTOMERS_LIST,
    { first: opts.first ?? 20, query: opts.query },
    ctx
  );
  return {
    customers: data.customers.edges.map(e => e.node),
    pageInfo: data.customers.pageInfo,
  };
}

export async function listThemes(ctx: Partial<AdminContext> = {}) {
  const data = await adminGraphQL<{ themes: { nodes: unknown[] } }>(
    ADMIN_QUERIES.THEMES_LIST,
    {},
    ctx
  );
  return data.themes.nodes;
}

export async function getThemeFiles(
  themeId: string,
  filenames: string[],
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{ theme: { id: string; name: string; files: { nodes: unknown[] } } }>(
    ADMIN_QUERIES.THEME_FILES_LIST,
    { themeId, filenames },
    ctx
  );
  return data.theme;
}

export async function setMetafields(
  metafields: Array<{
    ownerId: string;
    namespace: string;
    key: string;
    value: string;
    type: string;
  }>,
  ctx: Partial<AdminContext> = {}
) {
  const data = await adminGraphQL<{
    metafieldsSet: { metafields: unknown[]; userErrors: Array<{ field: string[]; message: string }> };
  }>(
    ADMIN_QUERIES.METAFIELDS_SET,
    { metafields },
    ctx
  );
  if (data.metafieldsSet.userErrors.length > 0) {
    throw new AdminError(
      `Metafields set failed: ${data.metafieldsSet.userErrors.map(e => e.message).join("; ")}`
    );
  }
  return data.metafieldsSet.metafields;
}

export async function getShopInfo(ctx: Partial<AdminContext> = {}) {
  const data = await adminGraphQL<{ shop: unknown }>(
    ADMIN_QUERIES.SHOP_INFO,
    {},
    ctx
  );
  return data.shop;
}
