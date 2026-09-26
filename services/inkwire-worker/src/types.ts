export interface Article {
  title: string;
  source: string;
  time: string;
  bullets: string[];
  body: string;
  url: string;
}

export interface Section {
  id: string;
  title: string;
  articles: Article[];
}

export interface EditionPayload {
  edition: string;
  syncedAt: string;
  weather: string;
  sections: Section[];
}

export interface RawFeedItem {
  title: string;
  summary: string;
  url: string;
  source: string;
  time: string;
}

export interface Env {
  AI?: {
    run: (model: string, options: { messages?: Array<{ role: string; content: string }>; prompt?: string }) => Promise<any>;
  };
  EDITION_KV?: KVNamespace;
  GEMINI_API_KEY?: string;
  WEATHER_CITY?: string;
  WEATHER_LAT?: string;
  WEATHER_LON?: string;
}
