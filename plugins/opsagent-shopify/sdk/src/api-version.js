/**
 * The ONE Shopify API version this SDK ships.
 *
 * Card Q0W9KeDW (sibling of j6K8DZka): `admin-client.js` and `storefront-client.js`
 * each carried their own literal, and both were already past Shopify's 12-month
 * support window. A per-file literal is why this class of defect recurred three times
 * in one package — there was no single place a bump could be applied or a guard could
 * read.
 *
 * Shopify's contract (https://shopify.dev/docs/api/usage/versioning): versions ship
 * quarterly on the 1st of Jan/Apr/Jul/Oct and are supported for 12 months, going
 * unsupported on the 16th of that month one year later at 15:00 UTC.
 *
 * `scripts/shopify-api-version.test.mjs` goes RED once this pin ages out.
 */
export const DEFAULT_SHOPIFY_API_VERSION = "2026-10";
