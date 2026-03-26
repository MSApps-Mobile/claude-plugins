/** Apify API base URL */
export const API_BASE_URL = "https://api.apify.com/v2";

/** Maximum response size in characters to prevent overwhelming LLM context */
export const CHARACTER_LIMIT = 25_000;

/** Default pagination limit */
export const DEFAULT_LIMIT = 20;

/** Maximum pagination limit */
export const MAX_LIMIT = 100;

/** API request timeout in milliseconds */
export const REQUEST_TIMEOUT = 60_000;

/** Sync run timeout in milliseconds (5 minutes) */
export const SYNC_RUN_TIMEOUT = 300_000;
