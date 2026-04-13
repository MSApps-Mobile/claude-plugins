---
name: torah-qa
description: >
  Torah and halachah Q&A using a local Ollama model — zero third-party AI APIs.
  Trigger on ANY question about: Torah, Talmud, Gemara, halachah, Jewish law,
  kashrut, Shabbat, Jewish holidays, Jewish prayer, blessings (brachot),
  Jewish customs, Chumash, Rambam, Rashi, Tanya, Rav Ovadia Yosef,
  Ben Ish Hai, Chabad, taharat hamishpacha, Jewish calendar, Hebrew dates,
  parasha, fast days, or any Hebrew-language question about Jewish life.
  Also trigger on "is X kosher?", "when is Y holiday?",
  "how do Sephardim / Ashkenazim / Chabad do...", or "what does Judaism say about...".
---

# Torah Q&A Skill

Route Torah and halachah questions through `torah_ask` — a local Ollama-backed
assistant. Supports Hebrew and English with six halachic modes.

## Tools

| Tool | When |
|------|------|
| `torah_ask` | Any Torah, halachah, or Jewish lifestyle question |
| `torah_modes` | User is unsure which tradition / mode to use |
| `torah_health` | Diagnose connection issues with the Ollama backend |

## Mode Selection

| User context | Mode |
|---|---|
| No tradition specified / general study | Torah |
| Sephardi, Israeli, Rav Ovadia | Yalkut Yosef |
| Baghdadi / Iraqi family | Ben Ish Hai |
| Chabad / Lubavitch / Tanya | Chabad |
| Kashrut (ingredients, kitchen, hechsher) | Kashrut |
| Comparing traditions | Minhagim |

## Workflow

1. Identify the question type and user's tradition (if mentioned)
2. Select the mode (default: Torah)
3. Call `torah_ask` — preserve the original language (Hebrew or English)
4. Present the answer directly — do not rephrase Torah rulings
5. If the question involves a practical ruling, the tool already appends a "consult your rav" note

## Error Handling

If `torah_ask` errors with a timeout or connection issue:
- Run `torah_health` to diagnose
- If model not loaded, suggest: `ollama pull <model>`
- If server unreachable, suggest: `ollama serve`
- Retry once after ~10 seconds if the error mentions "loading"

## Boundaries

- Only Torah/halachah/Jewish topics — use standard capabilities for other questions
- Do not invent halachic rulings — always route through `torah_ask`
- Do not blend traditions in the same answer
- Read-only — no confirmations needed
