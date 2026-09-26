# InkWire

A personalized daily news digest and curated feed reader for **CrossPoint Reader** (ESP32-S3 / E-Ink).

![Category](https://img.shields.io/badge/Category-News%20%26%20Feeds-blue)
![Orientation](https://img.shields.io/badge/Orientation-Portrait%20(480x800)-green)
![Version](https://img.shields.io/badge/Version-1.0.0-orange)

---

## Overview

**InkWire** transforms your CrossPoint e-reader into a custom, high-signal pocket newspaper:
1. **The "Bespoke Daily Edition"**: Rather than endless scrolling and clickbait feeds, InkWire presents a curated, finite daily issue divided into customizable topic beats (e.g. *Tech & AI*, *Chess*, *Handhelds*, *Local & Family*).
2. **Three-Tier Reading Depth**:
   * **Front Page Glance**: Hero card and headline cards with source badges and 1-line takeaways.
   * **The 1-Minute Brief**: Key Takeaways box with bullet points and synthesized paragraphs in crisp monochrome typography.
   * **QR Code Mobile Handoff**: At the bottom of every story, InkWire renders a native 1-bit QR code. Point your smartphone camera at your CrossPoint screen to instantly open the original full-length article in your mobile browser.
3. **On-Demand Battery-Friendly Sync**: Connects to Wi-Fi on-demand via `crosspoint.withWifi`, downloads your lightweight `edition.json` in ~2 seconds, and immediately shuts down the Wi-Fi radio to preserve battery.
4. **100% Offline Ready**: The current edition is automatically cached in sandboxed flash storage (`storage.writeFile("edition.json")`) for offline reading anywhere.

---

## Screen & Interaction Design

```text
┌──────────────────────────────────────────────┐
│  THE INKWIRE CHRONICLE                       │
│  Saturday, Sep 26, 2026  •  London 18°C ⛅   │
├──────────────────────────────────────────────┤
│ (All) [Tech & AI] [Chess] [Handhelds] [⚙]    │  <- Touch pill navigation
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ [TECH & AI] Ars Technica • 2h ago        │ │
│ │ Open Reasoning Models Reach Frontier     │ │  <- Story Card
│ │ Benchmark Parity                         │ │
│ │ • 67B model matches closed frontier labs │ │
│ │                               Read Brief ›│ │
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ [CHESS] Chess.com • 3h ago               │ │
│ │ Carlsen Sweeps Speed Chess Final in Blitz│ │
│ │ • Magnus edges out Hikaru Nakamura       │ │
│ │                               Read Brief ›│ │
│ └──────────────────────────────────────────┘ │
├──────────────────────────────────────────────┤
│ [◀ Prev]   Page 1 / 4   [Next ▶]  [🔄 Sync] │  <- Large touch targets
└──────────────────────────────────────────────┘
```

---

## Controls

### Touch Input
- **Front Page**:
  - **Section Tabs**: Tap any tab pill (`[All]`, `[Tech & AI]`, `[Chess]`, `[Handhelds]`, etc.) to switch topic beats.
  - **Story Card**: Tap any card to open the **Article Detail View**.
  - **Pagination**: Tap `[◀ Prev]` or `[Next ▶]` to page through stories in the selected section.
  - **Sync**: Tap `[🔄 Sync Feed]` to download the latest edition over Wi-Fi.
  - **Settings**: Tap the `[⚙]` gear icon to view feed URL configuration or reload the sample edition.
- **Article Reader**:
  - **`◀ Back`**: Returns to the Front Page.
  - **`◀ Prev Story` / `Next Story ▶`**: Jump directly between articles without returning to the list.
  - **QR Code**: Scan the on-screen QR code with your phone camera to read the complete article on the web.
- **Modals**:
  - Tap **Done / Continue** to dismiss sync and settings overlays.

### Physical Hardware Buttons
- **`PAGE_BACK` / `LEFT`**: Previous page (on frontpage) or previous article (in reader view).
- **`PAGE_FORWARD` / `RIGHT`**: Next page (on frontpage) or next article (in reader view).
- **`CONFIRM` (Enter / Space)**: Opens the first story on the current page.
- **`BACK` (Escape / Backspace)**:
  - Inside an article: Returns to the Front Page.
  - On the Front Page (in a sub-section): Returns to the **All** section.
  - On the Front Page (at the All section): Exits to the CrossPoint launcher.

---

## Data Contract (`edition.json`)

InkWire is completely decoupled from how your news is generated. The app simply reads a clean JSON payload:

```json
{
  "edition": "Saturday, Sep 26, 2026",
  "syncedAt": "07:30",
  "weather": "London 18°C ⛅ • Crisp Autumn Morning",
  "sections": [
    {
      "id": "tech",
      "title": "Tech & AI",
      "articles": [
        {
          "title": "Open Reasoning Models Reach Frontier Benchmark Parity",
          "source": "Ars Technica",
          "time": "2h ago",
          "bullets": [
            "Open-weights 67B model matches closed frontier labs on math and coding.",
            "Sparse attention architecture reduces required VRAM by 45%."
          ],
          "body": "Open-source artificial intelligence reached a new milestone today as researchers published weights...",
          "url": "https://arstechnica.com"
        }
      ]
    }
  ]
}
```

---

## Deployment & Feed Backend Options

To populate your own custom feed:

### Option A: Homelab Server (Docker / Python / Node)
1. Run a lightweight scheduled script on your homelab that fetches your custom RSS feeds and subreddits.
2. (Optional) Run local summarization with **Ollama** or call the free **Google Gemini Flash** API.
3. Serve `edition.json` over your local network (e.g. `http://192.168.1.100:8080/edition.json`) or via Tailscale / reverse proxy.
4. Set `"feedUrl"` in `apps/inkwire/.storage/config.json`.

### Option B: Cloudflare Worker / GitHub Actions
1. Deploy a small serverless worker (or a daily scheduled GitHub Action) using the free tier.
2. The worker aggregates your feeds every morning at 6:00 AM, passes them to Gemini Flash, and serves `https://<your-worker>.workers.dev/today.json`.
3. Set your worker URL in `config.json`.

---

## File Structure

```text
apps/inkwire/
├── manifest.json            # App metadata, portrait orientation, and Book icon
├── main.lua                 # Main coordinator and lifecycle hooks
├── state.lua                # Edition state, pagination, and Wi-Fi sync logic
├── ui.lua                   # High-contrast e-ink typography, masthead, and cards
├── qr.lua                   # Native 1-bit QR code drawing wrapper
├── json.lua                 # Pure-Lua JSON encoder/decoder
├── sample_edition.json      # Bundled offline fallback edition
├── test_inkwire.lua         # Standalone unit test suite (50 tests)
├── views/
│   ├── frontpage.lua        # Masthead, section tabs, and story cards
│   ├── article.lua          # Deep reading view with takeaways & QR handoff
│   └── modals.lua           # Wi-Fi sync and settings overlays
└── README.md                # Documentation
```

---

## Testing & Verification

Run the standalone unit test suite:
```bash
lua apps/inkwire/test_inkwire.lua
```

Run in the desktop simulator:
```bash
./sdk/run apps/inkwire
```

Headless visual render verification:
```bash
./sdk/run --screenshot /tmp/inkwire_frame.bmp apps/inkwire
```
