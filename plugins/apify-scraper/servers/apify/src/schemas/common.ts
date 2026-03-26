import { z } from "zod";
import { DEFAULT_LIMIT, MAX_LIMIT } from "../constants.js";

/** Reusable pagination schema */
export const PaginationSchema = z.object({
  limit: z.number()
    .int()
    .min(1)
    .max(MAX_LIMIT)
    .default(DEFAULT_LIMIT)
    .describe("Maximum number of items to return (1-100, default: 20)"),
  offset: z.number()
    .int()
    .min(0)
    .default(0)
    .describe("Number of items to skip for pagination (default: 0)"),
});

/** Actor identifier - can be ID or username/name format */
export const ActorIdSchema = z.string()
  .min(1)
  .describe("Actor ID (e.g. 'abc123') or full name (e.g. 'apify/web-scraper')");

/** Run ID schema */
export const RunIdSchema = z.string()
  .min(1)
  .describe("The unique ID of the Actor run");

/** Dataset ID schema */
export const DatasetIdSchema = z.string()
  .min(1)
  .describe("The unique ID of the dataset");

/** Key-Value Store ID schema */
export const KvsIdSchema = z.string()
  .min(1)
  .describe("The unique ID of the key-value store");

/** Request Queue ID schema */
export const RqIdSchema = z.string()
  .min(1)
  .describe("The unique ID of the request queue");

/** Optional JSON input schema */
export const JsonInputSchema = z.record(z.unknown())
  .optional()
  .describe("JSON input for the Actor (optional). Pass the Actor's expected input fields.");

/** Run options schema */
export const RunOptionsSchema = z.object({
  build: z.string().optional().describe("Build tag or number to run (e.g. 'latest', '0.1.2')"),
  timeoutSecs: z.number().int().min(0).optional().describe("Timeout for the run in seconds"),
  memoryMbytes: z.number().int().min(128).optional().describe("Memory limit in MB (min 128)"),
  waitForFinish: z.number().int().min(0).max(300).optional()
    .describe("Max seconds to wait for run to finish (0 = don't wait, max 300). Returns immediately if run finishes sooner."),
}).strict();
