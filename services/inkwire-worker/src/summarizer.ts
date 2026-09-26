import { Article, Env, RawFeedItem } from "./types";

interface AiArticleOutput {
  title: string;
  bullets: string[];
  body: string;
}

export async function summarizeArticles(
  sectionTitle: string,
  rawItems: RawFeedItem[],
  env: Env
): Promise<Article[]> {
  if (rawItems.length === 0) return [];

  // Attempt LLM summarization if Gemini API key or Cloudflare Workers AI is available
  if (env.GEMINI_API_KEY) {
    try {
      const result = await summarizeWithGemini(sectionTitle, rawItems, env.GEMINI_API_KEY);
      if (result && result.length > 0) return result;
    } catch (err) {
      console.warn("Gemini summarization failed, falling back to Workers AI / heuristic:", err);
    }
  }

  if (env.AI) {
    try {
      const result = await summarizeWithWorkersAi(sectionTitle, rawItems, env.AI);
      if (result && result.length > 0) return result;
    } catch (err) {
      console.warn("Workers AI summarization failed, falling back to heuristic:", err);
    }
  }

  // Graceful fallback: Heuristic summarization without AI
  return fallbackSummarize(rawItems);
}

async function summarizeWithGemini(
  sectionTitle: string,
  items: RawFeedItem[],
  apiKey: string
): Promise<Article[]> {
  const prompt = `You are the Editor-in-Chief of a high-signal e-ink pocket newspaper.
Section: ${sectionTitle}

Summarize these ${items.length} news items into structured format for e-ink reading.
Items to summarize:
${JSON.stringify(items.map(i => ({ title: i.title, summary: i.summary, source: i.source, url: i.url })), null, 2)}

Return ONLY a JSON array with exactly ${items.length} objects:
[
  {
    "title": "Clean, punchy headline",
    "bullets": ["Takeaway 1 (concise)", "Takeaway 2", "Takeaway 3"],
    "body": "1 to 2 clear paragraphs summarizing the event and why it matters."
  }
]
Do NOT include markdown formatting or backticks outside the JSON.`;

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json" }
    })
  });

  if (!res.ok) throw new Error(`Gemini API error ${res.status}: ${await res.text()}`);
  const data = (await res.json()) as any;
  const jsonText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!jsonText) throw new Error("Empty response from Gemini");

  const parsed = JSON.parse(jsonText) as AiArticleOutput[];
  return items.map((raw, idx) => {
    const ai = parsed[idx] || {};
    return {
      title: ai.title || raw.title,
      source: raw.source,
      time: raw.time,
      bullets: (ai.bullets && ai.bullets.length > 0) ? ai.bullets : [raw.summary.slice(0, 100)],
      body: ai.body || raw.summary,
      url: raw.url
    };
  });
}

async function summarizeWithWorkersAi(
  sectionTitle: string,
  items: RawFeedItem[],
  aiBinding: NonNullable<Env["AI"]>
): Promise<Article[]> {
  const prompt = `You are an editor summarizing news for an e-reader.
Section: ${sectionTitle}
Articles:
${items.map((i, idx) => `[${idx + 1}] Title: ${i.title}\nSource: ${i.source}\nSnippet: ${i.summary}`).join("\n\n")}

Provide a JSON array of ${items.length} items with:
[
  {
    "title": "headline",
    "bullets": ["key point 1", "key point 2"],
    "body": "short summary paragraph"
  }
]
Output JSON ONLY.`;

  const response = await aiBinding.run("@cf/meta/llama-3.1-8b-instruct", {
    messages: [
      { role: "system", content: "You are a news summarizer that outputs strictly valid JSON." },
      { role: "user", content: prompt }
    ]
  });

  const responseText = (response as any)?.response || "";
  const match = responseText.match(/\[\s*\{[\s\S]*\}\s*\]/);
  if (!match) throw new Error("Could not parse JSON array from Workers AI");

  const parsed = JSON.parse(match[0]) as AiArticleOutput[];
  return items.map((raw, idx) => {
    const ai = parsed[idx] || {};
    return {
      title: ai.title || raw.title,
      source: raw.source,
      time: raw.time,
      bullets: (ai.bullets && ai.bullets.length > 0) ? ai.bullets : [raw.summary.slice(0, 100)],
      body: ai.body || raw.summary,
      url: raw.url
    };
  });
}

function fallbackSummarize(items: RawFeedItem[]): Article[] {
  return items.map(item => {
    // Generate clean bullets from raw sentences
    const sentences = item.summary
      .split(/(?<=[.!?])\s+/)
      .filter(s => s.length > 15)
      .slice(0, 3);

    const bullets = sentences.length > 0
      ? sentences
      : [item.summary.slice(0, 120)];

    return {
      title: item.title,
      source: item.source,
      time: item.time,
      bullets: bullets,
      body: item.summary.length > 10 ? item.summary : item.title,
      url: item.url
    };
  });
}
