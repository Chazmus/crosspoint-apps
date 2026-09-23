# CrossPoint Lua App SDK & Simulator

A fast, lightweight desktop simulator and developer tool for building, visually aligning, and debugging CrossPoint Lua applications on PC (Linux/macOS) without needing physical hardware or flashing.

---

## Features

- **Pixel-Accurate 800×480 E-Ink Framebuffer**: Simulates 1-bit monochrome and 4-level e-ink dithering, rounded rectangles, line boxes, and bitmap/sprite rendering.
- **CrossPoint Typography**: Bundled TrueType fonts matching standard CrossPoint font hash IDs (`FONT_UI_10`, `FONT_UI_12`, `FONT_SMALL`, `FONT_NOTOSANS_*`, `FONT_NOTOSERIF_*`) with exact ascender-based line box alignment.
- **Hardware Input Simulation**:
  - Mouse clicks trigger `onTouch(x, y)` with automatic logical coordinate scaling.
  - Arrow keys, PageUp/PageDown, Enter, and Escape map directly to hardware buttons (`BTN_UP`, `BTN_DOWN`, `BTN_LEFT`, `BTN_RIGHT`, `BTN_CONFIRM`, `BTN_BACK`).
- **Sleep Screen Preview**: Press **`S`** to toggle between the active app view (`onDraw`) and the low-power sleep screen (`onSleepDraw`).
- **Live Hot-Reloading**: Automatically detects edits to `main.lua` and reloads within 300ms without restarting the simulator. Press **`R`** for immediate manual reload.
- **Instant Screenshots**: Press **`P`** to save `screenshot.bmp` during interactive mode, or use headless flags for automated visual tests and documentation.
- **Full API Parity**: Includes `gfx`, `input`, `storage` (sandboxed in `<app>/.storage/`), and `crosspoint` (including live network `httpGet()` via `libcurl`).

---

## Quick Start

### Prerequisites (Linux)

Install SDL2, libcurl, and CMake:

```bash
# Ubuntu / Debian
sudo apt install libsdl2-dev libcurl4-openssl-dev cmake build-essential

# Arch / Manjaro / CachyOS
sudo pacman -S sdl2 curl cmake base-devel

# Fedora
sudo dnf install SDL2-devel libcurl-devel cmake gcc-c++
```

### Running an App

From the repository root, run:

```bash
# Launch Tally Counter
./sdk/run apps/counter

# Launch Chess Daily Tactics
./sdk/run apps/chess
```

The runner script (`sdk/run`) will automatically build the simulator executable on first run (or after any SDK changes) and launch the app window.

---

## Controls & Hotkeys

| Key / Input | Action | CrossPoint Hardware Equivalent |
| :--- | :--- | :--- |
| **Mouse Left Click** | Touch tap at `(x, y)` | Capacitive Touchscreen (`onTouch`) |
| **Up Arrow / PageUp** | `input.BTN_UP` | Left physical button (X4) |
| **Down Arrow / PageDown** | `input.BTN_DOWN` | Right physical button (X4) |
| **Left Arrow** | `input.BTN_LEFT` | Left directional button |
| **Right Arrow** | `input.BTN_RIGHT` | Right directional button |
| **Enter / Space** | `input.BTN_CONFIRM` | Confirm button |
| **Escape / Backspace** | `input.BTN_BACK` | Back button (calls `onBack()`) |
| **`O`** | Rotate Orientation | Toggles Portrait (480×800) $\leftrightarrow$ Landscape (800×480) |
| **`S`** | Toggle Sleep Screen | E-ink sleep screen preview |
| **`R`** | Reload App | Restarts Lua state & re-runs `onEnter()` |
| **`P`** | Save Screenshot | Writes `screenshot.bmp` to current directory |

---

## Orientation Support

CrossPoint apps can declare their intended orientation in `manifest.json`:

```json
{
  "id": "chess",
  "title": "Chess Puzzles",
  "orientation": "landscape"
}
```

- `"orientation": "portrait"`: 480 wide × 800 high (default for CrossPoint handhelds).
- `"orientation": "landscape"`: 800 wide × 480 high (ideal for boards, tables, side-by-side panels).

The simulator automatically detects the manifest orientation, or you can force it via CLI:
```bash
./sdk/run -p apps/chess    # Force portrait
./sdk/run -l apps/counter  # Force landscape
```
At runtime, apps can also query or change orientation via `gfx.getOrientation()` and `gfx.setOrientation("landscape")`.

---

## Headless & CI Usage

The simulator can run headlessly (without an SDL2 window) to render frames directly to BMP files:

```bash
# Render initial app frame
./sdk/run --screenshot /tmp/counter.bmp apps/counter

# Render sleep screen frame
./sdk/run --screenshot-sleep /tmp/counter_sleep.bmp apps/counter
```

---

## Project Structure

```text
sdk/
├── run                      # Main entrypoint script (auto-builds & runs apps)
├── README.md                # SDK documentation
└── simulator/
    ├── CMakeLists.txt       # CMake build definition
    ├── assets/fonts/        # Bundled Noto Sans & Serif TTF fonts
    ├── lua/                 # Embedded Lua 5.4.7 core
    ├── stb/                 # stb_truetype header-only library
    └── src/
        ├── main.cpp         # SDL2 window loop, hotkey handlers, live hot-reloader
        ├── SimRenderer.h/.cpp    # 800x480 e-ink framebuffer, drawing & BMP exporter
        ├── FontRenderer.h/.cpp   # stb_truetype rasterizer matching font hash IDs
        ├── SimStorage.h/.cpp     # Local sandboxed file storage (.storage/)
        └── LuaSimBindings.h/.cpp # gfx, input, storage, crosspoint C++ bindings
```
