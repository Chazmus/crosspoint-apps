#include "SimDrawTarget.h"

#include <cmath>
#include <algorithm>

namespace sim {

SimDrawTarget::SimDrawTarget(SimRenderer& renderer, FontRenderer& fontRenderer)
    : renderer_(renderer), fontRenderer_(fontRenderer) {}

int SimDrawTarget::resolveFontId(freeink::ui::FontId slot) const {
  switch (slot) {
    case FONT_SMALL:
      return FONT_UI_10_ID;
    case FONT_BODY:
      return FONT_NOTOSERIF_12_ID;
    case FONT_TITLE:
      return FONT_NOTOSANS_14_ID;
    case FONT_LABEL:
      return FONT_UI_10_ID;
    default:
      return FONT_NOTOSANS_12_ID;
  }
}

freeink::ui::Size SimDrawTarget::measureText(freeink::ui::FontId font, const char* text,
                                             freeink::ui::TextStyle style) const {
  if (!text || !*text) return {0, 0};
  const int fid = resolveFontId(font);
  const int w = fontRenderer_.getTextWidth(fid, text);
  const int h = fontRenderer_.getLineHeight(fid);
  return {static_cast<int16_t>(w), static_cast<int16_t>(h)};
}

int16_t SimDrawTarget::lineHeight(freeink::ui::FontId font) const {
  const int fid = resolveFontId(font);
  return static_cast<int16_t>(fontRenderer_.getLineHeight(fid));
}

void SimDrawTarget::fill(freeink::ui::Rect rect, freeink::ui::Paint paint, uint8_t radius, uint8_t /*corners*/) {
  if (paint.kind == freeink::ui::PaintKind::None || rect.empty()) return;
  if (paint.kind == freeink::ui::PaintKind::Dither) {
    renderer_.fillRectDither(rect.x, rect.y, rect.width, rect.height, Color::LightGray);
    return;
  }

  const bool isBlack = (paint.color == freeink::ui::Color::Black);
  if (radius > 0) {
    renderer_.fillRoundedRect(rect.x, rect.y, rect.width, rect.height, radius,
                              isBlack ? Color::Black : Color::White);
  } else {
    renderer_.fillRect(rect.x, rect.y, rect.width, rect.height, isBlack);
  }
}

void SimDrawTarget::stroke(freeink::ui::Rect rect, freeink::ui::Paint paint, uint8_t width, uint8_t radius,
                           uint8_t /*corners*/) {
  if (paint.kind == freeink::ui::PaintKind::None || width == 0 || rect.empty()) return;
  const bool isBlack = (paint.color == freeink::ui::Color::Black);
  if (radius > 0) {
    renderer_.drawRoundedRect(rect.x, rect.y, rect.width, rect.height, radius, width, isBlack);
  } else {
    renderer_.drawRect(rect.x, rect.y, rect.width, rect.height, width, isBlack);
  }
}

void SimDrawTarget::line(freeink::ui::Point from, freeink::ui::Point to, uint8_t width, freeink::ui::Paint paint) {
  if (paint.kind == freeink::ui::PaintKind::None || width == 0) return;
  const bool isBlack = (paint.color == freeink::ui::Color::Black);
  renderer_.drawLine(from.x, from.y, to.x, to.y, width, isBlack);
}

void SimDrawTarget::triangle(freeink::ui::Point a, freeink::ui::Point b, freeink::ui::Point c,
                             freeink::ui::Paint paint) {
  if (paint.kind == freeink::ui::PaintKind::None) return;
  const bool isBlack = (paint.color == freeink::ui::Color::Black);
  renderer_.drawLine(a.x, a.y, b.x, b.y, 1, isBlack);
  renderer_.drawLine(b.x, b.y, c.x, c.y, 1, isBlack);
  renderer_.drawLine(c.x, c.y, a.x, a.y, 1, isBlack);
}

void SimDrawTarget::text(freeink::ui::Rect rect, const char* text, freeink::ui::TextStyle style) {
  if (!text || !*text || rect.empty()) return;
  freeink::ui::layoutText(*this, rect, text, style, [&](const char* line, freeink::ui::Rect r) {
    const int fid = resolveFontId(style.font);
    const bool isBlack = (style.color == freeink::ui::Color::Black);
    renderer_.drawText(fid, r.x, r.y, line, isBlack);
  });
}

void SimDrawTarget::bitmap(freeink::ui::Rect rect, freeink::ui::BitmapRef bitmap, freeink::ui::BitmapMode mode,
                           freeink::ui::Paint foreground, freeink::ui::Rotation rotation) {
  if (!bitmap || rect.empty()) return;
  const bool isBlack = (foreground.color == freeink::ui::Color::Black);
  freeink::ui::forEachBitmapPixel(
      rect, bitmap, mode,
      [&](const int16_t px, const int16_t py) {
        renderer_.drawPixel(px, py, isBlack);
      },
      rotation);
}

freeink::ui::DeviceContext SimDrawTarget::deviceContext() const {
  freeink::ui::DeviceContext device;
  device.width = static_cast<int16_t>(renderer_.getWidth());
  device.height = static_cast<int16_t>(renderer_.getHeight());
  device.orientation = (renderer_.getOrientation() == Orientation::Landscape)
                           ? freeink::ui::Orientation::LandscapeClockwise
                           : freeink::ui::Orientation::Portrait;
  device.touchOrientation = device.orientation;
  device.hasButtons = true;
  device.hasTouch = true;
  device.minTouchSize = 44;
  device.safeArea = freeink::ui::Insets{0, 0, 0, 0};
  return device;
}

}  // namespace sim
