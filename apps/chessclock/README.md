# Chess Clock ⏱️

A two-player over-the-board chess clock for CrossPoint Reader (ESP32-S3 / E-Ink).

![Category](https://img.shields.io/badge/Category-Games%20%26%20Utilities-blue)
![Orientation](https://img.shields.io/badge/Orientation-Landscape%20(800x480)-green)
![Version](https://img.shields.io/badge/Version-1.0.1-orange)

---

## Overview

**Chess Clock** turns the reader into a shared clock for two players sitting opposite each other across a real chess board. The screen splits into two half-screen panels: the near player's panel renders upright, the far player's panel is rendered **180° rotated** (custom 7-segment clock digits and a 5×7 bitmap label font, flipped at blit time), so both players read their own clock right-side up from their seat.

Supports standard time controls (bullet / blitz / rapid / classic presets), Fischer increment, tenths display under 10 seconds, pause/resume, seat swapping, flag detection with a result dialog, rematch, and a full game-state persistence across sleep and power-off.

---

## Features

### 1. Face-to-Face Two-Panel Clock
- **Split-screen landscape layout**: bottom panel faces the near player (native fonts), top panel faces the opponent across the board (flipped rendering).
- **Inverted active panel**: whoever's clock is running gets a solid black card with white digits — instantly visible from across the table.
- **SWAP** button flips the seat mapping for players who want White on the far side.

### 2. Time Controls
- **10 presets**: 1+0, 2+1, 3+0, 3+2, 5+0, 5+3, 10+0, 10+5, 15+10, 30+0.
- **Custom stepper**: 1–180 minutes, 0–60s increment.
- **Fischer increment**: the mover receives the increment after each completed move.

### 3. Clock Behavior
- **First tap starts White** regardless of which panel is tapped (standard chess clock behavior).
- **Tap your own panel** when it's running to complete your move (gain increment, pass the turn).
- **Tenths display**: the running clock switches from `M:SS` to tenths (`9.5`) under 10 seconds.
- **Flag**: when a clock hits zero the app freezes, marks the flagged side, and shows a `FLAG` result dialog with **REMATCH** / **SETUP** actions.
- **Move counter** per player in the panel corner.

### 4. Persistence & Power Discipline
- Game state (phase, times, control, seats, move counts) persists to SD and survives restarts.
- A game saved mid-turn reloads as **paused** — never silently resuming after an unknown outage.
- Elapsed think time commits to storage every 10 seconds while running, so a dead battery costs at most ~10 seconds.
- `millis()` wrap and stale baselines re-baseline instead of charging phantom time.

### 5. Sleep Screen
A static `onSleepDraw()` board showing both clocks, the control label, and the flagged state — rendered once, zero animation, battery-free on E-Ink.

---

## Architecture & Code Organization

```text
apps/chessclock/
├── manifest.json              # App metadata, landscape orientation, sleep flag
├── main.lua                   # Lifecycle coordinator, view/modal router, input mapping
├── state.lua                  # Clock engine: ms-domain timing, Fischer increment, JSON persistence
├── flipgfx.lua                # Upside-down rendering: 7-segment digits + 5x7 bitmap font
├── json.lua                   # Pure-Lua JSON serializer for SD storage
├── views/
│   ├── clock.lua              # Two-panel layout, panel drawing, header buttons, hit tests
│   ├── setup.lua              # Time-control list, custom steppers, seat toggle, start button
│   ├── modals.lua             # Menu / flag result / reset confirm dialogs
│   └── sleep_view.lua         # E-Ink sleep screen renderer
├── test_chessclock.lua        # Headless unit test suite (151 test cases)
└── README.md                  # This documentation
```

**Design note — no rotated-text API**: the Lua surface (firmware and simulator) exposes no rotated text, so the far panel's digits use the 7-segment trick (each active segment rectangle is rotated 180° about the digit cell center) and labels use a 5×7 bitmap font whose rows, columns, and character order are all reversed at blit time — a true 180° rotation, verified pixel-exact against the simulator output.

---

## Controls

### Touch
- **Tap your half of the screen** (the half facing you): completes your move — adds increment and starts the opponent's clock.
- **First tap anywhere** starts White's clock from the ready state.
- **Tap PAUSE** (header left) while running: freezes both clocks; tap again to resume.
- **SWAP** (header): flips which side White sits on.
- **MENU** (header): rematch, setup, or close.

### Physical Buttons
- **CONFIRM**: pause/resume the running clock.
- **UP / DOWN / PAGE BACK / PAGE FORWARD**: quick turn switch.
- **BACK**: close modal → back from setup → exit to launcher.

---

## Testing & Verification

### Headless unit tests
```bash
lua apps/chessclock/test_chessclock.lua
```
151 cases covering state transitions, exact ms charging, Fischer increment, flag detection, pause/resume rebaselining, millis-wrap safety, persistence round-trips, hostile-input clamping, touch hit tests, and rendering under corrupted state.

### Desktop simulator
```bash
./sdk/run apps/chessclock                                     # interactive
./sdk/run --screenshot /tmp/chessclock_frame.bmp apps/chessclock
./sdk/run --screenshot-sleep /tmp/chessclock_sleep.bmp apps/chessclock
./sdk/run --profile apps/chessclock
```
