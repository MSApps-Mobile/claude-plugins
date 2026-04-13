# Kosher AI Plugin

Torah-first bilingual AI assistant for Cowork — powered by OpsAgent's local Ollama runtime. Zero third-party AI APIs. Answers in Hebrew or English automatically.

## What It Does

Routes Torah, halachah, kashrut, and Jewish lifecycle questions through the Kosher AI backend (`kosher-ai.netlify.app`), which runs a local `qwen2.5` model via Ollama on Cloud Run. No Groq, no Gemini, no OpenAI — just the OpsAgent core.

Supports six halachic modes: Torah (general), Yalkut Yosef (Sephardi), Ben Ish Hai (Baghdadi), Chabad, Kashrut, and Minhagim.

## Setup

No API keys required. The backend is publicly accessible.

Optional env var:

```
KOSHER_AI_URL=https://kosher-ai.netlify.app/.netlify/functions/ai-chat
```

## Tools

| Tool | Description |
|------|-------------|
| `kosher_ask` | Ask a Torah/halachah question (English or Hebrew) with optional mode |
| `kosher_modes` | List available modes with descriptions |

## Skills

| Skill | Triggers |
|-------|---------|
| `kosher-torah` | Any Torah, halachah, kashrut, Shabbat, holiday, Jewish calendar, or Hebrew-language religious question |

## Example Usage

```
User: Is gelatin kosher?
→ kosher_ask("Is gelatin kosher?", mode="Kashrut")

User: מה הדין של קטניות לספרדים בפסח?
→ kosher_ask("מה הדין של קטניות לספרדים בפסח?", mode="Yalkut Yosef")

User: What does the Ben Ish Hai say about Havdala?
→ kosher_ask("What does the Ben Ish Hai say about Havdala?", mode="Ben Ish Hai")
```

## Architecture

```
Cowork (Claude) → kosher-ai MCP → Netlify Function → Ollama (qwen2.5) on Cloud Run
```

No third-party AI providers in the chain.

## SOSA Compliance

- **Supervised:** Read-only Q&A — no confirmations required
- **Orchestrated:** Single-step tool call with automatic language detection
- **Secured:** No credentials, no external auth, public endpoint
- **Agents:** Scoped strictly to Torah/halachah domain; declares tool manifest and role boundaries in SKILL.md
