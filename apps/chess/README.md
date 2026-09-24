# Daily Chess ♟️

A daily tactical chess puzzle application for CrossPoint Reader (ESP32-S3 / E-Ink).

![Category](https://img.shields.io/badge/Category-Games%20%26%20Puzzles-blue)
![Orientation](https://img.shields.io/badge/Orientation-Landscape%20(800x480)-green)
![Version](https://img.shields.io/badge/Version-1.0.3-orange)

---

## Overview

**Daily Chess** brings daily tactical chess training to your CrossPoint e-reader. It connects to Wi-Fi on-demand to fetch the daily puzzle from the [Lichess API](https://lichess.org/api#tag/Puzzles/operation/apiPuzzleDaily), automatically manages Wi-Fi lifecycle to conserve battery, and gracefully falls back to bundled offline puzzles if no internet connection is available.

Designed specifically for monochrome 800×480 E-Ink displays, Daily Chess features high-contrast piece glyphs, instant touch-based move input, turn validation, interactive solution checking, and an ambient sleep screen mode.

---

## Features

- **On-Demand Wi-Fi Daily Sync**: Tapping **Update** connects to Wi-Fi via `crosspoint.withWifi`, downloads the latest daily puzzle from Lichess over HTTPS, and automatically shuts down Wi-Fi immediately upon completion to preserve battery.
- **Offline Fallback**: Bundled with local puzzle data (`daily.json`) so the app is always playable offline.
- **Touch-Optimized Board**:
  - Tap a piece to highlight legal destination squares.
  - Tap a destination square to make a move.
  - Automatic board flipping based on whether the puzzle requires playing as White or Black.
- **Solution Verification**: Validates moves against the puzzle's UCI move line. Immediate visual feedback indicates correct moves or blunders.
- **Move History & Rating**: Displays the puzzle rating, theme tags, and move sequence.
- **Sleep Screen Mode (`onSleepDraw`)**: Sets the reader's low-power sleep screen to display the daily puzzle board and rating, turning your idle device into a desk puzzle display.

---

## Controls

### Touch Input
- **Tap Piece**: Selects the active piece and displays candidate move highlights.
- **Tap Square**: Moves the selected piece to the target square.
- **Top / Bottom Bar Buttons**:
  - **Hint**: Shows the next move in the puzzle sequence.
  - **Reset**: Resets the board back to the initial puzzle state.
  - **New / Next**: Cycles through available puzzles.

### Physical Hardware Buttons
- **`CONFIRM` (Center)**: Confirms selection or toggles move hint.
- **`BACK` (Escape)**: Exits the app back to the CrossPoint launcher.
- **`PAGE_BACK` / `PAGE_FORWARD`**: Step through move history.

---

## File Structure

```text
apps/chess/
├── manifest.json       # App metadata, landscape orientation, and sleep screen flag
├── main.lua            # Lifecycle hooks, board controller, and UI rendering
├── pieces.lua          # 1-bit monochrome piece bitmap sprites (King, Queen, Rook, etc.)
├── json.lua            # Pure-Lua JSON parser for Lichess API responses
├── daily.json          # Bundled offline fallback puzzle dataset
└── README.md           # This documentation
```

---

## Testing in Simulator

You can test and run Daily Chess on your desktop using the CrossPoint SDK:

```bash
# Launch Daily Chess in landscape mode
./sdk/run apps/chess

# Generate a screenshot of the active board
./sdk/run --screenshot /tmp/chess.bmp apps/chess

# Preview the sleep screen rendering
./sdk/run --screenshot-sleep /tmp/chess_sleep.bmp apps/chess
```
