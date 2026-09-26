import { fetchHackerNews, fetchReddit, fetchRss, fetchWeather } from "./feeds";
import { summarizeArticles } from "./summarizer";
import { EditionPayload, Env, Section } from "./types";

const KV_KEY_EDITION = "inkwire_today_edition";

// Default in-memory cache if KV is not configured
let memoryCache: EditionPayload | null = null;
let memoryCacheTimestamp = 0;

function formatEditionDate(): string {
  const d = new Date();
  const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${days[d.getDay()]}, ${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

function formatSyncedAt(): string {
  const d = new Date();
  const pad = (n: number) => (n < 10 ? `0${n}` : `${n}`);
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

async function buildLiveEdition(env: Env): Promise<EditionPayload> {
  const city = env.WEATHER_CITY || "London";
  const lat = env.WEATHER_LAT || "51.5074";
  const lon = env.WEATHER_LON || "-0.1278";

  console.log("Starting InkWire daily edition build...");

  // 1. Fetch live sources concurrently
  const [hnItems, arsItems, chessReddit, sbcGamingReddit, familyFeed, weatherStr] = await Promise.all([
    fetchHackerNews(3),
    fetchRss("https://feeds.arstechnica.com/arstechnica/index", "Ars Technica", 3),
    fetchReddit("chess", 4),
    fetchReddit("sbcgaming", 4),
    fetchRss("https://feeds.bbci.co.uk/news/education/rss.xml", "Family & Education", 3),
    fetchWeather(lat, lon, city)
  ]);

  // Merge tech feeds
  const techRaw = [...hnItems, ...arsItems].slice(0, 4);

  // 2. Synthesize & summarize each section with AI
  console.log("Summarizing sections with AI...");
  const [techArticles, chessArticles, gamingArticles, familyArticles] = await Promise.all([
    summarizeArticles("Technology & AI", techRaw, env),
    summarizeArticles("Chess & Tactics", chessReddit, env),
    summarizeArticles("Handheld Gaming & Emulation", sbcGamingReddit, env),
    summarizeArticles("Family & Community", familyFeed, env)
  ]);

  const sections: Section[] = [
    {
      id: "tech",
      title: "Tech & AI",
      articles: techArticles
    },
    {
      id: "chess",
      title: "Chess",
      articles: chessArticles
    },
    {
      id: "gaming",
      title: "Handhelds",
      articles: gamingArticles
    },
    {
      id: "family",
      title: "Local & Family",
      articles: familyArticles
    }
  ];

  const payload: EditionPayload = {
    edition: formatEditionDate(),
    syncedAt: formatSyncedAt(),
    weather: weatherStr,
    sections: sections
  };

  console.log(`Edition build complete: ${sections.length} sections, ${sections.reduce((acc, s) => acc + s.articles.length, 0)} total articles.`);
  return payload;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Content-Type": "application/json"
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // Force refresh endpoint: /refresh
    if (url.pathname === "/refresh") {
      try {
        const edition = await buildLiveEdition(env);
        if (env.EDITION_KV) {
          await env.EDITION_KV.put(KV_KEY_EDITION, JSON.stringify(edition));
        }
        memoryCache = edition;
        memoryCacheTimestamp = Date.now();
        return new Response(JSON.stringify(edition, null, 2), { headers: corsHeaders });
      } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message || "Failed to generate edition" }), {
          status: 500,
          headers: corsHeaders
        });
      }
    }

    // Main edition feed endpoint: / or /today.json
    if (url.pathname === "/" || url.pathname === "/today.json" || url.pathname === "/edition.json") {
      // 1. Try reading from KV
      if (env.EDITION_KV) {
        const cached = await env.EDITION_KV.get(KV_KEY_EDITION);
        if (cached) {
          return new Response(cached, { headers: corsHeaders });
        }
      }

      // 2. Try in-memory cache (valid for 1 hour)
      if (memoryCache && Date.now() - memoryCacheTimestamp < 3600 * 1000) {
        return new Response(JSON.stringify(memoryCache, null, 2), { headers: corsHeaders });
      }

      // 3. Generate on-demand if no cache exists
      try {
        const edition = await buildLiveEdition(env);
        if (env.EDITION_KV) {
          ctx.waitUntil(env.EDITION_KV.put(KV_KEY_EDITION, JSON.stringify(edition)));
        }
        memoryCache = edition;
        memoryCacheTimestamp = Date.now();
        return new Response(JSON.stringify(edition, null, 2), { headers: corsHeaders });
      } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message || "Failed to generate edition" }), {
          status: 500,
          headers: corsHeaders
        });
      }
    }

    // Health / Status endpoint: /status
    if (url.pathname === "/status") {
      return new Response(
        JSON.stringify({
          status: "ok",
          time: new Date().toISOString(),
          cached: memoryCache !== null,
          hasKV: !!env.EDITION_KV,
          hasAi: !!env.AI,
          hasGemini: !!env.GEMINI_API_KEY
        }),
        { headers: corsHeaders }
      );
    }

    return new Response(JSON.stringify({ error: "Not Found" }), { status: 404, headers: corsHeaders });
  },

  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    console.log(`Cron triggered at ${new Date().toISOString()}. Building fresh edition...`);
    try {
      const edition = await buildLiveEdition(env);
      if (env.EDITION_KV) {
        await env.EDITION_KV.put(KV_KEY_EDITION, JSON.stringify(edition));
      }
      memoryCache = edition;
      memoryCacheTimestamp = Date.now();
      console.log("Cron build completed and saved to cache.");
    } catch (err) {
      console.error("Cron build failed:", err);
    }
  }
};
