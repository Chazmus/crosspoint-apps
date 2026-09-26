# Spell Counter 🧙‍♂️

A feature-rich Magic: The Gathering (MTG) life and counter tracking application for CrossPoint Reader (ESP32-S3 / E-Ink).

![Category](https://img.shields.io/badge/Category-Games%20%26%20Utilities-blue)
![Orientation](https://img.shields.io/badge/Orientation-Landscape%20(800x480)-green)
![Version](https://img.shields.io/badge/Version-1.0.7-orange)

---

## Overview

**Spell Counter** is designed specifically for Commander (EDH) and multiplayer MTG games on 800×480 E-Ink displays. Inspired by popular MTG tracking apps, it features high contrast, battery-efficient rendering, zero glare in direct sunlight, and complete persistence across power interruptions.

It supports 1 to 4 players with configurable card themes, commander damage matrices, poison/energy/experience counters, dice rolling (D6 and D20), coin flips, monarch and initiative tracking, and an ambient sleep screen match summary.

---

## Features

### 1. Multiplayer Grid & Layouts
- **1 to 4 Players**: Seamless switching between 1-player, 2-player (side-by-side or face-to-face), 3-player, and 4-player quadrant layouts.
- **Starting Life Presets**: Quick switching between 20 (Standard), 30 (Two-Headed Giant), and 40 (Commander) starting life totals.
- **High-Contrast Cards**: Solid borders, large bold life totals, and customizable dark/light card backgrounds per player.

### 2. Life & Delta Tracking
- **Quick Tap (±1)**: Tap the `-` (left) or `+` (right) side of any player's card to increment or decrement life by 1.
- **Press & Hold (±10)**: Press and hold on `-` or `+` for $\ge 500\text{ms}$ to start rapidly ticking life by $\pm 10$ once every second while held. Lifting your finger cleanly stops ticking without triggering an accidental single tap.
- **Delta Overlay**: Displays recent net life changes (e.g. `+1` or `+20`) that automatically clear after inactivity.

### 3. Comprehensive Player Counters (`...` Modal)
- **Commander Damage Matrix**: Track 21 lethal commander combat damage dealt to each player by every opponent, with an optional toggle to automatically deduct commander damage from total life.
- **Poison Counters**: Tracks lethal infect/poison (10 threshold indicator).
- **Commander Tax**: Tracks cast tax increments (+2 mana per cast).
- **Energy Counters & Experience Points**: Individual energy and XP counters.
- **Storm Counter**: Dedicated storm count tracker with 1-tap reset.
- **Player Names**: Customizable player labels (Player 1–4, P1–P4, or commander color identities).

### 4. Game Tools Modal (`🎲` Button)
- **Dice Roller**: D6 and D20 roll generators with history logs.
- **Coin Flipper**: Heads / Tails generator with recent flip sequence.
- **Monarch & Initiative**: Single-tap claim and crown indicators displayed directly on the winning player's card.
- **Reset Game**: Confirmed full reset of all life totals and counters to match start.

### 5. Settings Modal (`⚙️` Button)
- Player count selector (1–4).
- Starting life selector (20, 30, 40).
- Sleep screen toggle.

### 6. Ambient Sleep Screen (`onSleepDraw`)
When the reader goes to sleep during a game, Spell Counter renders a crisp, battery-free match status board showing current player life totals, poison counts, commander damage, and monarch status.

---

## Architecture & Code Organization

Spell Counter is structured into decoupled, testable modules using Lua 5.4 `require()`:

```text
apps/spellcounter/
├── manifest.json              # App metadata, landscape orientation, sleep flag
├── main.lua                   # Concise lifecycle coordinator and top-level router
├── modal_manager.lua          # Modal dialog manager and tools actions coordinator
├── hold_handler.lua           # Touch-and-hold gesture engine for rapid ±10 ticking
├── state.lua                  # Game state engine, validation, and JSON SD persistence
├── ui.lua                     # Shared UI drawing components (buttons, cards, fonts)
├── json.lua                   # Pure-Lua JSON serializer for SD storage
├── views/
│   ├── grid.lua               # Player grid layouts (1P, 2P, 3P, 4P) and card rendering
│   ├── player_modal.lua       # Player detail dialog (Cmdr damage, poison, storm, tax)
│   ├── tools_modal.lua        # Tools dialog (Dice roller, coin flip, monarch claim)
│   ├── settings_modal.lua     # Settings dialog (Player count, starting life, sleep toggle)
│   └── sleep_view.lua         # E-Ink sleep screen match summary renderer
├── test_spellcounter.lua      # Comprehensive headless unit test suite (93 test cases)
└── README.md                  # This documentation
```

---

## Controls

### Touch Input
- **Tap `+` / `-`**: Adjusts player life by ±1.
- **Press & Hold `+` / `-`**: Ticks player life by ±10 (once per second while held).
- **Tap `...` (top-right of player card)**: Opens player details (commander damage, poison, storm, tax). Features a generous touch target (>= 76×54px) for reliable tapping on capacitive E-Ink screens.
- **Tap `🎲` (Tools, top right)**: Opens Dice / Coin / Monarch modal.
- **Tap `Reset` (top right)**: Prompts to reset the current match.

### Physical Hardware Buttons
- **`CONFIRM`**: Opens Game Tools modal.
- **`BACK`**: Closes active modal, or exits to CrossPoint launcher if no modal is open.
- **`BTN_UP` / `BTN_DOWN`**: Quick life adjustment for Player 1.

---

## Testing & Verification

### Running the Headless Unit Test Suite
Spell Counter includes a comprehensive automated test suite verifying state integrity, boundary clamps, touch hit tests, modal flows, and nil safety:

```bash
lua apps/spellcounter/test_spellcounter.lua
```

### Desktop Simulator
Test touch interactions and layouts interactively on PC:

```bash
# Launch Spell Counter
./sdk/run apps/spellcounter

# Generate a screenshot of the 4-player game grid
./sdk/run --screenshot /tmp/spellcounter.bmp apps/spellcounter

# Preview the sleep screen match summary
./sdk/run --screenshot-sleep /tmp/spellcounter_sleep.bmp apps/spellcounter

# Run live performance profiling
./sdk/run --profile apps/spellcounter
```
