/**
 * @opsagents/shopify-sdk — Public SDK entry point.
 *
 * Re-exports everything consumers need:
 * - createAdminClient — Admin API client with retry + cost awareness
 * - createStorefrontClient — Storefront MCP + GraphQL client
 * - Type schemas (Zod) for all Shopify entities
 * - MCP tool contracts for discovery and validation
 */

// Clients
export { createAdminClient } from "./admin-client.js";
export { createStorefrontClient } from "./storefront-client.js";

// Type schemas
export {
  MoneySchema,
  ImageSchema,
  VariantSchema,
  ProductSchema,
  LineItemSchema,
  FulfillmentSchema,
  OrderSchema,
  CustomerSchema,
  FileSchema,
  ThemeSchema,
  ThemeFileSchema,
  ShopSchema,
  StoreSummarySchema,
  AuditEventSchema,
  AgentTaskConfigSchema,
  McpHealthSnapshotSchema,
  PageInfoSchema,
  PaginatedResultSchema,
} from "./types.js";

// MCP tool contracts
export {
  STOREFRONT_TOOLS,
  ADMIN_TOOLS,
  ALL_TOOLS,
  getRequiredScopes,
  getToolsByLayer,
} from "./mcp-contracts.js";
