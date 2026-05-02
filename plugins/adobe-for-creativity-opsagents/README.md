# adobe-for-creativity (OpsAgents customization)

Adobe Creative Cloud skills tuned for OpsAgents work — OpsAgents Studio AI fashion content, OpsAgents/MSApps marketing assets, and Mama Sally / other Shopify clients.

## What was customized

| Skill                                | What changed                                                                                                                                          |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `adobe-batch-edit-photos`            | Two new looks added — **Studio Editorial** (default for OpsAgents Studio shoots) and **OpsAgents Crisp** (default for corporate/AI brand imagery).    |
| `adobe-create-social-variations`     | "Full set" redefined as IG + TikTok + LinkedIn + YouTube. Per-brand priority order (Studio = vertical-first, corporate = horizontal-first).           |
| `adobe-design-from-template`         | Brand palette + voice + bilingual rule table for OpsAgents, OpsAgents Studio, MSApps, Mama Sally, and client demos.                                   |
| `adobe-edit-quick-cut`               | Per-brand cut+vibe defaults — Studio = Short/Cinematic 9:16, demo reels = Long/Talking-Moments 16:9, MSApps = Medium/Action 16:9, Shopify = Short/Action 9:16. |
| `adobe-resize-photos-and-videos`     | Preset list rewritten around OpsAgents standard sizes: 2048×2048 Shopify, 1920×1080 web hero, 1080×1920 Studio vertical, 1200×627 LinkedIn, etc.       |
| `adobe-retouch-portraits`            | Repurposed from wedding-photographer wording → Studio AI model batches, MSApps team headshots, Shopify lifestyle defaults.                            |

A new `CONTEXT.md` at the plugin root carries the brand list, output-folder convention, bilingual rule, and standard-size reference that all six skills consult.

## Install

The canonical install artifact is the [`.plugin`](https://github.com/MichalOpsAgents/claude-plugins/raw/main/plugins/adobe-for-creativity-opsagents/adobe-for-creativity.plugin) file in this folder — drop it into Cowork → plugins to install.

To browse the source skills, look at the `skills/` subfolders here. The unzipped tree omits the upstream Adobe `intake-form.html` asset (use the copy bundled inside the `.plugin` file or pull from upstream Adobe).

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
