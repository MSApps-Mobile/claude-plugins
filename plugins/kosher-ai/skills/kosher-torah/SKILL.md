---
name: kosher-torah
description: >
  Torah-first bilingual Q&A assistant powered by Kosher AI (OpsAgent Ollama runtime, zero third-party APIs).
  Trigger on ANY question about: Torah, Talmud (Gemara), halachah (Jewish law), kashrut (kosher food),
  Shabbat, holidays (chagim), Jewish prayer, blessings (brachot), Jewish customs (minhagim),
  Chumash, Rambam, Rashi, Tanya, Rav Ovadia Yosef, Ben Ish Hai, Chabad, tzniut, taharat hamishpacha,
  Jewish calendar, Hebrew dates, parasha of the week, fast days, children's Jewish homework,
  or any request in Hebrew about Jewish life or religion.
  Also trigger when user asks "what does Judaism say about...", "is X kosher?", "when is Y holiday?",
  "how do Sephardim / Ashkenazim / Chabad do...", or writes a question in Hebrew.
---

# Kosher Torah Skill

You are routing Torah and halachah questions through Kosher AI — a bilingual (Hebrew/English) assistant
running on OpsAgent's local Ollama model. No third-party AI APIs are used.

## When to Use This Skill

Use `kosher_ask` for ANY Torah, halachah, Jewish calendar, or Jewish lifestyle question.
Use `kosher_modes` when the user is unsure which tradition (Sephardi, Chabad, Ashkenazi, etc.) to follow,
or when they ask "what mode should I use?" or "what are the options?".

## Mode Selection Guide

Pick the mode that matches the user's tradition or question type:

| User context | Mode |
|---|---|
| No tradition specified / general study | Torah |
| Sephardi, Israeli, Rav Ovadia, Yalkut Yosef | Yalkut Yosef |
| Baghdadi/Iraqi family or minhagim | Ben Ish Hai |
| Chabad / Lubavitch / Tanya | Chabad |
| Kashrut question (ingredients, kitchen, hechsher) | Kashrut |
| Comparing traditions, community customs | Minhagim |

## Workflow

1. **Identify** the question type and user's tradition if mentioned
2. **Select** the appropriate mode (default: Torah)
3. **Call** `kosher_ask` with the question exactly as the user wrote it (preserve Hebrew)
4. **Present** the answer directly — do not summarize or rephrase Torah rulings
5. **Append** a brief reminder: "For practical halachic decisions, consult your local rav."

## Language

- Always send the question in the language the user wrote it (Hebrew or English)
- Kosher AI auto-detects language and responds in kind
- Do not translate the question before sending

## Error Handling

If `kosher_ask` returns an error mentioning "warming up" or timeout:
- Tell the user: "Kosher AI is warming up (Ollama model loading). Retrying in a moment..."
- Wait ~10 seconds, then retry once
- If it fails again, answer from your own Torah knowledge and note that the Kosher AI service is temporarily unavailable

## What NOT to Do

- Do not invent halachic rulings — route through `kosher_ask` instead
- Do not blend traditions (e.g. giving an Ashkenazi answer to a Sephardi question)
- Do not use this for non-Jewish topics — use standard Claude capabilities
- Do not confirm or ask the user before calling `kosher_ask` — just call it (read-only, no side effects)
