import { XMLParser } from "fast-xml-parser";
import { RawFeedItem } from "./types";

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_"
});

function stripHtml(html: string): string {
  if (!html) return "";
  return html
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "")
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim();
}

function timeAgo(dateOrTimestamp: number | string): string {
  const ts = typeof dateOrTimestamp === "number" ? dateOrTimestamp : new Date(dateOrTimestamp).getTime();
  const diffHours = Math.max(1, Math.round((Date.now() - ts) / (1000 * 60 * 60)));
  return `${diffHours}h ago`;
}

export async function fetchHackerNews(limit = 4): Promise<RawFeedItem[]> {
  try {
    const res = await fetch("https://hacker-news.firebaseio.com/v0/topstories.json");
    if (!res.ok) return [];
    const ids = (await res.json()) as number[];
    const topIds = ids.slice(0, limit);

    const items: RawFeedItem[] = [];
    for (const id of topIds) {
      try {
        const itemRes = await fetch(`https://hacker-news.firebaseio.com/v0/item/${id}.json`);
        if (itemRes.ok) {
          const data = (await itemRes.json()) as any;
          if (data && data.title) {
            items.push({
              title: data.title,
              summary: data.text ? stripHtml(data.text) : `${data.score || 0} points • ${data.descendants || 0} comments`,
              url: data.url || `https://news.ycombinator.com/item?id=${id}`,
              source: "Hacker News",
              time: data.time ? timeAgo(data.time * 1000) : "Today"
            });
          }
        }
      } catch (e) {
        // Continue with other items
      }
    }
    return items;
  } catch (err) {
    console.error("Failed to fetch Hacker News:", err);
    return [];
  }
}

export async function fetchReddit(subreddit: string, limit = 4): Promise<RawFeedItem[]> {
  try {
    const url = `https://www.reddit.com/r/${subreddit}/hot.json?limit=${limit}`;
    const res = await fetch(url, {
      headers: {
        "User-Agent": "CrossPoint-InkWire/1.0 (Cloudflare Worker; contact: user@example.com)"
      }
    });
    if (!res.ok) return [];
    const data = (await res.json()) as any;
    const posts = data?.data?.children || [];

    const items: RawFeedItem[] = [];
    for (const p of posts) {
      const post = p.data;
      if (!post || post.stickied) continue;

      items.push({
        title: post.title,
        summary: post.selftext ? stripHtml(post.selftext).slice(0, 300) : `${post.score || 0} upvotes • r/${subreddit}`,
        url: post.url?.startsWith("http") ? post.url : `https://reddit.com${post.permalink}`,
        source: `r/${subreddit}`,
        time: post.created_utc ? timeAgo(post.created_utc * 1000) : "Today"
      });
      if (items.length >= limit) break;
    }
    return items;
  } catch (err) {
    console.error(`Failed to fetch reddit r/${subreddit}:`, err);
    return [];
  }
}

export async function fetchRss(feedUrl: string, sourceName: string, limit = 4): Promise<RawFeedItem[]> {
  try {
    const res = await fetch(feedUrl, {
      headers: {
        "User-Agent": "CrossPoint-InkWire/1.0"
      }
    });
    if (!res.ok) return [];
    const text = await res.text();
    const parsed = xmlParser.parse(text);

    const items: RawFeedItem[] = [];

    // RSS 2.0 (channel.item)
    const channelItems = parsed?.rss?.channel?.item;
    if (channelItems) {
      const arr = Array.isArray(channelItems) ? channelItems : [channelItems];
      for (const item of arr.slice(0, limit)) {
        items.push({
          title: stripHtml(item.title || "Untitled"),
          summary: stripHtml(item.description || item["content:encoded"] || ""),
          url: item.link || "",
          source: sourceName,
          time: item.pubDate ? timeAgo(item.pubDate) : "Today"
        });
      }
      return items;
    }

    // Atom (feed.entry)
    const entries = parsed?.feed?.entry;
    if (entries) {
      const arr = Array.isArray(entries) ? entries : [entries];
      for (const entry of arr.slice(0, limit)) {
        const link = entry.link?.["@_href"] || entry.link || "";
        items.push({
          title: stripHtml(entry.title || "Untitled"),
          summary: stripHtml(entry.summary || entry.content || ""),
          url: typeof link === "string" ? link : "",
          source: sourceName,
          time: entry.updated ? timeAgo(entry.updated) : "Today"
        });
      }
      return items;
    }

    return items;
  } catch (err) {
    console.error(`Failed to fetch RSS from ${feedUrl}:`, err);
    return [];
  }
}

export async function fetchWeather(lat = "51.5074", lon = "-0.1278", city = "London"): Promise<string> {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true`;
    const res = await fetch(url);
    if (!res.ok) return `${city} • Crisp Morning`;
    const data = (await res.json()) as any;
    const cur = data?.current_weather;
    if (!cur) return `${city} • Crisp Morning`;

    const temp = Math.round(cur.temperature);
    const code = cur.weathercode || 0;

    let desc = "Clear";
    if (code === 1 || code === 2) desc = "Partly Cloudy";
    else if (code === 3) desc = "Overcast";
    else if (code >= 51 && code <= 67) desc = "Light Rain";
    else if (code >= 71 && code <= 77) desc = "Snow";
    else if (code >= 80 && code <= 82) desc = "Rain Showers";
    else if (code >= 95) desc = "Thunderstorm";

    return `${city} ${temp}°C • ${desc}`;
  } catch (e) {
    return `${city} • Crisp Morning`;
  }
}
