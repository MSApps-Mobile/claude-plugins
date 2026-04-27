/**
 * @opsagents/shopify-sdk — Typed contracts for Shopify data.
 *
 * These are the canonical shapes that flow between OpsAgent components:
 * MCP server → SDK client → dashboard/agent. Shopify-specific field names
 * are normalized here so downstream code never touches raw Shopify nodes.
 *
 * Scope B from the Trello epic: StoreSummary, AuditEvent, AgentTaskConfig,
 * McpHealthSnapshot, plus all entity types.
 */

import { z } from "zod";

// ---------------------------------------------------------------------------
// Primitives
// ---------------------------------------------------------------------------

export const MoneySchema = z.object({
  amount: z.string(),
  currencyCode: z.string().length(3),
});

export const ImageSchema = z.object({
  url: z.string().url(),
  altText: z.string().nullable().optional(),
  width: z.number().optional(),
  height: z.number().optional(),
});

// ---------------------------------------------------------------------------
// Products
// ---------------------------------------------------------------------------

export const VariantSchema = z.object({
  id: z.string(),
  title: z.string(),
  price: z.string(),
  compareAtPrice: z.string().nullable().optional(),
  sku: z.string().nullable().optional(),
  barcode: z.string().nullable().optional(),
  inventoryQuantity: z.number().nullable().optional(),
  weight: z.number().nullable().optional(),
  weightUnit: z.string().nullable().optional(),
  selectedOptions: z.array(z.object({ name: z.string(), value: z.string() })).optional(),
});

export const ProductSchema = z.object({
  id: z.string(),
  title: z.string(),
  handle: z.string(),
  descriptionHtml: z.string().optional(),
  status: z.enum(["ACTIVE", "DRAFT", "ARCHIVED"]).optional(),
  vendor: z.string().optional(),
  productType: z.string().optional(),
  tags: z.array(z.string()).optional(),
  totalInventory: z.number().nullable().optional(),
  createdAt: z.string().optional(),
  updatedAt: z.string().optional(),
  featuredImage: ImageSchema.nullable().optional(),
  images: z.array(ImageSchema).optional(),
  variants: z.array(VariantSchema).optional(),
  priceRange: z.object({
    min: MoneySchema,
    max: MoneySchema,
  }).optional(),
  seo: z.object({
    title: z.string().nullable().optional(),
    description: z.string().nullable().optional(),
  }).optional(),
  metafields: z.array(z.object({
    id: z.string(),
    namespace: z.string(),
    key: z.string(),
    value: z.string(),
    type: z.string(),
  })).optional(),
});

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

export const LineItemSchema = z.object({
  title: z.string(),
  quantity: z.number(),
  price: MoneySchema.optional(),
  variant: z.object({
    id: z.string(),
    title: z.string(),
    sku: z.string().nullable().optional(),
  }).nullable().optional(),
});

export const FulfillmentSchema = z.object({
  status: z.string(),
  trackingNumber: z.string().nullable().optional(),
  trackingUrl: z.string().nullable().optional(),
});

export const OrderSchema = z.object({
  id: z.string(),
  name: z.string(),
  createdAt: z.string(),
  financialStatus: z.string(),
  fulfillmentStatus: z.string(),
  total: MoneySchema,
  subtotal: MoneySchema.optional(),
  shipping: MoneySchema.optional(),
  tax: MoneySchema.optional(),
  customer: z.object({
    id: z.string(),
    email: z.string().nullable().optional(),
    firstName: z.string().nullable().optional(),
    lastName: z.string().nullable().optional(),
    phone: z.string().nullable().optional(),
  }).nullable().optional(),
  lineItems: z.array(LineItemSchema).optional(),
  fulfillments: z.array(FulfillmentSchema).optional(),
  note: z.string().nullable().optional(),
  tags: z.array(z.string()).optional(),
});

// ---------------------------------------------------------------------------
// Customers
// ---------------------------------------------------------------------------

export const CustomerSchema = z.object({
  id: z.string(),
  email: z.string().nullable().optional(),
  firstName: z.string().nullable().optional(),
  lastName: z.string().nullable().optional(),
  phone: z.string().nullable().optional(),
  ordersCount: z.number().optional(),
  totalSpent: z.string().optional(),
  createdAt: z.string().optional(),
  tags: z.array(z.string()).optional(),
  state: z.string().optional(),
});

// ---------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------

export const FileSchema = z.object({
  id: z.string(),
  url: z.string().url().optional(),
  alt: z.string().nullable().optional(),
  mimeType: z.string().optional(),
  width: z.number().optional(),
  height: z.number().optional(),
  createdAt: z.string().optional(),
});

// ---------------------------------------------------------------------------
// Themes
// ---------------------------------------------------------------------------

export const ThemeSchema = z.object({
  id: z.string(),
  name: z.string(),
  role: z.string().optional(),
  createdAt: z.string().optional(),
  updatedAt: z.string().optional(),
});

export const ThemeFileSchema = z.object({
  filename: z.string(),
  size: z.number().optional(),
  contentType: z.string().optional(),
  content: z.string().optional(),
});

// ---------------------------------------------------------------------------
// Shop
// ---------------------------------------------------------------------------

export const ShopSchema = z.object({
  id: z.string().optional(),
  name: z.string(),
  email: z.string().optional(),
  myshopifyDomain: z.string(),
  primaryDomain: z.object({ url: z.string(), host: z.string().optional() }).optional(),
  plan: z.string().optional(),
  currencyCode: z.string().optional(),
  timezone: z.string().optional(),
  country: z.string().optional(),
});

// ---------------------------------------------------------------------------
// OpsAgent-specific compound types (from Trello epic Scope B)
// ---------------------------------------------------------------------------

/** Snapshot of a store's key metrics — feeds the dashboard overview card. */
export const StoreSummarySchema = z.object({
  shop: ShopSchema,
  productCount: z.number(),
  orderCount: z.number(),
  customerCount: z.number(),
  revenue30d: MoneySchema.optional(),
  topProducts: z.array(z.object({
    id: z.string(),
    title: z.string(),
    revenue: MoneySchema,
  })).optional(),
  lastSyncAt: z.string(),
});

/** Agent audit event — logged when an AI agent performs a Shopify action. */
export const AuditEventSchema = z.object({
  id: z.string(),
  agentId: z.string(),
  shopDomain: z.string(),
  action: z.string(),
  resourceType: z.string(),
  resourceId: z.string().optional(),
  input: z.unknown().optional(),
  output: z.unknown().optional(),
  impact: z.enum(["read", "low", "medium", "high", "critical"]),
  timestamp: z.string(),
  durationMs: z.number().optional(),
  error: z.string().nullable().optional(),
});

/** Config for an AI task that operates on Shopify data. */
export const AgentTaskConfigSchema = z.object({
  taskId: z.string(),
  name: z.string(),
  description: z.string(),
  shopDomain: z.string(),
  trigger: z.enum(["manual", "schedule", "webhook", "event"]),
  schedule: z.string().optional(),
  webhookTopic: z.string().optional(),
  requiredScopes: z.array(z.string()),
  maxCostPerRun: z.number().optional(),
  enabled: z.boolean(),
});

/** Health snapshot of the MCP connection to a Shopify store. */
export const McpHealthSnapshotSchema = z.object({
  shopDomain: z.string(),
  storefrontMcp: z.object({
    reachable: z.boolean(),
    latencyMs: z.number().optional(),
    lastChecked: z.string(),
    error: z.string().nullable().optional(),
  }),
  adminApi: z.object({
    authenticated: z.boolean(),
    scopes: z.array(z.string()).optional(),
    rateLimitRemaining: z.number().optional(),
    lastChecked: z.string(),
    error: z.string().nullable().optional(),
  }),
  storefrontGraphql: z.object({
    reachable: z.boolean(),
    lastChecked: z.string(),
    error: z.string().nullable().optional(),
  }),
});

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------

export const PageInfoSchema = z.object({
  hasNextPage: z.boolean(),
  endCursor: z.string().nullable().optional(),
});

export const PaginatedResultSchema = (itemSchema) => z.object({
  items: z.array(itemSchema),
  pageInfo: PageInfoSchema,
});
