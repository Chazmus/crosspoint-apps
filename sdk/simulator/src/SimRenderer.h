#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace sim {

enum class Color : uint8_t {
  Black = 0,
  DarkGray = 1,
  LightGray = 2,
  White = 3,
};

enum class Orientation : uint8_t {
  Portrait = 0,
  Landscape = 1,
  PortraitInverted = 2,
  LandscapeCounterClockwise = 3,
};

class FontRenderer;

class SimRenderer {
 public:
  static constexpr int PORTRAIT_WIDTH = 480;
  static constexpr int PORTRAIT_HEIGHT = 800;
  static constexpr int LANDSCAPE_WIDTH = 800;
  static constexpr int LANDSCAPE_HEIGHT = 480;

  // Defaults to portrait to match physical device default
  SimRenderer(FontRenderer& fontRenderer, int width = PORTRAIT_WIDTH, int height = PORTRAIT_HEIGHT);

  void setDimensions(int w, int h);
  void setOrientation(Orientation o);
  Orientation getOrientation() const { return orientation_; }

  void clearScreen(uint8_t color = 1);  // 1 = White, 0 = Black
  void drawPixel(int x, int y, bool black = true);
  void drawLine(int x1, int y1, int x2, int y2, int lineWidth = 1, bool black = true);
  void drawRect(int x, int y, int w, int h, int lineWidth = 1, bool black = true);
  void fillRect(int x, int y, int w, int h, bool black = true);
  void fillRectDither(int x, int y, int w, int h, Color color);
  void drawRoundedRect(int x, int y, int w, int h, int radius, int lineWidth = 1, bool black = true);
  void fillRoundedRect(int x, int y, int w, int h, int radius, Color color = Color::Black);
  void drawCircle(int cx, int cy, int r, int lineWidth = 1, bool black = true);
  void fillCircle(int cx, int cy, int r, bool black = true);

  void drawText(int fontId, int x, int y, const std::string& text, bool black = true);
  void drawCenteredText(int fontId, int y, const std::string& text, bool black = true);
  int getTextWidth(int fontId, const std::string& text);
  int getLineHeight(int fontId);

  bool drawBitmapFile(int x, int y, const std::string& fullPath);
  void drawSprite(int x, int y, int w, int h, const uint8_t* ink, const uint8_t* sil);
  bool saveBmp(const std::string& path) const;

  const uint32_t* getPixels() const { return pixels_.data(); }
  uint32_t* getPixels() { return pixels_.data(); }

  int getWidth() const { return width_; }
  int getHeight() const { return height_; }

 private:
  FontRenderer& fontRenderer_;
  int width_ = PORTRAIT_WIDTH;
  int height_ = PORTRAIT_HEIGHT;
  Orientation orientation_ = Orientation::Portrait;
  std::vector<uint32_t> pixels_;

  static constexpr uint32_t COLOR_ARGB_WHITE = 0xFFFBFBFB;
  static constexpr uint32_t COLOR_ARGB_BLACK = 0xFF181818;
  static constexpr uint32_t COLOR_ARGB_DARK_GRAY = 0xFF585858;
  static constexpr uint32_t COLOR_ARGB_LIGHT_GRAY = 0xFFB0B0B0;

  inline uint32_t resolveColor(Color col) const {
    switch (col) {
      case Color::Black: return COLOR_ARGB_BLACK;
      case Color::DarkGray: return COLOR_ARGB_DARK_GRAY;
      case Color::LightGray: return COLOR_ARGB_LIGHT_GRAY;
      case Color::White: return COLOR_ARGB_WHITE;
    }
    return COLOR_ARGB_BLACK;
  }
};

}  // namespace sim
