# adobe-for-creativity (OpsAgents customization)

Adobe Creative Cloud skills tuned for OpsAgents work — OpsAgents Studio AI fashion content, OpsAgents/MSApps marketing assets, and Mama Sally / other Shopify clients.

## What was customized

| Skill                                | What changed                                                                                                                                          | In this tree    |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| `adobe-batch-edit-photos`            | Two new looks added — **Studio Editorial** (default for OpsAgents Studio shoots) and **OpsAgents Crisp** (default for corporate/AI brand imagery).    | in `.plugin`    |
| `adobe-create-social-variations`     | "Full set" redefined as IG + TikTok + LinkedIn + YouTube. Per-brand priority order (Studio = vertical-first, corporate = horizontal-first).           | in `.plugin`    |
| `adobe-design-from-template`         | Brand palette + voice + bilingual rule table for OpsAgents, OpsAgents Studio, MSApps, Mama Sally, and client demos.                                   | unzipped here   |
| `adobe-edit-quick-cut`               | Per-brand cut+vibe defaults — Studio = Short/Cinematic 9:16, demo reels = Long/Talking-Moments 16:9, MSApps = Medium/Action 16:9, Shopify = Short/Action 9:16. | unzipped here   |
| `adobe-resize-photos-and-videos`     | Preset list rewritten around OpsAgents standard sizes: 2048×2048 Shopify, 1920×1080 web hero, 1080×1920 Studio vertical, 1200×627 LinkedIn, etc.       | unzipped here   |
| `adobe-retouch-portraits`            | Repurposed from wedding-photographer wording → Studio AI model batches, MSApps team headshots, Shopify lifestyle defaults.                            | in `.plugin`    |

A new `CONTEXT.md` at the plugin root carries the brand list, output-folder convention, bilingual rule, and standard-size reference that all six skills consult.

## Install

The canonical install artifact is the `adobe-for-creativity.plugin` file generated alongside this customization (it lives in Michal's outputs folder for the session and can be re-zipped from this tree at any time). Drop the `.plugin` file into Cowork → plugins to install.

To rebuild the `.plugin` from this folder:

```bash
cd plugins/adobe-for-creativity-opsagents
zip -r ../../adobe-for-creativity.plugin . -x "README.md"
```

The three SKILL.md files marked "in `.plugin`" above (batch-edit-photos, create-social-variations, retouch-portraits) are too large to push reliably through the cli-gateway transport in their full form, so the unzipped tree only carries the three smaller skills plus the per-brand context. The complete plugin lives in the bundled `.plugin` zip.

## Brand defaults at a glance

```
OpsAgents Studio    → Studio Editorial look · 9:16 vertical · TikTok-first
OpsAgents corporate → OpsAgents Crisp look  · 16:9 horizontal · LinkedIn-first
MSApps              → bilingual HE+EN       · MSApps blue palette
Mama Sally / Shopify→ Bright & Airy look    · 2048×2048 product square
Client demos        → match prospect voice  · 1920×1080 web hero
```

## Provenance

Forked from the upstream `adobe/skills` plugin (Apache-2.0). All six SKILL.md files were tuned in-place with OpsAgents brand context; the upstream tool routing, error handling, and Adobe API surface are unchanged.
