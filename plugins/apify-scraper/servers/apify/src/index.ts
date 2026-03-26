#!/usr/bin/env node
/**
 * Apify MCP Server
 *
 * Full-coverage MCP server for the Apify Web Scraping platform.
 * Provides tools for managing Actors, Runs, Datasets, Key-Value Stores,
 * Request Queues, Schedules, Webhooks, and Tasks.
 *
 * Authentication: Set APIFY_API_TOKEN environment variable.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { registerActorTools } from "./tools/actors.js";
import { registerDatasetTools } from "./tools/datasets.js";
import { registerRunTools } from "./tools/runs.js";
import { registerKeyValueStoreTools } from "./tools/key-value-stores.js";
import { registerScheduleWebhookTools } from "./tools/schedules-webhooks.js";

// Create server
const server = new McpServer({
  name: "apify-mcp-server",
  version: "1.0.0",
});

// Register all tool groups
registerActorTools(server);
registerRunTools(server);
registerDatasetTools(server);
registerKeyValueStoreTools(server);
registerScheduleWebhookTools(server);

// Start server
async function main(): Promise<void> {
  if (!process.env.APIFY_API_TOKEN) {
    console.error(
      "ERROR: APIFY_API_TOKEN environment variable is required.\n" +
      "Get your token from: Apify Console > Settings > Integrations"
    );
    process.exit(1);
  }

  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Apify MCP server running via stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
