import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { apiRequestUnwrap, handleApiError, truncateIfNeeded } from "../services/api-client.js";
import { CHARACTER_LIMIT } from "../constants.js";
import { PaginationSchema, ActorIdSchema, RunIdSchema } from "../schemas/common.js";
import type { ActorRun } from "../types.js";

function formatRun(run: ActorRun): string {
  const lines = [`## Run ${run.id}`, `- **Status**: ${run.status}`, `- **Actor**: ${run.actId}`, `- **Started**: ${run.startedAt}`];
  if (run.finishedAt) lines.push(`- **Finished**: ${run.finishedAt}`);
  if (run.statusMessage) lines.push(`- **Message**: ${run.statusMessage}`);
  if (run.stats?.durationMillis) lines.push(`- **Duration**: ${(run.stats.durationMillis / 1000).toFixed(1)}s`);
  if (run.stats?.computeUnits) lines.push(`- **Compute Units**: ${run.stats.computeUnits.toFixed(4)}`);
  lines.push(`- **Dataset**: ${run.defaultDatasetId}`, `- **KV Store**: ${run.defaultKeyValueStoreId}`, `- **Request Queue**: ${run.defaultRequestQueueId}`);
  return lines.join("\n");
}

export function registerRunTools(server: McpServer): void {

  server.registerTool(
    "apify_list_runs",
    {
      title: "List Actor Runs",
      description: `List runs for a specific Actor.\n\nArgs:\n  - actor_id (string): Actor ID or full name\n  - limit/offset: Pagination\n  - status: Filter by READY, RUNNING, SUCCEEDED, FAILED, TIMED-OUT, ABORTED\n  - desc (boolean): Sort newest first (default: true)\n\nReturns: List of runs with status, timing, and storage IDs.`,
      inputSchema: PaginationSchema.extend({
        actor_id: ActorIdSchema,
        status: z.enum(["READY", "RUNNING", "SUCCEEDED", "FAILED", "TIMED-OUT", "ABORTED"]).optional().describe("Filter by run status"),
        desc: z.boolean().default(true).describe("Sort newest first (default: true)"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const queryParams: Record<string, unknown> = { limit: params.limit, offset: params.offset, desc: params.desc ? 1 : 0 };
        if (params.status) queryParams.status = params.status;
        const response = await apiRequestUnwrap<{ total: number; count: number; offset: number; limit: number; items: ActorRun[] }>(`acts/${encodeURIComponent(params.actor_id)}/runs`, "GET", undefined, queryParams);
        const items = response.items || [];
        if (!items.length) return { content: [{ type: "text", text: "No runs found." }] };
        const lines = [`# Runs for Actor (${response.total} total)`, ""];
        for (const run of items) lines.push(formatRun(run), "");
        if (response.total > response.offset + items.length) lines.push(`_More available. Use offset=${response.offset + items.length}_`);
        return { content: [{ type: "text", text: truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT) }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_get_run",
    {
      title: "Get Run Details",
      description: `Get detailed information about a specific Actor run.\n\nArgs:\n  - actor_id (string): Actor ID or full name\n  - run_id (string): Run ID\n\nReturns: Full run details including status, stats, storage IDs.`,
      inputSchema: z.object({ actor_id: ActorIdSchema, run_id: RunIdSchema }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const run = await apiRequestUnwrap<ActorRun>(`acts/${encodeURIComponent(params.actor_id)}/runs/${params.run_id}`);
        const lines = [`# Run Details`, "", formatRun(run)];
        if (run.stats) {
          lines.push("", "**Resource Usage**:");
          if (run.stats.memMaxBytes) lines.push(`- Peak Memory: ${(run.stats.memMaxBytes / 1024 / 1024).toFixed(0)} MB`);
          if (run.stats.cpuMaxUsage) lines.push(`- Peak CPU: ${(run.stats.cpuMaxUsage * 100).toFixed(1)}%`);
          if (run.stats.netRxBytes) lines.push(`- Network RX: ${(run.stats.netRxBytes / 1024).toFixed(0)} KB`);
          if (run.stats.netTxBytes) lines.push(`- Network TX: ${(run.stats.netTxBytes / 1024).toFixed(0)} KB`);
        }
        return { content: [{ type: "text", text: lines.join("\n") }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_get_last_run",
    {
      title: "Get Last Run",
      description: `Get the most recent run of an Actor.\n\nArgs:\n  - actor_id (string): Actor ID or full name\n  - status (string): Filter by status (optional)\n\nReturns: Last run details.`,
      inputSchema: z.object({
        actor_id: ActorIdSchema,
        status: z.enum(["SUCCEEDED", "FAILED", "TIMED-OUT", "ABORTED"]).optional().describe("Only get last run with this status"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const queryParams: Record<string, unknown> = {};
        if (params.status) queryParams.status = params.status;
        const run = await apiRequestUnwrap<ActorRun>(`acts/${encodeURIComponent(params.actor_id)}/runs/last`, "GET", undefined, queryParams);
        return { content: [{ type: "text", text: `# Last Run\n\n${formatRun(run)}` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_abort_run",
    {
      title: "Abort Run",
      description: `Abort a running Actor execution.\n\nArgs:\n  - actor_id, run_id, gracefully (boolean)\n\nReturns: Updated run status.`,
      inputSchema: z.object({
        actor_id: ActorIdSchema, run_id: RunIdSchema,
        gracefully: z.boolean().default(false).describe("Send SIGINT before SIGKILL (default: false)"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const run = await apiRequestUnwrap<ActorRun>(`acts/${encodeURIComponent(params.actor_id)}/runs/${params.run_id}/abort`, "POST", undefined, { gracefully: params.gracefully ? 1 : 0 });
        return { content: [{ type: "text", text: `Run ${run.id} abort initiated. Status: ${run.status}` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_resurrect_run",
    {
      title: "Resurrect Run",
      description: `Resurrect a finished Actor run to continue from where it stopped.\n\nArgs:\n  - actor_id, run_id, build (optional), timeoutSecs (optional), memoryMbytes (optional)\n\nReturns: Updated run details.`,
      inputSchema: z.object({
        actor_id: ActorIdSchema, run_id: RunIdSchema,
        build: z.string().optional().describe("Build tag to use"),
        timeoutSecs: z.number().int().min(0).optional().describe("New timeout in seconds"),
        memoryMbytes: z.number().int().min(128).optional().describe("New memory in MB"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async (params) => {
      try {
        const queryParams: Record<string, unknown> = {};
        if (params.build) queryParams.build = params.build;
        if (params.timeoutSecs) queryParams.timeout = params.timeoutSecs;
        if (params.memoryMbytes) queryParams.memory = params.memoryMbytes;
        const run = await apiRequestUnwrap<ActorRun>(`acts/${encodeURIComponent(params.actor_id)}/runs/${params.run_id}/resurrect`, "POST", undefined, queryParams);
        return { content: [{ type: "text", text: `# Run Resurrected\n\n${formatRun(run)}` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_get_run_log",
    {
      title: "Get Run Log",
      description: `Get console log output from an Actor run. Useful for debugging.\n\nArgs:\n  - actor_id (string), run_id (string)\n\nReturns: Text log output.`,
      inputSchema: z.object({ actor_id: ActorIdSchema, run_id: RunIdSchema }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const log = await apiRequestUnwrap<string>(`acts/${encodeURIComponent(params.actor_id)}/runs/${params.run_id}/log`);
        const text = truncateIfNeeded(typeof log === "string" ? log : JSON.stringify(log), CHARACTER_LIMIT);
        return { content: [{ type: "text", text: `# Run Log\n\n\`\`\`\n${text}\n\`\`\`` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );
}
