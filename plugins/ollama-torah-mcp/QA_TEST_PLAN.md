# Ollama Torah MCP — QA Test Plan

## Scope

End-to-end testing of the `ollama-torah-mcp` plugin: MCP tools, halachic modes, error handling, bilingual support, and SOSA compliance.

## Environment

- **Ollama:** Local instance (`http://localhost:11434`)
- **Model:** `qwen2.5:0.5b-instruct`
- **MCP Inspector:** `npx @modelcontextprotocol/inspector`
- **Claude Code / Cowork:** Desktop app with plugin installed

---

## Test Cases

### TC-001: Health check — Ollama running
**Priority**: P0
**Type**: Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start Ollama (`ollama serve`) | Server starts on port 11434 |
| 2 | Call `torah_health` | Returns "Healthy", lists model as loaded |
| 3 | Verify response includes URL and model name | URL = localhost:11434, model = qwen2.5:0.5b-instruct |

---

### TC-002: Health check — Ollama NOT running
**Priority**: P0
**Type**: Error handling

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Stop Ollama | Server stopped |
| 2 | Call `torah_health` | Returns "Unreachable" with clear instructions to run `ollama serve` |

---

### TC-003: Health check — model not pulled
**Priority**: P1
**Type**: Error handling

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Set OLLAMA_MODEL to `nonexistent-model:latest` | Env var set |
| 2 | Call `torah_health` | Returns "Warning" with instruction to `ollama pull nonexistent-model:latest` |

---

### TC-004: Basic English question — Torah mode
**Priority**: P0
**Type**: Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call `torah_ask("What is Shabbat?", mode="Torah")` | Returns English answer about Shabbat |
| 2 | Verify response contains `[Torah]` header | Header present |
| 3 | Verify "consult your local rav" footer | Footer present |
| 4 | Verify response is in English | English text |

---

### TC-005: Hebrew question — auto language
**Priority**: P0
**Type**: Functional / i18n

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call `torah_ask("מה זה שבת?", mode="Torah")` | Returns Hebrew answer about Shabbat |
| 2 | Verify response contains Hebrew characters | Hebrew text present |

---

### TC-006: All six modes return distinct answers
**Priority**: P1
**Type**: Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call `torah_ask("What is the blessing after bread?", mode="Torah")` | General answer about Birkat Hamazon |
| 2 | Call same question with mode="Yalkut Yosef" | Sephardi-focused answer |
| 3 | Call same question with mode="Ben Ish Hai" | Baghdadi-focused answer |
| 4 | Call same question with mode="Chabad" | Chabad-focused answer |
| 5 | Call same question with mode="Kashrut" | Kashrut-focused angle |
| 6 | Call same question with mode="Minhagim" | Compares traditions |

**Notes**: Answers should differ meaningfully across modes, not just change a header.

---

### TC-007: torah_modes returns complete table
**Priority**: P1
**Type**: Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call `torah_modes()` | Returns markdown table with all 6 modes |
| 2 | Verify all modes present: Torah, Yalkut Yosef, Ben Ish Hai, Chabad, Kashrut, Minhagim | All 6 listed |

---

### TC-008: Timeout handling
**Priority**: P1
**Type**: Error handling

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Set REQUEST_TIMEOUT=100 (very short) | Env var set |
| 2 | Call `torah_ask("Explain the 39 melachot in detail")` | Returns error with "timeout" message |
| 3 | Verify error includes troubleshooting steps | Shows current timeout value, suggests increasing |

---

### TC-009: Context continuation
**Priority**: P2
**Type**: Functional

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call `torah_ask("What is Havdala?", mode="Torah")` | Gets base answer |
| 2 | Call `torah_ask("What spices are used?", mode="Torah", context="Q: What is Havdala? A: [previous answer]")` | Answer relates to Havdala spices specifically, not generic spice question |

---

### TC-010: Empty / invalid input
**Priority**: P1
**Type**: Validation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Call `torah_ask("", mode="Torah")` | Returns validation error (min 1 char) |
| 2 | Call `torah_ask("test", mode="InvalidMode")` | Returns validation error for invalid enum |

---

### TC-011: SOSA — read-only verification
**Priority**: P0
**Type**: Security / Compliance

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Review all tool implementations | No write operations, no side effects |
| 2 | Call each tool 10 times | No state change on Ollama server |
| 3 | Verify no credentials are logged or transmitted | Clean — only model name and question sent |

---

### TC-012: Custom Ollama URL
**Priority**: P2
**Type**: Configuration

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Set OLLAMA_URL to a remote Ollama instance | Env var set |
| 2 | Call `torah_health` | Connects to remote instance |
| 3 | Call `torah_ask("What is Shabbat?")` | Gets answer from remote model |

---

### TC-013: Skill trigger coverage
**Priority**: P1
**Type**: Integration / Skill

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | In Cowork, say "Is chicken parmesan kosher?" | torah-qa skill triggers, calls `torah_ask` with Kashrut mode |
| 2 | Say "מתי צום גדליה?" | Skill triggers on Hebrew text |
| 3 | Say "How do Chabad and Sephardim differ on Havdala?" | Triggers with Minhagim mode |
| 4 | Say "What's the weather today?" | Skill does NOT trigger (non-Jewish topic) |

---

## Test Data

### Hebrew Test Queries
- `מה זה שבת?`
- `מה הדין של בשר וחלב?`
- `מתי ראש השנה?`
- `איך מברכים על הלחם?`
- `מה ההבדל בין ספרדים לאשכנזים בענייני כשרות?`

### English Test Queries
- "What is Shabbat?"
- "Is gelatin kosher?"
- "When is Yom Kippur?"
- "Explain the mitzvah of tzedakah"
- "What does the Rambam say about repentance?"

### Edge Cases
- Very long question (500+ chars)
- Mixed Hebrew/English in one question
- Question with no Jewish content ("What is Python?")
- Emoji in question
- Question about controversial topics ("Is X community right about Y?")

---

## Pass Criteria

- All P0 tests pass
- At least 90% of P1 tests pass
- No security/SOSA violations in TC-011
- Response time under 10 seconds on `qwen2.5:0.5b-instruct` (CPU)
- Hebrew and English both produce coherent answers
