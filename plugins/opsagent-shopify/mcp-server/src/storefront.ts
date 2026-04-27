/**
 * Shopify Storefront client — thin wrapper around:
 *   (a) Shopify Storefront MCP endpoint (JSON-RPC over HTTP+SSE) at {shop}/api/mcp
 *   (b) Storefront GraphQL at {shop}/api/{version}/graphql.json  (fallback + token-gated calls)
 *
 * Multi-tenant by design: every call accepts a `shop` (the myshopify domain). If omitted,
 * falls back to SHOPIFY_DEFAULT_SHOP from env. No per-shop state is stored in-process.
 */

export interface ShopContext {
  shop: string;                 // e.g. mama-sally.myshopify.com
  storefrontToken?: string;     // Storefront API token (GraphQL only)
  apiVersion?: string;          // default 2025-01
  mcpPath?: string;             // default /api/mcp
}

export class StorefrontError extends Error {
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
    this.name = "StorefrontError";
  }
}

function resolveContext(partial: Partial<ShopContext>): ShopContext {
  const shop = partial.shop || process.env.SHOPIFY_DEFAULT_SHOP;
  if (!shop) {
    throw new StorefrontError(
      "No shop configured. Pass `shop` argument or set SHOPIFY_DEFAULT_SHOP env var. " +
      "Format: <handle>.myshopify.com"
    );
  }
  if (!/^[a-z0-9-]+\.myshopify\.com$/i.test(shop)) {
    throw new StorefrontError(
      `Invalid shop domain "${shop}". Expected format: <handle>.myshopify.com`
    );
  }
  return {
    shop,
    storefrontToken: partial.storefrontToken || process.env.SHOPIFY_STOREFRONT_TOKEN,
    apiVersion: partial.apiVersion || process.env.SHOPIFY_API_VERSION || "2025-01",
    mcpPath: partial.mcpPath || process.env.SHOPIFY_MCP_PATH || "/api/mcp",
  };
}

/**
 * Call the shop's Storefront MCP endpoint via JSON-RPC. No token required — the MCP
 * endpoint is public. Good for catalog search, cart, policies.
 */
export async function callStorefrontMcp(
  method: string,
  params: Record<string, unknown>,
  ctx: Partial<ShopContext> = {}
): Promise<unknown> {
  const { shop, mcpPath } = resolveContext(ctx);
  const url = `https://${shop}${mcpPath}`;
  const body = {
    jsonrpc: "2.0",
    id: cryptoRandomId(),
    method: "tools/call",
    params: { name: method, arguments: params },
  };
  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json" },
      body: JSON.stringify(body),
    });
  } catch (e) {
    throw new StorefrontError(`Network error calling ${url}: ${(e as Error).message}`, e);
  }
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new StorefrontError(
      `Storefront MCP returned ${res.status} ${res.statusText}. ` +
      `URL: ${url}. Body: ${text.slice(0, 500)}`
    );
  }
  const payload = (await res.json()) as { result?: unknown; error?: { message: string } };
  if (payload.error) {
    throw new StorefrontError(`Storefront MCP error: ${payload.error.message}`);
  }
  return payload.result;
}

/**
 * Call Storefront GraphQL directly. Requires a Storefront token. Use when the MCP
 * endpoint doesn't expose what you need, or for post-purchase / account operations.
 */
export async function storefrontGraphQL<T = unknown>(
  query: string,
  variables: Record<string, unknown> = {},
  ctx: Partial<ShopContext> = {}
): Promise<T> {
  const { shop, storefrontToken, apiVersion } = resolveContext(ctx);
  if (!storefrontToken) {
    throw new StorefrontError(
      "Storefront GraphQL requires a token. Set SHOPIFY_STOREFRONT_TOKEN or pass `storefrontToken`. " +
      "Get one from Admin → Sales channels → Headless → Storefront API access token."
    );
  }
  const url = `https://${shop}/api/${apiVersion}/graphql.json`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "X-Shopify-Storefront-Access-Token": storefrontToken,
    },
    body: JSON.stringify({ query, variables }),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new StorefrontError(
      `Storefront GraphQL ${res.status}: ${text.slice(0, 500)}`
    );
  }
  const payload = (await res.json()) as { data?: T; errors?: Array<{ message: string }> };
  if (payload.errors?.length) {
    throw new StorefrontError(
      `GraphQL errors: ${payload.errors.map(e => e.message).join("; ")}`
    );
  }
  return payload.data as T;
}

function cryptoRandomId(): string {
  // Small, dependency-free id. Good enough for JSON-RPC request ids.
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}
