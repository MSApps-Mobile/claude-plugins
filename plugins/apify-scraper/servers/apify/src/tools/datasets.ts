import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { apiRequest, apiRequestUnwrap, handleApiError, truncateIfNeeded } from "../services/api-client.js";
import { CHARACTER_LIMIT } from "../constants.js";
import { PaginationSchema, DatasetIdSchema } from "../schemas/common.js";
import type { DatasetSummary } from "../types.js";

export function registerDatasetTools(server: McpServer): void {

  server.registerTool(
    "apify_list_datasets",
    {
      title: "List Datasets",
      description: `List datasets in your Apify account.\n\nArgs:\n  - limit (number): Max items (default: 20)\n  - offset (number): Pagination offset (default: 0)\n  - unnamed (boolean): Include unnamed datasets (default: true)\n\nReturns: List of datasets with id, name, itemCount, and timestamps.`,
      inputSchema: PaginationSchema.extend({
        unnamed: z.boolean().default(true).describe("Include unnamed datasets (default: true)"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const response = await apiRequestUnwrap<{
          total: number; count: number; offset: number; limit: number; items: DatasetSummary[];
        }>("datasets", "GET", undefined, { limit: params.limit, offset: params.offset, unnamed: params.unnamed ? 1 : 0 });
        const items = response.items || [];
        if (!items.length) return { content: [{ type: "text", text: "No datasets found." }] };
        const lines = [`# Datasets (${response.total} total)`, ""];
        for (const d of items) lines.push(`- **${d.name || "(unnamed)"}** (${d.id}) — ${d.itemCount} items, modified ${d.modifiedAt}`);
        if (response.total > response.offset + items.length) lines.push("", `_More available. Use offset=${response.offset + items.length}_`);
        return { content: [{ type: "text", text: truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT) }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_get_dataset_items",
    {
      title: "Get Dataset Items",
      description: `Retrieve items from a dataset. This is the main way to get Actor run results.\n\nAfter running an Actor, use the defaultDatasetId from the run response to get results here.\n\nArgs:\n  - dataset_id (string): Dataset ID\n  - limit (number): Max items (default: 20, max: 100)\n  - offset (number): Skip items (default: 0)\n  - fields (string[]): Only include specific fields (optional)\n  - omit (string[]): Exclude specific fields (optional)\n  - desc (boolean): Sort descending (default: false)\n  - clean (boolean): Remove empty items (default: false)\n\nReturns: JSON array of dataset items.`,
      inputSchema: PaginationSchema.extend({
        dataset_id: DatasetIdSchema,
        fields: z.array(z.string()).optional().describe("Only include these fields"),
        omit: z.array(z.string()).optional().describe("Exclude these fields"),
        desc: z.boolean().default(false).describe("Sort descending (default: false)"),
        clean: z.boolean().default(false).describe("Remove empty items (default: false)"),
        flatten: z.array(z.string()).optional().describe("Flatten nested fields"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const queryParams: Record<string, unknown> = { limit: params.limit, offset: params.offset, desc: params.desc ? 1 : 0, clean: params.clean ? 1 : 0 };
        if (params.fields?.length) queryParams.fields = params.fields.join(",");
        if (params.omit?.length) queryParams.omit = params.omit.join(",");
        if (params.flatten?.length) queryParams.flatten = params.flatten.join(",");
        const items = await apiRequest<unknown[]>(`datasets/${params.dataset_id}/items`, "GET", undefined, queryParams);
        if (!Array.isArray(items) || items.length === 0) return { content: [{ type: "text", text: "No items found in this dataset." }] };
        const text = truncateIfNeeded(JSON.stringify(items, null, 2), CHARACTER_LIMIT);
        return { content: [{ type: "text", text: `# Dataset Items (${items.length} returned)\n\n\`\`\`json\n${text}\n\`\`\`` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_push_dataset_items",
    {
      title: "Push Items to Dataset",
      description: `Add items to a dataset.\n\nArgs:\n  - dataset_id (string): Dataset ID\n  - items (array): Array of JSON objects to push\n\nReturns: Confirmation of items pushed.`,
      inputSchema: z.object({
        dataset_id: DatasetIdSchema,
        items: z.array(z.record(z.unknown())).min(1).describe("Array of JSON objects to add"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async (params) => {
      try {
        await apiRequest(`datasets/${params.dataset_id}/items`, "POST", params.items);
        return { content: [{ type: "text", text: `Successfully pushed ${params.items.length} items to dataset ${params.dataset_id}.` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_get_dataset",
    {
      title: "Get Dataset Info",
      description: `Get metadata about a specific dataset.\n\nArgs:\n  - dataset_id (string): Dataset ID\n\nReturns: Dataset metadata including itemCount, name, and timestamps.`,
      inputSchema: z.object({ dataset_id: DatasetIdSchema }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const ds = await apiRequestUnwrap<DatasetSummary>(`datasets/${params.dataset_id}`);
        return { content: [{ type: "text", text: [`# Dataset: ${ds.name || "(unnamed)"}`, "", `- **ID**: ${ds.id}`, `- **Items**: ${ds.itemCount}`, `- **Created**: ${ds.createdAt}`, `- **Modified**: ${ds.modifiedAt}`, `- **Accessed**: ${ds.accessedAt}`].join("\n") }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );
}
