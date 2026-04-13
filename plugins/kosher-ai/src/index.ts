import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const KOSHER_AI_URL =
  process.env.KOSHER_AI_URL ||
  "https://kosher-ai.netlify.app/.netlify/functions/ai-chat";

const MODES = [
  "Torah",
  "Yalkut Yosef",
  "Ben Ish Hai",
  "Chabad",
  "Kashrut",
  "Minhagim",
] as const;

type Mode = (typeof MODES)[number];

async function callKosherAi(
  question: string,
  mode: Mode = "Torah"
): Promise<string> {
  const res = await fetch(KOSHER_AI_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      messages: [{ role: "user", content: question }],
      mode,
    }),
    signal: AbortSignal.timeout(30_000),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Kosher AI returned ${res.status}: ${body.slice(0, 200)}`);
  }

  const text = await res.text();

  // Parse SSE: data: {"delta":"..."}\n\ndata: [DONE]\n\n
  let answer = "";
  for (const line of text.split("\n")) {
    if (!line.startsWith("data: ") || line.includes("[DONE]")) continue;
    try {
      const payload = JSON.parse(line.slice(6));
      if (payload.delta) answer += payload.delta;
      if (payload.error) throw new Error(payload.error);
    } catch {
      // skip malformed lines
    }
  }

  if (!answer.trim()) {
    throw new Error("Kosher AI returned an empty response.");
  }
  return answer.trim();
}

// ── Server ──────────────────────────────────────────────────────────────────

const server = new McpServer({
  name: "kosher-ai",
  version: "1.0.0",
});

server.tool(
  "kosher_ask",
  [
    "Ask Kosher AI a Torah or halachah question in English or Hebrew.",
    "Use this for ANY question about Jewish law, holidays, customs, kashrut,",
    "prayer, Chumash, Gemara, Rambam, or Jewish philosophy.",
    "The AI answers in the same language the question is written in.",
    "Powered by a local Ollama model — no third-party AI APIs.",
  ].join(" "),
  {
    question: z
      .string()
      .min(1)
      .describe("The Torah or halachah question (English or Hebrew)"),
    mode: z
      .enum(MODES)
      .default("Torah")
      .describe(
        "Halachic tradition to answer from: Torah (general), Yalkut Yosef (Sephardi/Rav Ovadia), " +
          "Ben Ish Hai (Baghdadi/Sephardi), Chabad, Kashrut (food laws), Minhagim (customs)"
      ),
  },
  async ({ question, mode }) => {
    try {
      const answer = await callKosherAi(question, mode);
      return {
        content: [
          {
            type: "text",
            text: `**[Kosher AI · ${mode}]**\n\n${answer}`,
          },
        ],
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      return {
        content: [
          {
            type: "text",
            text: [
              `**Kosher AI error:** ${msg}`,
              "",
              "Possible causes: Ollama runtime is warming up (retry in ~10s), or the service is temporarily unavailable.",
              "Endpoint: " + KOSHER_AI_URL,
            ].join("\n"),
          },
        ],
        isError: true,
      };
    }
  }
);

server.tool(
  "kosher_modes",
  "List available Kosher AI halachic modes with descriptions. Use this when the user is unsure which tradition to follow.",
  {},
  async () => ({
    content: [
      {
        type: "text",
        text: [
          "**Kosher AI — Available Modes**",
          "",
          "| Mode | Tradition | Best For |",
          "|------|-----------|----------|",
          "| Torah | General / multi-tradition | Chumash, Gemara, Rambam, hashkafah, kids homework |",
          "| Yalkut Yosef | Sephardi — Rav Ovadia Yosef | Practical Sephardi halachah, Israeli Sephardi practice |",
          "| Ben Ish Hai | Baghdadi / Iraqi Sephardi | Baghdadi minhagim, Iraqi community customs |",
          "| Chabad | Chabad-Lubavitch | Chabad minhagim, Alter Rebbe rulings, Tanya |",
          "| Kashrut | Kashrut focus | Kitchen questions, ingredients, hechsherim, milchig/fleishig |",
          "| Minhagim | Customs & community differences | Comparing traditions, holiday customs, community variations |",
        ].join("\n"),
      },
    ],
  })
);

// ── Start ────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
