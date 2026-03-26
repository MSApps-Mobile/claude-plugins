import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { apiRequestUnwrap, handleApiError, truncateIfNeeded } from "../services/api-client.js";
import { CHARACTER_LIMIT } from "../constants.js";
import { PaginationSchema, ActorIdSchema, JsonInputSchema, RunOptionsSchema } from "../schemas/common.js";
import type { ActorSummary, ActorDetail, ActorRun, ActorBuild, ApifyListResponse } from "../types.js";

export function registerActorTools(server: McpServer): void {

  server.registerTool(
    "apify_list_actors",
    {
      title: "List Actors",
      description: `List Actors in your Apify account.\n\nReturns a paginated list of Actors you've created or used. Use offset/limit for pagination.\n\nArgs:\n  - my (boolean): If true, only return Actors created by you (default: true)\n  - limit (number): Max items to return (default: 20)\n  - offset (number): Items to skip (default: 0)\n\nReturns: List of Actors with id, name, title, description, and stats.`,
      inputSchema: PaginationSchema.extend({
        my: z.boolean().default(true).describe("Only list your own Actors (default: true)"),
      }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const response = await apiRequestUnwrap<{
          total: number; count: number; offset: number; limit: number; items: ActorSummary[];
        }>("acts", "GET", undefined, { limit: params.limit, offset: params.offset, my: params.my ? 1 : 0 });
        const items = response.items || [];
        if (!items.length) return { content: [{ type: "text", text: "No Actors found." }] };
        const lines = [`# Actors (${response.total} total, showing ${items.length})`, ""];
        for (const a of items) {
          lines.push(`## ${a.title || a.name} (${a.id})`);
          if (a.username) lines.push(`- Owner: ${a.username}`);
          if (a.description) lines.push(`- ${a.description.slice(0, 150)}`);
          lines.push(`- Public: ${a.isPublic} | Runs: ${a.stats?.totalRuns ?? "N/A"}`, "");
        }
        if (response.total > response.offset + items.length) lines.push(`_More available. Use offset=${response.offset + items.length} to see next page._`);
        return { content: [{ type: "text", text: truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT) }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_get_actor",
    {
      title: "Get Actor Details",
      description: `Get detailed information about a specific Actor.\n\nArgs:\n  - actor_id (string): Actor ID or username/name (e.g. 'apify/web-scraper')\n\nReturns: Actor details including versions, default run options, input schema, and categories.`,
      inputSchema: z.object({ actor_id: ActorIdSchema }).strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const actor = await apiRequestUnwrap<ActorDetail>(`acts/${encodeURIComponent(params.actor_id)}`);
        const lines = [`# ${actor.title || actor.name}`, "", `- **ID**: ${actor.id}`, `- **Name**: ${actor.username ? `${actor.username}/${actor.name}` : actor.name}`, `- **Public**: ${actor.isPublic}`, `- **Created**: ${actor.createdAt}`, `- **Modified**: ${actor.modifiedAt}`];
        if (actor.description) lines.push("", `**Description**: ${actor.description}`);
        if (actor.defaultRunOptions) {
          const opts = actor.defaultRunOptions;
          lines.push("", "**Default Run Options**:");
          if (opts.build) lines.push(`- Build: ${opts.build}`);
          if (opts.timeoutSecs) lines.push(`- Timeout: ${opts.timeoutSecs}s`);
          if (opts.memoryMbytes) lines.push(`- Memory: ${opts.memoryMbytes} MB`);
        }
        if (actor.versions?.length) { lines.push("", "**Versions**:"); for (const v of actor.versions.slice(0, 10)) lines.push(`- v${v.versionNumber} (tag: ${v.buildTag}, source: ${v.sourceType})`); }
        if (actor.exampleRunInput) { lines.push("", "**Example Input** (content-type: " + actor.exampleRunInput.contentType + "):", "```json", actor.exampleRunInput.body.slice(0, 2000), "```"); }
        if (actor.categories?.length) lines.push("", `**Categories**: ${actor.categories.join(", ")}`);
        return { content: [{ type: "text", text: truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT) }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_run_actor",
    {
      title: "Run Actor",
      description: `Start an Actor run (asynchronous). Returns immediately with run info.\n\nUse waitForFinish to optionally wait up to 300 seconds for the run to complete.\nAfter run finishes, use apify_get_dataset_items with the defaultDatasetId to get results.\n\nArgs:\n  - actor_id (string): Actor ID or full name\n  - input (object): JSON input (optional)\n  - build (string): Build tag (optional)\n  - timeoutSecs (number): Timeout in seconds (optional)\n  - memoryMbytes (number): Memory in MB (optional)\n  - waitForFinish (number): Seconds to wait (0-300, optional)\n\nReturns: Run details including id, status, defaultDatasetId, defaultKeyValueStoreId.`,
      inputSchema: z.object({
        actor_id: ActorIdSchema,
        input: JsonInputSchema,
        build: z.string().optional().describe("Build tag or number (e.g. 'latest')"),
        timeoutSecs: z.number().int().min(0).optional().describe("Timeout in seconds"),
        memoryMbytes: z.number().int().min(128).optional().describe("Memory in MB (min 128)"),
        waitForFinish: z.number().int().min(0).max(300).optional().describe("Seconds to wait for finish (0-300)"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async (params) => {
      try {
        const queryParams: Record<string, unknown> = {};
        if (params.build) queryParams.build = params.build;
        if (params.timeoutSecs) queryParams.timeout = params.timeoutSecs;
        if (params.memoryMbytes) queryParams.memory = params.memoryMbytes;
        if (params.waitForFinish) queryParams.waitForFinish = params.waitForFinish;
        const run = await apiRequestUnwrap<ActorRun>(`acts/${encodeURIComponent(params.actor_id)}/runs`, "POST", params.input || {}, queryParams);
        const lines = [`# Actor Run Started`, "", `- **Run ID**: ${run.id}`, `- **Status**: ${run.status}`, `- **Actor**: ${run.actId}`, `- **Started**: ${run.startedAt}`];
        if (run.finishedAt) lines.push(`- **Finished**: ${run.finishedAt}`);
        if (run.statusMessage) lines.push(`- **Message**: ${run.statusMessage}`);
        lines.push("", `**Storage IDs** (use these to retrieve results):`, `- Dataset: ${run.defaultDatasetId}`, `- Key-Value Store: ${run.defaultKeyValueStoreId}`, `- Request Queue: ${run.defaultRequestQueueId}`);
        if (run.containerUrl) lines.push(`- Container URL: ${run.containerUrl}`);
        if (run.status === "RUNNING") lines.push("", "_Run is still in progress. Use apify_get_run to check status, or apify_get_dataset_items with the dataset ID above to get results when complete._");
        return { content: [{ type: "text", text: lines.join("\n") }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_run_actor_sync",
    {
      title: "Run Actor Synchronously",
      description: `Run an Actor and wait for it to finish, returning dataset items directly.\n\nTimeout is 300 seconds — for longer runs, use apify_run_actor instead.\n\nArgs:\n  - actor_id (string): Actor ID or full name\n  - input (object): JSON input (optional)\n  - build (string): Build tag (optional)\n  - timeoutSecs (number): Timeout (optional, max ~300)\n  - memoryMbytes (number): Memory in MB (optional)\n\nReturns: Dataset items from the Actor run (JSON).`,
      inputSchema: z.object({
        actor_id: ActorIdSchema,
        input: JsonInputSchema,
        build: z.string().optional().describe("Build tag"),
        timeoutSecs: z.number().int().min(0).optional().describe("Timeout in seconds"),
        memoryMbytes: z.number().int().min(128).optional().describe("Memory in MB"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async (params) => {
      try {
        const queryParams: Record<string, unknown> = {};
        if (params.build) queryParams.build = params.build;
        if (params.timeoutSecs) queryParams.timeout = params.timeoutSecs;
        if (params.memoryMbytes) queryParams.memory = params.memoryMbytes;
        const items = await apiRequestUnwrap<unknown[]>(`acts/${encodeURIComponent(params.actor_id)}/run-sync-get-dataset-items`, "POST", params.input || {}, queryParams);
        const text = truncateIfNeeded(JSON.stringify(items, null, 2), CHARACTER_LIMIT);
        return { content: [{ type: "text", text: `# Results (${Array.isArray(items) ? items.length : "?"} items)\n\n\`\`\`json\n${text}\n\`\`\`` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_build_actor",
    {
      title: "Build Actor",
      description: `Trigger a new build of an Actor.\n\nArgs:\n  - actor_id (string): Actor ID or full name\n  - version (string): Version number to build (e.g. '0.1')\n  - tag (string): Build tag (optional)\n  - waitForFinish (number): Seconds to wait (0-300, optional)\n\nReturns: Build details including status and build number.`,
      inputSchema: z.object({
        actor_id: ActorIdSchema,
        version: z.string().min(1).describe("Version number to build (e.g. '0.1')"),
        tag: z.string().optional().describe("Build tag (e.g. 'latest')"),
        waitForFinish: z.number().int().min(0).max(300).optional().describe("Seconds to wait"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async (params) => {
      try {
        const queryParams: Record<string, unknown> = { version: params.version };
        if (params.tag) queryParams.tag = params.tag;
        if (params.waitForFinish) queryParams.waitForFinish = params.waitForFinish;
        const build = await apiRequestUnwrap<ActorBuild>(`acts/${encodeURIComponent(params.actor_id)}/builds`, "POST", undefined, queryParams);
        return { content: [{ type: "text", text: [`# Actor Build`, "", `- **Build ID**: ${build.id}`, `- **Status**: ${build.status}`, `- **Build Number**: ${build.buildNumber}`, `- **Started**: ${build.startedAt}`, build.finishedAt ? `- **Finished**: ${build.finishedAt}` : ""].filter(Boolean).join("\n") }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );
}
