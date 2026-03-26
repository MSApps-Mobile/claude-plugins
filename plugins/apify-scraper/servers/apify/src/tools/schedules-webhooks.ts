import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { apiRequestUnwrap, handleApiError, truncateIfNeeded } from "../services/api-client.js";
import { CHARACTER_LIMIT } from "../constants.js";
import { PaginationSchema } from "../schemas/common.js";
import type { ScheduleSummary, WebhookSummary, ActorTask, ActorRun } from "../types.js";

export function registerScheduleWebhookTools(server: McpServer): void {

  server.registerTool(
    "apify_list_schedules",
    {
      title: "List Schedules",
      description: `List all schedules in your account.\n\nArgs:\n  - limit, offset\n\nReturns: Schedules with cron expressions, next run times, and associated Actors.`,
      inputSchema: PaginationSchema.strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const response = await apiRequestUnwrap<{ total: number; count: number; offset: number; limit: number; items: ScheduleSummary[] }>("schedules", "GET", undefined, { limit: params.limit, offset: params.offset });
        const items = response.items || [];
        if (!items.length) return { content: [{ type: "text", text: "No schedules found." }] };
        const lines = [`# Schedules (${response.total} total)`, ""];
        for (const s of items) {
          lines.push(`## ${s.name || s.id}`, `- **ID**: ${s.id}`, `- **Enabled**: ${s.isEnabled}`, `- **Cron**: \`${s.cronExpression}\` (${s.timezone})`);
          if (s.nextRunAt) lines.push(`- **Next Run**: ${s.nextRunAt}`);
          if (s.lastRunAt) lines.push(`- **Last Run**: ${s.lastRunAt}`);
          if (s.actions?.length) for (const a of s.actions) lines.push(`- **Action**: ${a.type} → ${a.actorId || a.actorTaskId || "N/A"}`);
          lines.push("");
        }
        return { content: [{ type: "text", text: truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT) }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_create_schedule",
    {
      title: "Create Schedule",
      description: `Create a new schedule to run an Actor on a cron schedule.\n\nArgs:\n  - name, cronExpression, timezone, isEnabled, actorId, actorInput\n\nReturns: Created schedule details.`,
      inputSchema: z.object({
        name: z.string().min(1).describe("Schedule name"),
        cronExpression: z.string().min(1).describe("Cron expression (e.g. '0 8 * * *')"),
        timezone: z.string().default("UTC").describe("Timezone (default: UTC)"),
        isEnabled: z.boolean().default(true).describe("Active immediately (default: true)"),
        actorId: z.string().min(1).describe("Actor ID to schedule"),
        actorInput: z.record(z.unknown()).optional().describe("Actor input JSON"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async (params) => {
      try {
        const schedule = await apiRequestUnwrap<ScheduleSummary>("schedules", "POST", {
          name: params.name, cronExpression: params.cronExpression, timezone: params.timezone, isEnabled: params.isEnabled, isExclusive: false,
          actions: [{ type: "RUN_ACTOR", actorId: params.actorId, runInput: params.actorInput ? { contentType: "application/json", body: JSON.stringify(params.actorInput) } : undefined }],
        });
        return { content: [{ type: "text", text: [`# Schedule Created`, "", `- **ID**: ${schedule.id}`, `- **Name**: ${schedule.name}`, `- **Cron**: \`${schedule.cronExpression}\` (${schedule.timezone})`, `- **Enabled**: ${schedule.isEnabled}`, schedule.nextRunAt ? `- **Next Run**: ${schedule.nextRunAt}` : ""].filter(Boolean).join("\n") }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_delete_schedule",
    {
      title: "Delete Schedule",
      description: `Delete a schedule by ID.\n\nArgs:\n  - schedule_id\n\nReturns: Confirmation.`,
      inputSchema: z.object({ schedule_id: z.string().min(1).describe("Schedule ID to delete") }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        await apiRequestUnwrap<void>(`schedules/${params.schedule_id}`, "DELETE");
        return { content: [{ type: "text", text: `Schedule ${params.schedule_id} deleted.` }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_list_webhooks",
    {
      title: "List Webhooks",
      description: `List all webhooks in your account.\n\nArgs:\n  - limit, offset\n\nReturns: Webhooks with event types, URLs, and conditions.`,
      inputSchema: PaginationSchema.strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const response = await apiRequestUnwrap<{ total: number; count: number; offset: number; limit: number; items: WebhookSummary[] }>("webhooks", "GET", undefined, { limit: params.limit, offset: params.offset });
        const items = response.items || [];
        if (!items.length) return { content: [{ type: "text", text: "No webhooks found." }] };
        const lines = [`# Webhooks (${response.total} total)`, ""];
        for (const w of items) {
          lines.push(`## Webhook ${w.id}`, `- **URL**: ${w.requestUrl}`, `- **Events**: ${w.eventTypes.join(", ")}`);
          if (w.condition?.actorId) lines.push(`- **Actor**: ${w.condition.actorId}`);
          if (w.lastDispatch) lines.push(`- **Last dispatch**: ${w.lastDispatch.status} at ${w.lastDispatch.finishedAt}`);
          lines.push("");
        }
        return { content: [{ type: "text", text: truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT) }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_create_webhook",
    {
      title: "Create Webhook",
      description: `Create a webhook for Actor run events.\n\nArgs:\n  - requestUrl, eventTypes[], actorId (optional), actorTaskId (optional), payloadTemplate (optional)\n\nReturns: Created webhook details.`,
      inputSchema: z.object({
        requestUrl: z.string().url().describe("Webhook destination URL"),
        eventTypes: z.array(z.string()).min(1).describe("Event types to listen for"),
        actorId: z.string().optional().describe("Actor ID to watch"),
        actorTaskId: z.string().optional().describe("Task ID to watch"),
        payloadTemplate: z.string().optional().describe("Custom payload template"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async (params) => {
      try {
        const webhook = await apiRequestUnwrap<WebhookSummary>("webhooks", "POST", {
          requestUrl: params.requestUrl, eventTypes: params.eventTypes,
          condition: { ...(params.actorId ? { actorId: params.actorId } : {}), ...(params.actorTaskId ? { actorTaskId: params.actorTaskId } : {}) },
          payloadTemplate: params.payloadTemplate,
        });
        return { content: [{ type: "text", text: [`# Webhook Created`, "", `- **ID**: ${webhook.id}`, `- **URL**: ${webhook.requestUrl}`, `- **Events**: ${webhook.eventTypes.join(", ")}`].join("\n") }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_list_tasks",
    {
      title: "List Actor Tasks",
      description: `List saved Actor tasks (pre-configured runs).\n\nArgs:\n  - limit, offset\n\nReturns: Tasks with names, Actors, and configs.`,
      inputSchema: PaginationSchema.strict(),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    },
    async (params) => {
      try {
        const response = await apiRequestUnwrap<{ total: number; count: number; offset: number; limit: number; items: ActorTask[] }>("actor-tasks", "GET", undefined, { limit: params.limit, offset: params.offset });
        const items = response.items || [];
        if (!items.length) return { content: [{ type: "text", text: "No tasks found." }] };
        const lines = [`# Actor Tasks (${response.total} total)`, ""];
        for (const t of items) { lines.push(`## ${t.title || t.name} (${t.id})`, `- **Actor**: ${t.actId}`); if (t.description) lines.push(`- ${t.description.slice(0, 150)}`); lines.push(`- **Modified**: ${t.modifiedAt}`, ""); }
        return { content: [{ type: "text", text: truncateIfNeeded(lines.join("\n"), CHARACTER_LIMIT) }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );

  server.registerTool(
    "apify_run_task",
    {
      title: "Run Actor Task",
      description: `Run a saved Actor task.\n\nArgs:\n  - task_id, input (optional override), waitForFinish (0-300, optional)\n\nReturns: Run details with storage IDs.`,
      inputSchema: z.object({
        task_id: z.string().min(1).describe("Task ID or full name"),
        input: z.record(z.unknown()).optional().describe("Input override (merges with saved)"),
        waitForFinish: z.number().int().min(0).max(300).optional().describe("Seconds to wait"),
      }).strict(),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true },
    },
    async (params) => {
      try {
        const queryParams: Record<string, unknown> = {};
        if (params.waitForFinish) queryParams.waitForFinish = params.waitForFinish;
        const run = await apiRequestUnwrap<ActorRun>(`actor-tasks/${encodeURIComponent(params.task_id)}/runs`, "POST", params.input || {}, queryParams);
        return { content: [{ type: "text", text: [`# Task Run Started`, "", `- **Run ID**: ${run.id}`, `- **Status**: ${run.status}`, `- **Started**: ${run.startedAt}`, `- **Dataset**: ${run.defaultDatasetId}`, `- **KV Store**: ${run.defaultKeyValueStoreId}`].join("\n") }] };
      } catch (error) { return { content: [{ type: "text", text: handleApiError(error) }] }; }
    }
  );
}
