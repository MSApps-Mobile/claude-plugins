import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { apiRequest, apiRequestUnwrap, handleApiError, truncateIfNeeded } from "../services/api-client.js";
import { CHARACTER_LIMIT } from "../constants.js";
import { PaginationSchema, KvsIdSchema } from "../schemas/common.js";
import type { KeyValueStoreSummary, KeyValueStoreKeys } from "../types.js";

export function registerKeyValueStoreTools(server: McpServer): void {

  server.registerTool(
    "apify_list_key_value_stores",
    {
      title: "List Key-Value Stores",
      description: `List key-value stores in your account.\n\nArgs:\n  - limit, offset, unnamed (boolean)\n\nReturns: List of stores with id, name, and timestamps.`,
      inputSchema: PaginationSchema.extend({ unnamed: z.boolean().default(true).describe("Include unnamed stores") }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const response = await apiRequestUnwrap<{ total: number; count: number; offset: number; limit: number; items: KeyValueStoreSummary[] }>("key-value-stores", "GET", undefined, { limit: params.limit, offset: params.offset, unnamed: params.unnamed ? 1 : 0 });
        const items = response.items || [];
        if (!items.length) return { content: [{ type: "text", text: "No key-value stores found." }] };
        const lines = [`# Key-Value Stores (${response.total} total)`, ""];
        for (const s of items) lines.push(`- **${s.name || "(unnamed)"}** (${s.id}) — modified ${s.modifiedAt}`);
        return { content: [{ type: "text", text: truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT) }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_list_keys",
    {
      title: "List Keys in Store",
      description: `List keys in a key-value store.\n\nArgs:\n  - store_id, limit, exclusiveStartKey (pagination)\n\nReturns: List of keys with sizes and content types.`,
      inputSchema: z.object({
        store_id: KvsIdSchema,
        limit: z.number().int().min(1).max(1000).default(20).describe("Max keys to return"),
        exclusiveStartKey: z.string().optional().describe("Start after this key (pagination)"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const queryParams: Record<string, unknown> = { limit: params.limit };
        if (params.exclusiveStartKey) queryParams.exclusiveStartKey = params.exclusiveStartKey;
        const response = await apiRequestUnwrap<KeyValueStoreKeys>(`key-value-stores/${params.store_id}/keys`, "GET", undefined, queryParams);
        const items = response.items || [];
        if (!items.length) return { content: [{ type: "text", text: "No keys found in this store." }] };
        const lines = [`# Keys (${response.count} returned)`, ""];
        for (const k of items) lines.push(`- \`${k.key}\` — ${k.contentType}, ${(k.size / 1024).toFixed(1)} KB`);
        if (response.isTruncated && response.nextExclusiveStartKey) lines.push("", `_More keys available. Use exclusiveStartKey="${response.nextExclusiveStartKey}"_`);
        return { content: [{ type: "text", text: truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT) }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_get_record",
    {
      title: "Get Record from Store",
      description: `Get a specific record from a key-value store by its key.\n\nCommon keys: "OUTPUT" (Actor's main result), "INPUT" (Actor's input).\n\nArgs:\n  - store_id (string), key (string)\n\nReturns: Record content (JSON or text).`,
      inputSchema: z.object({ store_id: KvsIdSchema, key: z.string().min(1).describe("Record key (e.g. 'OUTPUT', 'INPUT')") }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const record = await apiRequest<unknown>(`key-value-stores/${params.store_id}/records/${encodeURIComponent(params.key)}`, "GET");
        const text = typeof record === "string" ? record : JSON.stringify(record, null, 2);
        return { content: [{ type: "text", text: `# Record: \`${params.key}\`\n\n\`\`\`json\n${truncateIfNeeded(text, CHARACTER_LIMIT)}\n\`\`\`` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_set_record",
    {
      title: "Set Record in Store",
      description: `Create or update a record in a key-value store.\n\nArgs:\n  - store_id, key, value (JSON)\n\nReturns: Confirmation.`,
      inputSchema: z.object({ store_id: KvsIdSchema, key: z.string().min(1).describe("Record key"), value: z.unknown().describe("Value to store (JSON)") }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        await apiRequest(`key-value-stores/${params.store_id}/records/${encodeURIComponent(params.key)}`, "PUT", params.value);
        return { content: [{ type: "text", text: `Record \`${params.key}\` saved to store ${params.store_id}.` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_delete_record",
    {
      title: "Delete Record from Store",
      description: `Delete a record from a key-value store.\n\nArgs:\n  - store_id, key\n\nReturns: Confirmation.`,
      inputSchema: z.object({ store_id: KvsIdSchema, key: z.string().min(1).describe("Record key to delete") }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        await apiRequest(`key-value-stores/${params.store_id}/records/${encodeURIComponent(params.key)}`, "DELETE");
        return { content: [{ type: "text", text: `Record \`${params.key}\` deleted from store ${params.store_id}.` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );
}
