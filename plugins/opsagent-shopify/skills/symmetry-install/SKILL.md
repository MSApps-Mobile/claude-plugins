---
name: symmetry-install
description: >
  Walk a merchant through installing the Symmetry theme — or any paid Theme
  Store theme — on any Shopify store, from Theme Store preview to live
  publish. Trigger on: "install Symmetry", "add Symmetry theme", "install a
  Shopify theme", "switch theme", "try a new theme", "publish a theme",
  "Shopify theme install", "theme store", or any request to change a Shopify
  storefront theme. Also trigger when the user links to
  themes.shopify.com/themes/symmetry or to any Shopify Theme Store listing.
---

# Symmetry theme install — merchant playbook

Use this skill when the user wants Symmetry (a paid Shopify theme by Clean
Canvas) installed on a Shopify store. Works identically for any paid Theme
Store theme — just swap "Symmetry" for the theme name.

## What you are doing

Adding a theme to a Shopify store does NOT replace the live storefront. It
lands as a **Draft theme**, which the merchant can customize and preview at
a secret URL. Only a deliberate "Publish" swap makes it live. The
`shopify_describe_theme` MCP tool (from the `shopify-mcp` skill) can confirm
what's currently published before and after.

Symmetry costs money (one-time license, typically ~$350 USD, per-store).
"Try theme" is free and creates the Draft; "Buy theme" is the licensing step.

## Path A — Merchant self-serve (recommended)

This is the default. The merchant owns the Shopify admin and their own
payment method. Claude's job is to write the steps clearly.

1. **Admin → Online Store → Themes.** If there is no Themes menu, the store
   is not on a plan that permits theme changes — flag that and stop.
2. Scroll to **Theme library** → **Add theme** → **Visit Theme Store**.
3. Search **Symmetry** (or paste the Theme Store URL). Open the listing.
4. Click **Try theme**. Shopify installs it in **Draft themes** for free.
5. Customize Draft → preview with the eye icon → share preview link with
   stakeholders.
6. When ready, in Draft themes click the **...** menu → **Publish**.
7. Shopify prompts for payment. Once paid, the theme becomes the live one
   and the previous theme moves to the Theme library as a backup.

> **Always recommend step 4 (Try theme) before step 7 (Buy/Publish).** A
> Draft install is free and reversible; publishing is an immediate swap.

## Path B — Partner / staff — via Shopify CLI

Use this when Claude has repo access and the merchant wants a version-
controlled theme.

```bash
# One-time: install CLI
npm install -g @shopify/cli @shopify/theme

# Auth against the merchant's store (substitute the client's handle)
shopify login --store <handle>.myshopify.com

# Pull the current live theme as a safety backup (writes to ./backup/)
shopify theme pull --live --path ./backup

# Download Symmetry source (merchant must have purchased it first — CLI cannot
# buy a theme). Get the .zip from Theme Store > My themes, then:
shopify theme push --path ./symmetry --unpublished

# Preview
shopify theme dev --store <handle>.myshopify.com --theme "Symmetry"

# Publish when stakeholders approve
shopify theme publish --theme "Symmetry"
```

Keep the pre-Symmetry backup in git under `themes/pre-symmetry/` so a
rollback is `shopify theme push --path ./themes/pre-symmetry --live`.

## Path C — Claude-in-Chrome automation

Only use this if the user explicitly asks Claude to drive the admin. Chrome
MCP is tier-"read" for the browser itself, but the extension tools can click
inside the admin. Before any click inside Shopify admin:

1. Verify the extension is connected (`chrome-health-check` skill).
2. Navigate to `https://admin.shopify.com/store/<handle>/themes`.
3. Walk the user through Try theme as above, pausing at every destructive
   step (especially Publish) for confirmation.

Do NOT auto-publish. Do NOT enter payment details. Always hand control
back for the buy-theme step.

## Pre-install checklist

Before the merchant clicks anything:

- [ ] Confirm current theme name and version (`shopify_describe_theme`).
- [ ] Confirm Shopify plan supports theme changes (Basic and up do).
- [ ] Confirm staff account has **Themes** permission.
- [ ] Export a backup of the current theme (Admin → Themes → ... → Download).
- [ ] Note any custom Liquid or apps that inject into the current theme —
      these will need to be re-wired in Symmetry.
- [ ] Screenshot the live storefront hero + product page for before/after.

## Post-install checklist

- [ ] Core pages render: home, collection, product, cart, search, 404.
- [ ] Checkout flow completes end to end on a test order.
- [ ] Apps that inject into theme still work (reviews, currency switcher,
      cookie banner, live chat).
- [ ] Analytics pixels present (GA4, Meta, TikTok if used).
- [ ] Mobile viewport tested — Symmetry is responsive but custom sections
      can break.
- [ ] Search indexing: robots.txt and sitemap still valid.

## SOSA notes

- **Supervised** — publishing a theme is a destructive storefront change;
  always confirm with the merchant before Path B's `theme publish` or
  Path A's Publish click.
- **Orchestrated** — follow the Plan/Act/Verify structure: describe current
  theme, install draft, verify preview, publish, verify live.
- **Secured** — never ask the merchant for their Shopify password. All
  operations go through staff accounts or CLI tokens the merchant owns.
