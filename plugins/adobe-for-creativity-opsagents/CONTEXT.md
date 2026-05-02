# OpsAgents context for the Adobe for Creativity plugin

This file is the shared context every Adobe skill in this plugin should
respect. It was tuned for OpsAgents (https://opsagents.agency) and the wider
MSApps group.

## Brands this plugin produces work for

When the user does not name a brand, ask which one — or assume `OpsAgents`
unless the request clearly belongs to one of the others.

| Brand                | Domain                          | What we make for it                                           |
| -------------------- | ------------------------------- | ------------------------------------------------------------- |
| OpsAgents            | opsagents.agency                | AI-agency content: hero imagery, partner blocks, demo assets  |
| OpsAgents Studio     | studio.opsagents.agency         | AI fashion content — model photos and short videos            |
| MSApps               | msapps.mobi                     | Bilingual (HE + EN) website + blog assets, dev studio brand   |
| Mama Sally           | mamasally.com (and other Shopify clients) | Product photography, lifestyle imagery, social posts |
| ILCF MedInfo demos   | ilcf-medinfo*.netlify.app       | Medical-info chatbot demo screenshots, hero stills            |
| Client demo sites    | *-demo.opsagents.agency         | Lead-response demos in Social Jet / Bizone style              |

## Default look — apply unless the user says otherwise

- **Aesthetic**: editorial clean — subtle warmth, clarity over saturation,
  natural skin tones, modern editorial feel. Not overprocessed.
- **OpsAgents Studio fashion**: lean slightly more cinematic — soft contrast,
  warm highlights, deep blacks. Studio is the brand that can carry a stronger
  look.
- **MSApps + OpsAgents corporate**: stay neutral and crisp — these are
  AI/tech brands, the imagery should feel modern and confident, not stylized.
- **Shopify product**: bright, true-to-color, white background unless the
  source is a lifestyle shoot.

## Output folder convention

Save final outputs under the user-selected workspace folder using:

```
<workspace>/<brand>/<YYYY-MM-DD>/<asset-type>/
```

Examples:

```
~/OpsAgents/assets/opsagents-studio/2026-05-03/model-photos/
~/OpsAgents/assets/msapps/2026-05-03/blog-hero/
~/OpsAgents/assets/mama-sally/2026-05-03/products/
```

If no workspace folder is selected, drop outputs into the current Cowork
outputs folder and tell the user to move them.

## Priority social platforms

When generating social variations or sizing assets, default to these in
order of priority:

1. Instagram (feed 1080x1350, story/reel 1080x1920)
2. TikTok (1080x1920)
3. LinkedIn (1200x627 single image, 1080x1080 square, 1080x1920 video)
4. YouTube (1920x1080 thumbnail, 1080x1920 Shorts)

Only generate Facebook / X / Pinterest / Threads variations when the user
explicitly asks.

## Bilingual rule (HE + EN)

- Anything for **MSApps** (msapps.mobi) is bilingual by default — produce
  Hebrew (RTL) and English versions of any text overlay.
- **OpsAgents** and **OpsAgents Studio** are English-first. Add Hebrew only
  if the user asks.
- When laying out RTL Hebrew, mirror text alignment and any directional
  iconography. Do not mirror logos or product photography.

## Standard sizes to remember

| Use                          | Dimensions       |
| ---------------------------- | ---------------- |
| Shopify product (square)     | 2048 x 2048      |
| Shopify product (portrait)   | 1500 x 2000      |
| Web hero (opsagents/msapps)  | 1920 x 1080      |
| Studio vertical model shot   | 1080 x 1920      |
| Studio square model shot     | 1080 x 1080      |
| Blog featured image          | 1600 x 900       |
| LinkedIn share card          | 1200 x 627       |

## Per Michal's standing rules

- Always push code to GitHub after every session.
- Drop a Trello card on at least one round of changes.
- All cloud CLIs (gh, gcloud, firebase, shopify, trello) are available and
  always-on — call them via cli-gateway when needed.
