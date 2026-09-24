# Tally Counter 🔢

A persistent touch and button tally counter application for CrossPoint Reader (ESP32-S3 / E-Ink).

![Category](https://img.shields.io/badge/Category-Utilities-blue)
![Orientation](https://img.shields.io/badge/Orientation-Portrait%20(480x800)-green)
![Version](https://img.shields.io/badge/Version-1.0.2-orange)

---

## Overview

**Tally Counter** is a minimalist, battery-friendly handheld tally counter. Designed for low latency and high tactile readability on 480×800 portrait E-Ink screens, it provides large touch zones for one-handed counting and full hardware button support.

State is continuously saved to sandboxed SD card storage (`storage.writeFile("count.txt", ...)`), ensuring counts are never lost across power cycles or reboots.

---

## Features

- **Large Touch Targets**: Generous top and bottom split-screen touch regions for rapid incrementing and decrementing.
- **Hardware Button Support**: Increment or decrement using side buttons without looking at the screen.
- **Configurable Step Size**: Increment or decrement by ±1, ±5, or ±10.
- **Persistent SD Storage**: Automatically stores count and step settings to `/apps/counter/count.txt`.
- **E-Ink Sleep Screen Takeover (`onSleepDraw`)**: Sets the sleep screen to show the current tally count in a large, readable format, turning the reader into a persistent low-power counter desk display.
- **Quick Reset**: Long-press confirmation or dedicated reset button with safety threshold.

---

## Controls

### Touch Input
- **Top Region / Large `+`**: Increments the tally count by current step size.
- **Bottom Region / `-`**: Decrements the tally count by current step size.
- **Reset Button**: Resets tally to zero.
- **Step Buttons**: Selects step increment (`1`, `5`, `10`).

### Physical Hardware Buttons
- **`BTN_UP` / `BTN_PAGE_BACK`**: Increment tally.
- **`BTN_DOWN` / `BTN_PAGE_FORWARD`**: Decrement tally.
- **`CONFIRM`**: Increment tally.
- **`BACK`**: Exits the app back to the CrossPoint launcher.

---

## File Structure

```text
apps/counter/
├── manifest.json       # App metadata, portrait orientation, and sleep screen flag
├── main.lua            # Lifecycle hooks, touch/button handlers, and rendering
└── README.md           # This documentation
```

---

## Testing in Simulator

Test and run Tally Counter on your computer using the CrossPoint SDK:

```bash
# Launch Tally Counter in portrait mode
./sdk/run apps/counter

# Generate a screenshot of the main counter UI
./sdk/run --screenshot /tmp/counter.bmp apps/counter

# Preview the sleep screen rendering
./sdk/run --screenshot-sleep /tmp/counter_sleep.bmp apps/counter
```
