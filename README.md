# CrossPoint Apps 📦

Official community application repository for the [CrossPoint Reader](https://github.com/chazmus/crosspoint-reader) firmware (ESP32-S3 / E-Ink).

This repository hosts verified, modular Lua applications that run directly on CrossPoint devices. Applications can be browsed and installed over Wi-Fi via the device's built-in **App Store** or copied directly to the SD card.

---

## 📱 Included Applications

### 1. Daily Chess (`apps/chess`)
- **Category**: Games / Puzzles
- **Author**: Chazmus
- **Features**:
  - Daily tactical chess puzzles fetched from Lichess with offline local puzzle fallback (`daily.json`).
  - Board rendering with high-contrast piece sprites optimized for 800×480 E-Ink displays.
  - Touch support for selecting and making moves, interactive move validation, and solution feedback.

### 2. Tally Counter (`apps/counter`)
- **Category**: Utilities
- **Author**: CrossPoint
- **Features**:
  - Clean touch and button-driven tally counter.
  - Persistent state saved to SD card.
  - E-Ink sleep screen takeover (`onSleepDraw`), turning the reader into a low-power persistent counter display.

---

## 🚀 Installing Applications

### Method 1: On-Device App Store (Recommended)
1. Turn on Wi-Fi on your CrossPoint reader.
2. From the main menu, navigate to **Applications** → **App Store**.
3. Under the **Apps** tab, select any application and press **Confirm** or tap **Install**.
4. The application and all its assets will download over HTTPS directly to your SD card.
5. Exit the store; the newly installed app will be immediately visible and ready to launch!

### Method 2: Manual SD Card Installation
1. Insert your reader's MicroSD card into your computer.
2. Copy the desired app folder (e.g., `apps/chess/`) into `/apps/` on your SD card:
   ```text
   /apps/
   └── chess/
       ├── manifest.json
       ├── main.lua
       ├── pieces.lua
       ├── json.lua
       └── daily.json
   ```
3. Reinsert the SD card into your device. CrossPoint discovers new apps automatically on boot.

---

## 🛠️ Adding Custom App Repositories

CrossPoint is completely open! Users can configure any public GitHub repository as an app source:

1. Open **App Store** → navigate to the **Sources** tab.
2. Tap **+ Add Repository...**
3. Type the GitHub repository in `owner/repo` format (e.g. `your-username/my-crosspoint-apps`).
4. CrossPoint verifies that the repository contains a valid `catalog.json` manifest and immediately aggregates its apps into your device's store.

---

## 👨‍💻 Developing a New App

Applications are written in standard Lua 5.4 and have access to the hardware abstraction layer:

- **`gfx`**: Geometry (`drawRect`, `fillRect`, `drawCircle`), text rendering (`drawText`), dithering, 1-bit / masked sprite rendering (`drawSprite`), and buffer refreshes.
- **`input`**: Physical buttons and touch events with screen coordinates (`input.wasReleased`, `input.getTouchPosition`).
- **`storage`**: Safe, mutex-locked SD card file I/O (`storage.read`, `storage.write`, `storage.exists`).
- **`crosspoint`**: Real-time clock (`getEpochTime`), HTTP GET networking (`fetchUrl`), logging (`log`), and sleep-screen hooks (`onSleepDraw`).

### Application Structure (`apps/<app_id>/`)

Each app directory must contain:
1. `manifest.json`: App metadata:
   ```json
   {
     "id": "my_app",
     "name": "My Great App",
     "version": "1.0.0",
     "author": "Your Name",
     "description": "Brief description of the app",
     "icon": "Blocks"
   }
   ```
2. `main.lua`: Application entry point with lifecycle callbacks:
   ```lua
   function onEnter()
     -- Setup and initial render
   end

   function loop()
     -- Input handling and state updates
   end

   function onExit()
     -- Cleanup
   end
   ```

---

## 🤝 Contributing

We welcome community submissions! To add your application to this repository:
1. Fork this repository.
2. Create your app folder under `apps/<app_id>/`.
3. Add your app's entry to root `catalog.json`.
4. Submit a Pull Request.

---

## 📄 License

MIT License. See individual application manifests for third-party asset attributions.
