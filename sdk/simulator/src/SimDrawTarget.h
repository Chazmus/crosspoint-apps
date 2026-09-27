#pragma once

#include <FreeInkUICore.h>
#include "FontRenderer.h"
#include "SimRenderer.h"

namespace sim {

class SimDrawTarget final : public freeink::ui::DrawTarget {
 public:
  static constexpr freeink::ui::FontId FONT_SMALL = 0;
  static constexpr freeink::ui::FontId FONT_BODY = 1;
  static constexpr freeink::ui::FontId FONT_TITLE = 2;
  static constexpr freeink::ui::FontId FONT_LABEL = 3;

  SimDrawTarget(SimRenderer& renderer, FontRenderer& fontRenderer);

  freeink::ui::Rect clipRect() const override { return clip_; }
  bool setClipRect(freeink::ui::Rect rect) override {
    clip_ = rect;
    return true;
  }

  freeink::ui::Size measureText(freeink::ui::FontId font, const char* text,
                                freeink::ui::TextStyle style) const override;
  int16_t lineHeight(freeink::ui::FontId font) const override;

  void fill(freeink::ui::Rect rect, freeink::ui::Paint paint, uint8_t radius = 0,
            uint8_t corners = freeink::ui::CornersAll) override;
  void stroke(freeink::ui::Rect rect, freeink::ui::Paint paint, uint8_t width, uint8_t radius = 0,
              uint8_t corners = freeink::ui::CornersAll) override;
  void line(freeink::ui::Point from, freeink::ui::Point to, uint8_t width, freeink::ui::Paint paint) override;
  void triangle(freeink::ui::Point a, freeink::ui::Point b, freeink::ui::Point c, freeink::ui::Paint paint) override;
  void text(freeink::ui::Rect rect, const char* text, freeink::ui::TextStyle style) override;
  void bitmap(freeink::ui::Rect rect, freeink::ui::BitmapRef bitmap, freeink::ui::BitmapMode mode,
              freeink::ui::Paint foreground = freeink::ui::Paint::solid(freeink::ui::Color::Black),
              freeink::ui::Rotation rotation = freeink::ui::Rotation::None) override;

  freeink::ui::DeviceContext deviceContext() const;
  int resolveFontId(freeink::ui::FontId slot) const;

 private:
  SimRenderer& renderer_;
  FontRenderer& fontRenderer_;
  freeink::ui::Rect clip_{0, 0, 32767, 32767};
};

}  // namespace sim
