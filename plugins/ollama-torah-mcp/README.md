# Ollama Torah MCP

Torah and halachah Q&A plugin for Claude — powered by any Ollama instance. No third-party AI APIs. Bring your own model and endpoint.

## What It Does

Routes Torah, halachah, kashrut, and Jewish lifecycle questions through a local (or remote) Ollama model. Bilingual Hebrew/English with automatic language detection.

Six halachic modes: Torah (general), Yalkut Yosef (Sephardi), Ben Ish Hai (Baghdadi), Chabad, Kashrut, and Minhagim.

## Setup

1. **Install Ollama** — [ollama.com](https://ollama.com/)
2. **Pull a model** — `ollama pull qwen2.5:0.5b-instruct` (fast) or any model you prefer
3. **Start Ollama** — `ollama serve`
4. **Set env vars** (optional — defaults to localhost):

```bash
export OLLAMA_URL=http://localhost:11434
export OLLAMA_MODEL=qwen2.5:0.5b-instruct
export REQUEST_TIMEOUT=30000
```

Works with any Ollama-compatible endpoint (local, Cloud Run, Docker, etc.).

## Tools

| Tool | Description | Read-only |
|------|-------------|-----------|
| `torah_ask` | Ask a Torah/halachah question with optional mode | Yes |
| `torah_modes` | List available halachic traditions | Yes |
| `torah_health` | Check Ollama connectivity and model availability | Yes |

## Skills

| Skill | Triggers |
|-------|---------|
| `torah-qa` | Torah, halachah, kashrut, Shabbat, holidays, Jewish calendar, Hebrew questions |

## Example Usage

```
User: Is gelatin kosher?
→ torah_ask("Is gelatin kosher?", mode="Kashrut")

User: מה הדין של קטניות בפסח?
→ torah_ask("מה הדין של קטניות בפסח?", mode="Yalkut Yosef")

User: What does the Ben Ish Hai say about Havdala?
→ torah_ask("...", mode="Ben Ish Hai")
```

## Recommended Models

| Model | Size | Speed (CPU) | Quality |
|-------|------|-------------|---------|
| `qwen2.5:0.5b-instruct` | 400MB | Fast (~3s) | Good for basic Q&A |
| `qwen2.5:3b-instruct` | 2GB | Moderate (~15s) | Better reasoning |
| `llama3:8b` | 4.7GB | Slow (~30s+) | Best quality, needs GPU |

## SOSA Compliance

- **Supervised:** All tools are read-only — no side effects, no confirmations needed
- **Orchestrated:** Single-step tool calls with clear mode selection
- **Secured:** No credentials required, no external auth, configurable endpoint
- **Agents:** Scoped to Torah/halachah domain, declares boundaries in SKILL.md
