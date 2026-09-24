# CrossPoint Apps 📦

Official community application repository and developer SDK for the [CrossPoint Reader](https://github.com/chazmus/crosspoint-reader) firmware (ESP32-S3 / E-Ink).

This repository hosts verified, modular Lua applications that run directly on CrossPoint devices. Applications can be browsed, installed, and updated over Wi-Fi via the device's built-in **App Store**, or copied directly to the SD card.

It also contains the official **CrossPoint Lua SDK & Desktop Simulator** (`sdk/`), enabling developers to build, test, visually align, and debug applications on PC (Linux/macOS) with pixel-accurate E-Ink simulation, hardware input mapping, live hot-reloading, and dynamic orientation.

---

## 📱 Included Applications

Each application maintains its own dedicated `README.md` with in-depth gameplay rules, controls, and architecture documentation:

| Application | Path | Category | Orientation | Description | Guide |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Daily Chess** | `apps/chess` | Games / Puzzles | Landscape ($800 \times 480$) | Daily tactical puzzles fetched from Lichess with offline fallback and sleep screen board. | [README](apps/chess/README.md) |
| **Spell Counter** | `apps/spellcounter` | Games / Utilities | Landscape ($800 \times 480$) | MTG life and counter tracker (1–4 players, commander damage, poison, tools, sleep summary). | [README](apps/spellcounter/README.md) |
| **Tally Counter** | `apps/counter` | Utilities | Portrait ($480 \times 800$) | Touch and physical button counter with persistent SD storage and sleep screen desk display. | [README](apps/counter/README.md) |

---

## 💻 CrossPoint Desktop SDK & Simulator

Develop, visually align, and test applications directly on your computer without flashing firmware or swapping SD cards.

```text
sdk/
├── run                      # CLI runner (auto-builds & launches simulator)
├── README.md                # Dedicated SDK guide
└── simulator/               # C++ / SDL2 / Lua 5.4 / stb_truetype simulator source
```

### Simulator Features
- **Pixel-Accurate E-Ink Emulation**: Simulates 1-bit monochrome and 4-level Bayer dithering, rounded rectangles, line boxes, and bitmap/sprite rendering matching CrossPoint hardware.
- **CrossPoint Typography**: Bundled TrueType fonts matching CrossPoint font hash IDs (`FONT_UI_10`, `FONT_UI_12`, `FONT_SMALL`, `FONT_NOTOSANS_*`, `FONT_NOTOSERIF_*`) with exact ascender-based line box alignment.
- **Hardware Input Simulation**:
  - Mouse left-click triggers `onTouch(x, y)` with automatic logical coordinate scaling.
  - Arrow keys, PageUp/PageDown, Enter, and Escape map directly to hardware buttons (`BTN_UP`, `BTN_DOWN`, `BTN_LEFT`, `BTN_RIGHT`, `BTN_CONFIRM`, `BTN_BACK`).
- **Dynamic Orientation**: Auto-detects `"orientation"` from `manifest.json`. Press **`O`** to toggle between Portrait ($480 \times 800$) and Landscape ($800 \times 480$) on the fly.
- **Sleep Screen Preview**: Press **`S`** to toggle between active app rendering (`onDraw`) and the sleep screen (`onSleepDraw`).
- **Live Hot-Reloading**: Automatically detects edits to `main.lua` and reloads in <300ms without restarting the simulator. Press **`R`** for manual reload.
- **Instant Screenshots & Headless CI**: Press **`P`** to save `screenshot.bmp`, or use headless flags (`--screenshot`, `--screenshot-sleep`) for CI visual regression testing.

### Running an App in the Simulator

```bash
# Launch Tally Counter (Portrait)
./sdk/run apps/counter

# Launch Chess (Landscape)
./sdk/run apps/chess

# Force orientation via CLI
./sdk/run -l apps/counter    # Force landscape
./sdk/run -p apps/chess      # Force portrait

# Headless screenshot generation
./sdk/run --screenshot /tmp/counter.bmp apps/counter
./sdk/run --screenshot-sleep /tmp/counter_sleep.bmp apps/counter

# Headless performance profiling
./sdk/run --profile apps/spellcounter
```

### Simulator Hotkeys

| Key / Input | Action | Hardware Equivalent |
| :--- | :--- | :--- |
| **Mouse Left Click** | Touch tap at `(x, y)` | Capacitive Touchscreen (`onTouch`) |
| **Up Arrow / PageUp** | `input.BTN_UP` | Top side button |
| **Down Arrow / PageDown** | `input.BTN_DOWN` | Bottom side button |
| **Left Arrow** | `input.BTN_LEFT` | Left front button |
| **Right Arrow** | `input.BTN_RIGHT` | Right front button |
| **Enter / Space** | `input.BTN_CONFIRM` | Confirm front button |
| **Escape / Backspace** | `input.BTN_BACK` | Back front button (calls `onBack()`) |
| **`O`** | Rotate Orientation | Toggles Portrait ($480 \times 800$) $\leftrightarrow$ Landscape ($800 \times 480$) |
| **`S`** | Toggle Sleep Screen | E-ink sleep screen preview (`onSleepDraw`) |
| **`R`** | Reload App | Re-executes Lua state and `onEnter()` |
| **`P`** | Save Screenshot | Writes `screenshot.bmp` |
| **`T`** | Toggle Profiling | Toggles live frame time and Lua memory logs |

---

## 🚀 Installing Applications on Hardware

### Method 1: On-Device App Store (Recommended)
1. Turn on Wi-Fi on your CrossPoint reader (**Settings** → **Wi-Fi**).
2. From the main menu, navigate to **Applications** → **App Store**.
3. Under the **Apps** tab, select an application and press **Confirm** or tap **Install** (or **Update**).
4. The application and all its assets will download over HTTPS directly to `/apps/<app_id>/` on your SD card.
5. Exit the store; the newly installed app will be immediately visible and ready to launch in the Apps menu!

### Method 2: Manual SD Card Installation
1. Insert your reader's MicroSD card into your computer.
2. Copy the desired app folder (e.g., `apps/chess/`) into `/apps/` on the SD card:
   ```text
   /apps/
   └── chess/
       ├── manifest.json
       ├── main.lua
       ├── pieces.lua
       ├── json.lua
       └── daily.json
   ```
3. Reinsert the SD card. CrossPoint automatically discovers new apps and standalone `.lua` scripts.

---

## 🛠️ Adding Custom App Repositories

CrossPoint is completely open and supports community app repositories:

1. Open **Applications** → **App Store** → navigate to the **Sources** tab.
2. Tap **+ Add Repository...** (or press Confirm on the button).
3. Type the GitHub repository in `owner/repo` format (e.g. `your-username/my-crosspoint-apps`).
4. CrossPoint verifies that the repository contains a valid `catalog.json` manifest and aggregates its applications into your device's store.

---

## 👨‍💻 Developing a New App

Applications are written in standard Lua 5.4. They run within an isolated runtime backed by the ESP32-S3's 8MB PSRAM and communicate with the hardware via dedicated C++ bindings.

### Application Directory Structure (`apps/<app_id>/`)

Each app directory must contain:

1. `manifest.json`: App metadata, orientation, and sleep screen capabilities:
   ```json
   {
     "id": "my_app",
     "title": "My Great App",
     "description": "Brief description of the app",
     "author": "Your Name",
     "icon": "Blocks",
     "orientation": "portrait",
     "version": "1.0.0",
     "sleepScreen": true
   }
   ```
   - `"orientation"`: `"portrait"` ($480 \times 800$, default) or `"landscape"` ($800 \times 480$). The firmware and simulator automatically rotate drawing, screen dimensions, and touch coordinates.
   - `"sleepScreen"`: Set to `true` if the app implements `onSleepDraw()` and can be used as a persistent lock screen.

2. `main.lua`: Application entry point with lifecycle callbacks.

### Application Lifecycle Callbacks

The host environment calls these global Lua functions when events occur:

| Callback | Arguments | Description |
| :--- | :--- | :--- |
| `onEnter()` | *none* | Called once when the app starts. Initialize state and load files. |
| `onTouch(x, y)` | `x, y` (integers) | Fired when the touchscreen is tapped (tap completion). |
| `onTouchDown(x, y)` | `x, y` (integers) | Fired when finger or mouse first touches the screen. |
| `onTouchUp(x, y)` | `x, y` (optional) | Fired when finger or mouse is lifted. |
| `onInput(btn, action)` | `buttonId, action` | Fired when a physical button state changes (`action`: `"press"` or `"release"`). |
| `onBack()` | *none* | Fired when the hardware Back button is pressed. Return `true` to consume the event (e.g., close dialogs); return `false`/nil to exit the app. |
| `onUpdate(dt)` | `dt` (ms or sec) | Called periodically (~50ms) for timers, continuous holds, or step logic. |
| `onDraw()` | *none* | Primary screen render function. Clear and draw graphics here. |
| `onSleepDraw()` | *none* | Called when the device enters sleep if this app was designated as the sleep app. |
| `onExit()` | *none* | Called when exiting the app. Perform state saving or cleanup here. |

---

## 📚 Lua API Reference

### `gfx` — Graphics and Display

| Function | Parameters | Description |
| :--- | :--- | :--- |
| `gfx.getWidth()` | *none* | Returns screen width in pixels ($480$ portrait, $800$ landscape). |
| `gfx.getHeight()` | *none* | Returns screen height in pixels ($800$ portrait, $480$ landscape). |
| `gfx.getOrientation()` | *none* | Returns current orientation string (`"portrait"` or `"landscape"`). |
| `gfx.setOrientation(target)` | `"portrait"` / `"landscape"` or enum | Rotates the display and inverts width/height dimensions. |
| `gfx.clearScreen([color])` | `color` (optional, 0=Black, 1=White) | Clears the active framebuffer. |
| `gfx.drawPixel(x, y, color)` | `x, y, color` | Draws a single pixel. |
| `gfx.drawLine(x0, y0, x1, y1, color)` | `x0, y0, x1, y1, color` | Draws a 1px line between two points. |
| `gfx.drawRect(x, y, w, h, color)` | `x, y, w, h, color` | Draws an unfilled rectangle. |
| `gfx.fillRect(x, y, w, h, color)` | `x, y, w, h, color` | Draws a solid filled rectangle. |
| `gfx.fillRectDither(x, y, w, h, level)` | `x, y, w, h, level` ($0..3$) | Fills a rectangle with 4-level Bayer dither. |
| `gfx.drawRoundedRect(x, y, w, h, r, [c])`| `x, y, w, h, radius, color` | Draws an unfilled rounded rectangle. |
| `gfx.fillRoundedRect(x, y, w, h, r, [c])`| `x, y, w, h, radius, color` | Draws a solid filled rounded rectangle. |
| `gfx.drawCircle(x, y, r, color)` | `x, y, radius, color` | Draws an unfilled circle. |
| `gfx.drawText(font, x, y, text, color)` | `fontId, x, y, text, color` | Renders text string at `(x, y)`. |
| `gfx.drawCenteredText(font, y, text, c)` | `fontId, y, text, color` | Centers text horizontally on the screen at vertical position `y`. |
| `gfx.getTextWidth(font, text)` | `fontId, text` | Returns the width in pixels of `text` when rendered in `font`. |
| `gfx.getLineHeight(font)` | `fontId` | Returns the total line height / ascender of `font`. |
| `gfx.drawSprite(x, y, w, h, data, [c])` | `x, y, w, h, table, color` | Renders a 1-bit monochrome sprite table (`0`=trans, `1`=opaque). |
| `gfx.drawBitmapFile(x, y, path)` | `x, y, filepath` | Renders a 1-bit BMP file from SD card storage. |
| `gfx.displayBuffer([mode])` | `mode` (optional) | Flushes framebuffer to E-Ink display (`REFRESH_FAST`, `HALF`, `FULL`). |

#### `gfx` Constants
- **Colors**: `gfx.COLOR_WHITE` (`0`), `gfx.COLOR_BLACK` (`1`), `gfx.COLOR_LIGHT_GRAY` (`2`), `gfx.COLOR_DARK_GRAY` (`3`).
- **Refresh Modes**: `gfx.REFRESH_FAST` (`0`), `gfx.REFRESH_HALF` (`1`), `gfx.REFRESH_FULL` (`2`).
- **Orientation Modes**: `gfx.ORIENTATION_PORTRAIT`, `gfx.ORIENTATION_LANDSCAPE`, `gfx.ORIENTATION_PORTRAIT_INVERTED`, `gfx.ORIENTATION_LANDSCAPE_CCW`.
- **Fonts**:
  - `gfx.FONT_UI_10`, `gfx.FONT_UI_12` (Interface sans-serif)
  - `gfx.FONT_SMALL` (Compact text)
  - `gfx.FONT_NOTOSANS_12`, `gfx.FONT_NOTOSANS_14`, `gfx.FONT_NOTOSANS_16`
  - `gfx.FONT_NOTOSERIF_12`, `gfx.FONT_NOTOSERIF_14`

---

### `input` — Buttons and Touch

| Function | Parameters | Description |
| :--- | :--- | :--- |
| `input.wasPressed(btn)` | `buttonId` | Returns `true` if the button was clicked this frame. |
| `input.isPressed(btn)` | `buttonId` | Returns `true` if the button is currently held down. |
| `input.isTouchDown()` | *none* | Returns `true` if finger/mouse is currently pressed down. |
| `input.getTouch()` | *none* | Returns `isDown, x, y` (current touch contact position). |
| `input.wasTouchDown()` | *none* | Returns `isDown, x, y` if a new touch began this frame. |
| `input.wasTouchReleased()` | *none* | Returns `true` if touch contact ended this frame. |
| `input.wasScreenTapped(x, y, w, h)` | `x, y, w, h` | Returns `true` if the given bounding box was tapped. |

#### `input` Button Constants
- `input.BTN_UP`: Top side button (or PageUp).
- `input.BTN_DOWN`: Bottom side button (or PageDown).
- `input.BTN_LEFT`: Left front button.
- `input.BTN_RIGHT`: Right front button.
- `input.BTN_CONFIRM`: Center / Confirm front button.
- `input.BTN_BACK`: Back front button.
- `input.BTN_PAGE_BACK`, `input.BTN_PAGE_FORWARD`: Logical page flip buttons.

---

### `storage` — Sandboxed SD Card Storage

All paths are sandboxed inside the app's directory (`/apps/<app_id>/` on hardware, `apps/<app_id>/.storage/` in the simulator). Cross-app access is prevented.

| Function | Parameters | Description |
| :--- | :--- | :--- |
| `storage.readFile(path)` | `filename` | Returns the file contents as a string, or `nil` if missing. |
| `storage.writeFile(path, content)` | `filename, string` | Writes string content to file. Returns `true` on success. |
| `storage.exists(path)` | `filename` | Returns `true` if the file exists. |
| `storage.remove(path)` | `filename` | Deletes the file. Returns `true` on success. |

---

### `log` — Serial & Debug Logging

CrossPoint firmware streams logging over USB Serial (`115200` baud) via FreeRTOS `LOG_INF`, `LOG_DBG`, and `LOG_ERR`. In the desktop simulator, logs are formatted with ANSI color output. Safe for all Lua types (strings, numbers, tables, booleans, and nil).

| Function | Parameters | Description |
| :--- | :--- | :--- |
| `log.debug([tag], msg)` | `[tag], msg` | Emits a debug level message (`LOG_DBG` on hardware, gray in simulator). |
| `log.info([tag], msg)` | `[tag], msg` | Emits an informational message (`LOG_INF` on hardware, cyan in simulator). |
| `log.warn([tag], msg)` | `[tag], msg` | Emits a warning message (`LOG_INF [WARN]` on hardware, yellow in simulator). |
| `log.error([tag], msg)` | `[tag], msg` | Emits an error level message (`LOG_ERR` on hardware, red in simulator). |

---

### `crosspoint` — System & Network Utilities

| Function | Parameters | Description |
| :--- | :--- | :--- |
| `crosspoint.millis()` | *none* | Returns system uptime in milliseconds. |
| `crosspoint.requestUpdate()` | *none* | Flags that the screen needs redrawing on the next cycle. |
| `crosspoint.finish()` | *none* | Gracefully exits the application and returns to CrossPoint. |
| `crosspoint.log([tag], msg)` | `[tag], msg` | Backwards-compatible alias to `log.info`. |
| `crosspoint.getMemoryInfo()` | *none* | Returns table with memory metrics: `{ luaMemoryKb = <int>, freeHeapKb = <int>, freePsramKb = <int> }`. |
| `crosspoint.isWifiConnected()` | *none* | Returns `true` if Wi-Fi is active and connected to an AP. |
| `crosspoint.connectWifi(callback)` | `callback(connected)` | Connects to Wi-Fi on-demand via modal `WifiSelectionActivity`, invoking `callback(true/false)`. |
| `crosspoint.withWifi(callback)` | `callback(connected)` | Scoped Wi-Fi connection. Automatically connects on-demand and guarantees Wi-Fi disconnects upon return or error. |
| `crosspoint.disconnectWifi()` | *none* | Disconnects Wi-Fi immediately to conserve battery. |
| `crosspoint.httpGet(url)` | `urlString` | Performs an HTTP GET request over Wi-Fi (or libcurl in simulator). Returns response body string. |
| `crosspoint.setSleepApp(appId)` | `appId` | Designates an app to render the E-Ink sleep screen. |
| `crosspoint.getSleepApp()` | *none* | Returns the ID of the currently designated sleep app. |
| `crosspoint.clearSleepApp()` | *none* | Unsets the sleep screen app, reverting to default cover/screensaver. |

---

### Modular Code & `require()`

Applications can be cleanly organized into multiple modules and subdirectories using standard Lua `require("submodule")` or `require("views.grid")`:

- Modules are resolved relative to the app's root folder (`apps/<app_id>/<module>.lua` or `<module>/init.lua`).
- Loaded modules are automatically cached in `package.loaded`.
- All module files must be declared in root `catalog.json` under `"files"` so the on-device App Store downloads all dependencies.

---

## 🤝 Contributing & Publishing Applications

To publish your application to the official CrossPoint App Store:

1. Fork this repository.
2. Develop and test your application using the simulator:
   ```bash
   ./sdk/run apps/<your_app>
   ```
3. Ensure your `manifest.json` contains valid metadata, orientation, and versioning.
4. Add your app's entry to root `catalog.json`:
   ```json
   {
     "id": "my_app",
     "name": "My App",
     "version": "1.0.0",
     "author": "Your Name",
     "description": "What my app does",
     "icon": "Blocks",
     "path": "apps/my_app",
     "files": [
       "manifest.json",
       "main.lua"
     ]
   }
   ```
5. Bump `"version"` in root `catalog.json`.
6. Submit a Pull Request! Once merged, all CrossPoint devices worldwide will immediately see your app in their on-device store.

---

## 📄 License

MIT License. See individual application manifests for third-party asset attributions.
