# CrossPoint Apps Development Guide (Lua Apps & SDK)

Project: Modular community application ecosystem and developer SDK for CrossPoint Reader (ESP32-S3 / E-Ink).
Companion Repository: [crosspoint-reader](https://github.com/chazmus/crosspoint-reader) (C++ firmware).

---

## AI Agent Identity & Cognitive Rules

* **Role**: Senior Embedded Systems Engineer & Lua Application Developer.
* **Target Hardware**: ESP32-S3 (dual-core Xtensa LX7 @ 240MHz, 8MB Octal PSRAM), 800×480 E-Ink display (SSD1677), Goodix GT911 capacitive touch, SDMMC storage.
* **Verification Mandate**: You MUST verify any application changes or additions using the desktop simulator (`./sdk/run`) and inspect generated screenshots before declaring work complete.
* **E-Ink Sensibility**: Design strictly for reflective, high-latency monochrome displays: high contrast, clean typography, generous touch targets (>= 44px), event-driven rendering, no fast animations.
* **App Store Discipline**: Any code change or fix to an existing app MUST bump the app's version in both its `manifest.json` and root `catalog.json`. Otherwise, physical devices will not offer an update to users.

---

## Development Environment & Platform Detection

Detect the host platform at session start to choose appropriate tools:

```bash
uname -s
# Linux, Darwin, MINGW64_NT-*
```

### Desktop SDK & Simulator (`sdk/`)

The repository includes a pixel-accurate C++/SDL2 desktop simulator for developing, visually testing, and aligning Lua apps without needing physical hardware:

```bash
# Launch an app interactively
./sdk/run apps/counter
./sdk/run apps/chess

# Force orientation via CLI
./sdk/run -p apps/chess      # Force portrait (480x800)
./sdk/run -l apps/counter    # Force landscape (800x480)

# Headless visual verification (renders directly to BMP without SDL2 window)
./sdk/run --screenshot /tmp/app_frame.bmp apps/<app_id>
./sdk/run --screenshot-sleep /tmp/sleep_frame.bmp apps/<app_id>
```

#### Simulator Hotkeys
- **Mouse Left-Click**: Simulates capacitive touch tap (`onTouch(x, y)`).
- **`O`**: Rotate orientation (toggles Portrait $480 \times 800 \leftrightarrow$ Landscape $800 \times 480$).
- **`S`**: Toggle Sleep Screen view (`onSleepDraw()`).
- **`R`**: Hot-reload Lua state and re-run `onEnter()`.
- **`P`**: Save `screenshot.bmp` of current frame.
- **`T`**: Toggle live performance profiling log output (frame execution time and Lua RAM).
- **Arrows / Enter / Escape / PageUp / PageDown**: Mapped hardware buttons (`input.BTN_*`).

You can also run headless profiling via:
```bash
./sdk/run --profile apps/<app_id>
```

---

## E-Ink Display Constraints & Design Rules

1. **Resolution & Orientation**:
   - Hardware native panel: $800 \times 480$.
   - **Portrait** ($480 \text{ wide} \times 800 \text{ high}$): Default for CrossPoint handheld reading and utilities.
   - **Landscape** ($800 \text{ wide} \times 480 \text{ high}$): Ideal for board games (chess), charts, tabular data, split-pane UIs.
   - Declare orientation in `manifest.json` via `"orientation": "portrait"` or `"orientation": "landscape"`.
   - **Never hardcode coordinate boundaries**: Always query `gfx.getWidth()` and `gfx.getHeight()` dynamically.

2. **Refresh & Latency**:
   - Full refresh flashes black/white and takes ~800–1000ms (`gfx.REFRESH_FULL`). Use only on app start or mode switch.
   - Partial/fast refresh updates in ~200–300ms without flashing (`gfx.REFRESH_FAST`).
   - Never implement 60 FPS continuous animation loops. Render on demand: call `crosspoint.requestUpdate()` only when input or data changes.

3. **Monochrome Contrast & Dithering**:
   - Use high contrast: solid black text on white backgrounds or inverted white-on-black cards.
   - Avoid thin 1px light gray borders. Use rounded rectangles with solid borders (`gfx.drawRoundedRect(x, y, w, h, radius, thickness, color)`).
   - Use 4-level Bayer dither (`gfx.fillRectDither`) sparingly for backgrounds or inactive regions.

4. **Typography & Line Alignment**:
   - Available font constants: `gfx.FONT_UI_10`, `gfx.FONT_UI_12`, `gfx.FONT_SMALL`, `gfx.FONT_NOTOSANS_12`, `gfx.FONT_NOTOSANS_14`, `gfx.FONT_NOTOSANS_16`, `gfx.FONT_NOTOSERIF_12`, `gfx.FONT_NOTOSERIF_14`.
   - Text rendering in CrossPoint aligns from the **baseline / ascender top**. Use `gfx.getLineHeight(font)` and `gfx.getTextWidth(font, text)` to compute vertical and horizontal centering.

---

## Application Structure & Contract

All apps reside under `apps/<app_id>/`:

```text
apps/<app_id>/
├── manifest.json            # Application metadata & capabilities
├── main.lua                 # Entry point and lifecycle callbacks
├── README.md                # Dedicated user & developer guide for this app
├── test_<app_id>.lua        # Optional standalone unit test suite
└── [supporting files]       # Views, helpers, sprites, and data files
```

### `manifest.json` Specification

```json
{
  "id": "my_app",
  "title": "My Great App",
  "description": "Short 1-line description of the application",
  "author": "Your Name",
  "icon": "Blocks",
  "orientation": "portrait",
  "version": "1.0.0",
  "sleepScreen": true
}
```

- `"id"`: Unique alphanumeric string identifier (matches folder name).
- `"title"`: Human-readable display name.
- `"orientation"`: `"portrait"` ($480 \times 800$, default) or `"landscape"` ($800 \times 480$).
- `"version"`: Semantic version string. Must be bumped with every change.
- `"icon"`: UI icon identifier from CrossPoint `UIIcon` (e.g. `"Blocks"`, `"Book"`, `"Settings"`, `"Help"`, `"Sync"`).
- `"sleepScreen"`: Set to `true` if the app implements `onSleepDraw()`.

### Lifecycle Callbacks

The host runtime calls these global functions in `main.lua`:

- **`onEnter()`**: Called when the app starts. Read saved state (`storage.readFile()`), initialize tables.
- **`onTouch(x, y)`**: Called on capacitive touch tap completion. Coordinates are already transformed into logical screen space based on orientation.
- **`onTouchDown(x, y)`**: Called when touch contact begins.
- **`onTouchUp(x, y)`**: Called when touch contact ends / finger is lifted.
- **`onInput(buttonId, action)`**: Physical button events. `action` is `"press"` or `"release"`.
- **`onBack()`**: Hardware Back button handler. Return `true` to consume the back event (e.g., closing a modal or subview); return `false` or `nil` to allow CrossPoint to exit to the launcher.
- **`onUpdate(dt)`**: Periodic update step (~50ms). Do NOT call drawing primitives here; update internal timers, continuous touch holds, and call `crosspoint.requestUpdate()`.
- **`onDraw()`**: Main rendering routine. Clear and redraw the screen with `gfx.*`.
- **`onSleepDraw()`**: Sleep screen renderer. Called when the reader enters sleep if this app was designated as sleep app (`crosspoint.setSleepApp("<app_id>")`).
- **`onExit()`**: Called prior to exiting. Save persistent state (`storage.writeFile()`).

---

## Lua API Reference

### `gfx` Module
- `gfx.getWidth()`, `gfx.getHeight()`: Screen dimensions in current orientation.
- `gfx.getOrientation()`: Returns `"portrait"` or `"landscape"`.
- `gfx.setOrientation("portrait" | "landscape")`: Rotates orientation dynamically.
- `gfx.clearScreen([color])`: 0=Black, 1=White.
- `gfx.drawPixel(x, y, color)`
- `gfx.drawLine(x0, y0, x1, y1, color)`
- `gfx.drawRect(x, y, w, h, color)`
- `gfx.fillRect(x, y, w, h, color)`
- `gfx.fillRectDither(x, y, w, h, level)`: 4-level dither ($0..3$).
- `gfx.drawRoundedRect(x, y, w, h, r, [thickness], [color])`
- `gfx.fillRoundedRect(x, y, w, h, r, [color])`
- `gfx.drawCircle(x, y, r, color)`
- `gfx.drawText(fontId, x, y, text, color)`
- `gfx.drawCenteredText(fontId, y, text, color)`
- `gfx.getTextWidth(fontId, text)`
- `gfx.getLineHeight(fontId)`
- `gfx.drawSprite(x, y, w, h, dataTable, [color])`: 1-bit table (`1`=opaque, `0`=transparent).
- `gfx.drawBitmapFile(x, y, filepath)`: 1-bit BMP from SD card.
- `gfx.displayBuffer([mode])`: `gfx.REFRESH_FAST`, `REFRESH_HALF`, `REFRESH_FULL`.

### `input` Module
- `input.wasPressed(btn)`
- `input.isPressed(btn)`
- `input.isTouchDown()`: Returns `true` if finger / mouse is currently held down.
- `input.getTouch()`: Returns `isDown, x, y` (logical coordinates).
- `input.wasTouchDown()`: Returns `isDown, x, y` if touch started this frame.
- `input.wasTouchReleased()`: Returns `true` if touch ended this frame.
- `input.wasScreenTapped(x, y, w, h)`: Bounding box touch hit test.
- Button constants: `input.BTN_UP`, `input.BTN_DOWN`, `input.BTN_LEFT`, `input.BTN_RIGHT`, `input.BTN_CONFIRM`, `input.BTN_BACK`, `input.BTN_PAGE_BACK`, `input.BTN_PAGE_FORWARD`.

### `storage` Module
- `storage.readFile(path)`: Returns file content string or `nil`.
- `storage.writeFile(path, content)`: Saves string content. Returns `true` on success.
- `storage.exists(path)`: Returns boolean.
- `storage.remove(path)`: Deletes file.
- **Sandboxed**: All paths are automatically isolated in `/apps/<app_id>/` on hardware and `apps/<app_id>/.storage/` in the simulator.

### `log` Module (Serial & Debug Logging)
CrossPoint firmware connects logging directly to hardware serial monitor (`115200` baud via USB CDC).
- `log.debug([tag], message)`: Emits debug log (`LOG_DBG` on hardware, gray on simulator).
- `log.info([tag], message)`: Emits info log (`LOG_INF` on hardware, cyan on simulator).
- `log.warn([tag], message)`: Emits warning log (`LOG_INF` with `[WARN]`, yellow on simulator).
- `log.error([tag], message)`: Emits error log (`LOG_ERR` on hardware, red on simulator).
- Safe with all Lua data types: numbers, tables, booleans, and `nil` are stringified automatically without raising errors.

### Modular Code & `require()`
Apps can split complex logic across multiple files using standard Lua `require("submodule")` or `require("views.grid")`:
- Modules are resolved relative to the app's root folder (`apps/<app_id>/<module>.lua` or `<module>/init.lua`).
- Loaded modules are cached automatically in `package.loaded`.

### `crosspoint` Module
- `crosspoint.millis()`: Milliseconds since boot.
- `crosspoint.requestUpdate()`: Flags dirty screen for redraw on next loop.
- `crosspoint.finish()`: Exits app back to CrossPoint launcher.
- `crosspoint.log([tag], msg)`: Backwards-compatible alias to `log.info`.
- `crosspoint.getMemoryInfo()`: Returns table with memory metrics: `{ luaMemoryKb = <int>, freeHeapKb = <int>, freePsramKb = <int> }`.
- `crosspoint.isWifiConnected()`: Returns `true` if connected to Wi-Fi.
- `crosspoint.httpGet(url)`: Performs HTTP GET over Wi-Fi (or libcurl in simulator).
- `crosspoint.setSleepApp(appId)`: Registers app for sleep screen takeover.
- `crosspoint.getSleepApp()`: Returns current sleep app ID.
- `crosspoint.clearSleepApp()`: Restores default sleep screen.

---

## App Store & Catalog Protocol (`catalog.json`)

CrossPoint readers maintain an on-device App Store that synchronizes with `catalog.json` in the root of this repository.

### Release & Update Checklist

Whenever an app is created or modified:
1. **Verify locally**: Test using `./sdk/run` (interactive touch, buttons, and sleep screen `S`).
2. **Run tests**: If the app includes a unit test script (e.g. `lua apps/<app_id>/test_<app_id>.lua`), execute and verify all tests pass.
3. **Documentation**: Ensure `apps/<app_id>/README.md` is created or updated to document new features, controls, and architecture.
4. **Bump app version**: In `apps/<app_id>/manifest.json`, increment `"version"` (e.g. `"1.0.1"` $\rightarrow$ `"1.0.2"`).
5. **Update catalog entry**: In `catalog.json`:
   - Match the updated `"version"`.
   - Verify all required runtime files are listed in `"files"`.
6. **Bump root catalog version**: In `catalog.json`, increment `"version"` integer (e.g. `2` $\rightarrow$ `3`).
7. **Commit and push** to `main` branch after verification.

---

## Testing & Verification Patterns

For non-trivial applications, implement a mock-based test harness (`apps/<app_id>/test_<app_id>.lua`) that tests game state transitions, edge cases, nil safety, and boundary clamps without requiring the SDL2 simulator or physical hardware:

```bash
lua apps/<app_id>/test_<app_id>.lua
```

---

## Memory, Concurrency & Platform Discipline

- **Thread-Safe Firmware Execution**: CrossPoint firmware uses FreeRTOS multi-tasking where `FreeInkUI` invokes `onDraw()` from a dedicated `renderTaskLoop` while touch and button events are processed on the main loop task. The firmware synchronizes all Lua state execution with a recursive mutex (`luaMutex_`). Keep `onTouch()`, `onDraw()`, and `onUpdate()` callbacks fast and non-blocking.
- **PSRAM Allocation**: On physical hardware, all Lua allocations are hosted in 8MB PSRAM (`LuaPsramAlloc.h`). DRAM is preserved for networking and the E-Ink framebuffer.
- **Garbage Collection**: Do not allocate throwaway tables or concatenate large strings inside `onDraw()` or `onUpdate()`. Pre-allocate state tables and buffer reuse where possible.
- **32-Bit Float Mantissa Limit**: The firmware builds with `-DLUA_32BITS=1`. Numbers in Lua 5.4 have 24 bits of float mantissa. Integers up to $16,777,216$ are exact; beyond that precision is lost. Font IDs are handled internally via integer pointers.
