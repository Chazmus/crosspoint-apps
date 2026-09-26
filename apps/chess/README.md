# CrossPoint Chess

A complete chess application for CrossPoint Reader (ESP32-S3 / E-Ink), featuring **Play vs Computer** (built-in pure-Lua AI with 3 difficulty levels) and **Daily Chess Puzzles** (synced from Lichess).

![Category](https://img.shields.io/badge/Category-Games%20%26%20Puzzles-blue)
![Orientation](https://img.shields.io/badge/Orientation-Landscape%20(800x480)-green)
![Version](https://img.shields.io/badge/Version-1.1.2-orange)

---

## Overview

**CrossPoint Chess** brings full-featured chess to your CrossPoint e-reader:
1. **Play vs Computer**: Challenge an on-device chess engine with 3 skill levels (Easy, Medium, Hard). Play as White or Black, view legal move indicators, take back moves, flip the board, and save games automatically.
2. **Daily Puzzles**: Connect to Wi-Fi on-demand to fetch tactical training puzzles from the [Lichess API](https://lichess.org/api#tag/Puzzles/operation/apiPuzzleDaily), or solve bundled offline tactics when on the go.

Designed specifically for reflective, monochrome 800x480 E-Ink displays with high contrast, crisp Staunton piece glyphs, generous touch targets (>= 44px), and ambient sleep screen integration.

---

## Features

- **Built-in Pure-Lua Chess Engine (`engine.lua`)**:
  - Full FIDE rule implementation: castling, en passant, pawn promotion, check, checkmate, stalemate, 50-move rule, and insufficient material draws.
  - Minimax search with Alpha-Beta pruning, Piece-Square Tables (PST), and move ordering.
  - Highly optimized for ESP32-S3 PSRAM architecture: zero-allocation ray casting, hoisted directional tables, lookup-based piece testing, and pooled undo stacks.
  - 3 Embedded-Calibrated Difficulty Levels:
    - **Easy (~1000 Elo)**: Depth 1 search with randomized candidate selection within a close evaluation margin. Instant response (~0.05s on ESP32).
    - **Medium (~1350 Elo)**: Depth 2 search with positional evaluation and material awareness (~0.2–0.4s on ESP32).
    - **Hard (~1600 Elo)**: Depth 3 search with tactical combinations, piece-square development, and alpha-beta pruning (~1.5–2.5s on ESP32).
- **High-Contrast Staunton Pieces**: Custom 40x40 dual-layer 1-bit sprites derived from Colin M.L. Burnett's open-source piece vectors. Solid fills for Light pieces and contrast halos for Dark pieces ensure pieces remain legible on white and dithered squares.
- **Interactive Move Guidance**:
  - Tap your piece to highlight all legal destination squares (dots for quiet moves, rings for captures).
  - Tap destination to execute move.
  - Automatic promotion to Queen.
- **Game State Persistence**:
  - Ongoing games automatically save to `game.json` in sandboxed app storage.
  - Main menu provides an instant **Resume Game** option.
- **Takebacks & Board Flipping**:
  - **Undo**: Rewinds both computer and player moves cleanly.
  - **Flip Board**: Toggles board orientation between White and Black perspectives.
- **Daily Puzzle Mode**:
  - On-demand Wi-Fi sync via `crosspoint.withWifi` downloads the daily Lichess puzzle and disconnects Wi-Fi immediately to conserve battery.
  - Interactive solution verification with hints and resets.
  - Offline fallback dataset (`daily.json`).
- **Ambient Sleep Screen (`views/sleep.lua`)**:
  - Shows your ongoing game (board, move number, turn indicator) when put to sleep during a match.
  - Shows the daily tactical puzzle when put to sleep from puzzle mode or the main menu.
  - Toggle sleep takeover directly from the main menu.

---

## Controls

### Touch Input
- **Main Menu**:
  - Tap **Play vs Computer** card to start or resume a game.
  - Tap **Daily Puzzle** card to practice tactics.
  - Tap **Sleep Screen** button to toggle CrossPoint sleep screen takeover.
  - Drag from the left edge rightward to exit.
- **Game Setup**:
  - Select Side: **White** (move first) or **Black** (computer moves first).
  - Select Difficulty: **Easy**, **Medium**, or **Hard**.
  - Tap **Start Game** to begin.
- **Play Screen**:
  - **Tap Piece**: Selects piece and highlights legal destination squares.
  - **Tap Square**: Moves piece to chosen destination.
  - **Undo**: Takes back the last turn.
  - **New Game**: Returns to setup to start a new match.
  - **Flip Board**: Rotates the board perspective 180 degrees.
  - **< Menu**: Returns to main menu (game state is saved).
- **Navigation Gesture**:
  - Swipe right from the left screen edge (x <= 60px) to navigate back from any screen.

### Physical Hardware Buttons
- **`CONFIRM` (Enter / Space)**: Resets puzzle in puzzle mode.
- **`BACK` (Escape / Backspace)**: Returns to main menu from subviews, or exits to CrossPoint launcher from main menu.

---

## File Structure

```text
apps/chess/
├── manifest.json       # App metadata, landscape orientation, and sleep screen flag
├── main.lua            # Lean main coordinator and lifecycle hooks
├── engine.lua          # Pure-Lua FIDE chess engine, move generator, and minimax AI
├── pieces.lua          # 1-bit monochrome piece bitmap sprites (40x40 ink & mask)
├── json.lua            # Pure-Lua JSON parser and serializer
├── ui.lua              # UI components, button helpers, and chessboard rendering
├── daily.json          # Bundled offline fallback puzzle dataset
├── test_chess.lua      # Standalone unit test suite
├── views/
│   ├── menu.lua        # Main menu dashboard view
│   ├── setup.lua       # Match configuration view
│   ├── game.lua        # Play vs Computer active match view & controller
│   ├── puzzle.lua      # Daily puzzle solver view & controller
│   └── sleep.lua       # Ambient sleep screen renderer
└── README.md           # Documentation
```

---

## Testing & Simulator

Run the automated test suite:
```bash
lua apps/chess/test_chess.lua
```

Launch in the CrossPoint desktop simulator:
```bash
./sdk/run apps/chess
```

Run headless performance profiling:
```bash
./sdk/run --profile apps/chess
```

---

## Credits & Artwork

- **Chess Piece Vectors**: Derived from Colin M.L. Burnett's (Cburnett) standard Staunton chess piece set (used on Wikipedia and Lichess), licensed under CC BY-SA 3.0 and GPLv3.
- **Daily Puzzles**: Powered by the [Lichess.org Daily Puzzle API](https://lichess.org/api#tag/Puzzles/operation/apiPuzzleDaily).
