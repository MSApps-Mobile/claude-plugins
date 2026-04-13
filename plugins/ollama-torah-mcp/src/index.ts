/**
 * ollama-torah-mcp — Generic Torah Q&A MCP server backed by any Ollama instance.
 *
 * Works with any Ollama-compatible endpoint. No vendor lock-in, no third-party
 * AI APIs. Bring your own model and endpoint.
 *
 * Env vars:
 *   OLLAMA_URL     — Base URL of the Ollama server (e.g. http://localhost:11434)
 *   OLLAMA_MODEL   — Model tag to use (default: qwen2.5:0.5b-instruct)
 *   REQUEST_TIMEOUT — Request timeout in ms (default: 30000)
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// ── Config ──────────────────────────────────────────────────────────────────

const OLLAMA_URL = (process.env.OLLAMA_URL || "http://localhost:11434").replace(
  /\/$/,
  ""
);
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || "qwen2.5:0.5b-instruct";
const REQUEST_TIMEOUT = Number(process.env.REQUEST_TIMEOUT) || 30_000;

// ── Halachic modes ──────────────────────────────────────────────────────────

const MODES = [
  "Torah",
  "Yalkut Yosef",
  "Ben Ish Hai",
  "Chabad",
  "Kashrut",
  "Minhagim",
] as const;

type Mode = (typeof MODES)[number];

const MODE_SYSTEM: Record<Mode, string> = {
  Torah:
    "You are a Torah study assistant. Focus on Chumash, Gemara, Rambam, and classical Torah commentary. " +
    "Answer in the same language the user writes (Hebrew or English). " +
    "Keep replies respectful, family-safe, and halachah-conscious. " +
    "For practical halachic rulings, recommend consulting a local rav.",
  "Yalkut Yosef":
    "You are a halachah assistant following Rav Ovadia Yosef's rulings and the Yalkut Yosef. " +
    "Prioritize Sephardi practice. Distinguish lechatchilah and bediavad when relevant. " +
    "Answer in the same language the user writes. Recommend consulting a local rav for practical rulings.",
  "Ben Ish Hai":
    "You are a halachah assistant following the Ben Ish Hai and Baghdadi/Iraqi Sephardi minhagim. " +
    "Note when this differs from later Sephardi practice. " +
    "Answer in the same language the user writes. Recommend consulting a local rav for practical rulings.",
  Chabad:
    "You are a halachah assistant following Chabad-Lubavitch custom and the Alter Rebbe's rulings. " +
    "Separate Chabad minhag from general halachah when relevant. " +
    "Answer in the same language the user writes. Recommend consulting a local rav for practical rulings.",
  Kashrut:
    "You are a kashrut assistant. Focus on kashrut laws, ingredients, hechsherim, " +
    "milchig/fleishig separation, pareve handling, and community differences. " +
    "Answer in the same language the user writes. Recommend consulting a local rav for practical rulings.",
  Minhagim:
    "You are a Jewish customs assistant. Explain which answer follows which tradition, " +
    "compare Yalkut Yosef, Ben Ish Hai, Chabad, and general practice when needed. " +
    "Do not blend customs together. Answer in the same language the user writes.",
};

// ── Ollama client ───────────────────────────────────────────────────────────

interface OllamaMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

interface OllamaChatResponse {
  message?: { content?: string };
  response?: string;
  error?: string;
}

async function ollamaChat(
  messages: OllamaMessage[],
  model?: string
): Promise<string> {
  const url = `${OLLAMA_URL}/api/chat`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: model || OLLAMA_MODEL,
      messages,
      stream: false,
    }),
    signal: AbortSignal.timeout(REQUEST_TIMEOUT),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(
      `Ollama returned HTTP ${res.status}. ` +
        `Check OLLAMA_URL (${OLLAMA_URL}) and OLLAMA_MODEL (${OLLAMA_MODEL}). ` +
        body.slice(0, 200)
    );
  }

  const data: OllamaChatResponse = await res.json();

  if (data.error) {
    throw new Error(`Ollama error: ${data.error}`);
  }

  const text = data.message?.content || data.response || "";
  if (!text.trim()) {
    throw new Error(
      "Ollama returned an empty response. The model may still be loading — retry in a few seconds."
    );
  }
  return text.trim();
}

// ── MCP Server ──────────────────────────────────────────────────────────────

const server = new McpServer({
  name: "ollama-torah-mcp",
  version: "1.0.0",
});

// Tool: torah_ask — primary Q&A
server.tool(
  "torah_ask",
  "Ask a Torah, halachah, or Jewish studies question. Routes to a local Ollama model. " +
    "Supports Hebrew and English. Choose a halachic mode to tailor the tradition.",
  {
    question: z
      .string()
      .min(1)
      .describe("The question in Hebrew or English"),
    mode: z
      .enum(MODES)
      .default("Torah")
      .describe(
        "Halachic tradition: Torah (general), Yalkut Yosef (Sephardi), " +
          "Ben Ish Hai (Baghdadi), Chabad, Kashrut (food laws), Minhagim (customs)"
      ),
    context: z
      .string()
      .optional()
      .describe(
        "Optional prior conversation context to include (e.g. previous Q&A)"
      ),
  },
  async ({ question, mode, context }) => {
    try {
      const messages: OllamaMessage[] = [
        { role: "system", content: MODE_SYSTEM[mode] },
      ];
      if (context) {
        messages.push({ role: "user", content: context });
        messages.push({
          role: "assistant",
          content: "(continuing the conversation)",
        });
      }
      messages.push({ role: "user", content: question });

      const answer = await ollamaChat(messages);
      return {
        content: [
          {
            type: "text" as const,
            text: `**[${mode}]**\n\n${answer}\n\n---\n*For practical halachic decisions, consult your local rav.*`,
          },
        ],
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return {
        content: [
          {
            type: "text" as const,
            text: `**Error:** ${msg}\n\nTroubleshooting:\n- Is Ollama running at \`${OLLAMA_URL}\`?\n- Is the model \`${OLLAMA_MODEL}\` pulled? Run: \`ollama pull ${OLLAMA_MODEL}\`\n- Try increasing REQUEST_TIMEOUT (currently ${REQUEST_TIMEOUT}ms)`,
          },
        ],
        isError: true,
      };
    }
  }
);

// Tool: torah_modes — list available traditions
server.tool(
  "torah_modes",
  "List available halachic modes (traditions) with descriptions. " +
    "Use when the user is unsure which tradition to choose.",
  {},
  async () => ({
    content: [
      {
        type: "text" as const,
        text: [
          "## Available Halachic Modes\n",
          "| Mode | Tradition | Best For |",
          "|------|-----------|----------|",
          "| Torah | General / multi-tradition | Chumash, Gemara, Rambam, hashkafah, study, kids homework |",
          "| Yalkut Yosef | Sephardi (Rav Ovadia Yosef) | Practical Sephardi halachah, Israeli Sephardi practice |",
          "| Ben Ish Hai | Baghdadi / Iraqi Sephardi | Baghdadi minhagim, Iraqi community customs |",
          "| Chabad | Chabad-Lubavitch | Chabad minhagim, Alter Rebbe rulings, Tanya |",
          "| Kashrut | Kashrut focus | Kitchen questions, ingredients, hechsherim, milchig/fleishig |",
          "| Minhagim | Customs & differences | Comparing traditions, holiday customs, community variations |",
        ].join("\n"),
      },
    ],
  })
);

// Tool: torah_health — connectivity check
server.tool(
  "torah_health",
  "Check if the Ollama backend is reachable and the model is loaded. " +
    "Use to diagnose connection issues before asking questions.",
  {},
  async () => {
    try {
      const start = Date.now();
      const res = await fetch(`${OLLAMA_URL}/api/tags`, {
        signal: AbortSignal.timeout(10_000),
      });
      const elapsed = Date.now() - start;

      if (!res.ok) {
        return {
          content: [
            {
              type: "text" as const,
              text: `**Unhealthy** — Ollama returned HTTP ${res.status} (${elapsed}ms)\nURL: ${OLLAMA_URL}`,
            },
          ],
          isError: true,
        };
      }

      const data = await res.json();
      const models = (data.models || []).map(
        (m: { name: string }) => m.name
      );
      const hasModel = models.some(
        (n: string) =>
          n === OLLAMA_MODEL || n.startsWith(OLLAMA_MODEL.split(":")[0])
      );

      return {
        content: [
          {
            type: "text" as const,
            text: [
              `**${hasModel ? "Healthy" : "Warning"}** (${elapsed}ms)`,
              `- URL: \`${OLLAMA_URL}\``,
              `- Target model: \`${OLLAMA_MODEL}\` ${hasModel ? "— loaded" : "— **not found**, run `ollama pull " + OLLAMA_MODEL + "`"}`,
              `- Available models: ${models.length ? models.join(", ") : "(none)"}`,
            ].join("\n"),
          },
        ],
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return {
        content: [
          {
            type: "text" as const,
            text: `**Unreachable** — ${msg}\n\nIs Ollama running? Start with: \`ollama serve\`\nExpected URL: \`${OLLAMA_URL}\``,
          },
        ],
        isError: true,
      };
    }
  }
);

// ── Start ────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
