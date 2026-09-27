# UI Kit Test (`uitest`)

Test harness and component showcase for native `FreeInkUI` controls in the CrossPoint Lua application runtime.

---

## Overview

`uitest` exercises the Phase 1 `ui.*` component bindings:
- **`ui.drawHeader`**: Navigation title, theme border, battery indicator, and action icons.
- **`ui.drawTabBar`**: Segmented tab controls with theme pill styling and `onSelect` callback dispatching.
- **`ui.drawCard`**: Outlined, filled, and dithered container cards with theme corner radii and click handling.
- **`ui.drawButton`**: Primary, secondary, and ghost variant buttons with hit testing.
- **`ui.drawBadge`**: Solid, outline, and dither status badges.
- **`ui.drawToggle`**: Interactive switch toggles with boolean state.
- **`ui.drawDialog`**: Modal dialog boxes with action buttons and background dimming.
- **`ui.drawToast`**: Notification toasts.

---

## Running in the Simulator

```bash
./sdk/run apps/uitest
```
