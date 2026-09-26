# InkWire Cloudflare Worker

A serverless news aggregator and AI synthesis backend for **CrossPoint InkWire**.

It crawls live feeds (Hacker News, Reddit r/chess, r/sbcgaming, BBC RSS, Open-Meteo weather), summarizes them into structured, high-signal briefings, and serves a compact `edition.json` to your CrossPoint e-reader over Wi-Fi in ~50ms.

---

## Features

- **Live Multi-Source Aggregation**:
  - **Tech & AI**: Hacker News top stories + Ars Technica RSS
  - **Chess**: Reddit `/r/chess` hot discussions & tactics
  - **Handheld Gaming**: Reddit `/r/sbcgaming` hardware updates & reviews
  - **Family & Community**: BBC / Education & Local community RSS
  - **Weather**: Live Open-Meteo temperature & condition forecast (no API key needed)
- **Built-in AI Summarization**:
  - **Default**: Runs natively on **Cloudflare Workers AI** using `@cf/meta/llama-3.1-8b-instruct` (10,000 free neurons/day, zero API keys required).
  - **Optional**: Supports **Google Gemini 1.5 Flash** (via `GEMINI_API_KEY`).
  - **Graceful Fallback**: If AI services are unavailable, generates clean bullet points and extracts sentences from raw descriptions so your daily feed never fails.
- **Automated Daily Cron**: Runs every morning at 6:00 AM UTC (customizable in `wrangler.toml`).
- **Instant Testing Endpoint**: Hit `/refresh` at any time to force an immediate re-fetch.

---

## Quick Start

### 1. Test Locally
```bash
cd services/inkwire-worker
npm install
npm run dev
```
Open `http://localhost:8787/today.json` in your browser to inspect the generated live edition!

### 2. Deploy to Cloudflare
Authenticate with your Cloudflare account (if not already logged in):
```bash
npx wrangler login
```

Deploy the worker:
```bash
npx wrangler deploy
```

Wrangler will output your live URL:
```text
Published inkwire-worker (https://inkwire-worker.<your-subdomain>.workers.dev)
```

### 3. (Optional) Configure Gemini API Key
If you prefer Google Gemini 1.5 Flash over Cloudflare Workers AI:
```bash
npx wrangler secret put GEMINI_API_KEY
# Paste your Gemini API key when prompted
```

### 4. (Optional) Configure Weather City
In `wrangler.toml`, adjust:
```toml
[vars]
WEATHER_CITY = "London"
WEATHER_LAT = "51.5074"
WEATHER_LON = "-0.1278"
```

---

## Endpoints

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/` or `/today.json` | `GET` | Returns today's cached `edition.json` payload (with CORS headers). |
| `/refresh` | `GET`/`POST` | Forces an immediate live re-crawl, synthesizes stories, and caches the result. |
| `/status` | `GET` | Health check returning timestamp, active cache, and AI provider status. |

---

## Connecting to CrossPoint Reader

Once your worker is deployed, configure your CrossPoint Reader:
1. In `apps/inkwire/.storage/config.json` (or via the on-screen `[Cfg]` button):
   ```json
   {
     "feedUrl": "https://inkwire-worker.<your-subdomain>.workers.dev/today.json"
   }
   ```
2. In InkWire on your device, tap **Sync Feed** to download your live briefing!
