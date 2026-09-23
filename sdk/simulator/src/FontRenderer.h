#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace sim {

// Standard CrossPoint font hash IDs
static constexpr int FONT_UI_10_ID = 1322569422;
static constexpr int FONT_UI_12_ID = 1831230762;
static constexpr int FONT_SMALL_ID = 1465627787;
static constexpr int FONT_NOTOSANS_12_ID = 1597191560;
static constexpr int FONT_NOTOSANS_14_ID = -1413326613;
static constexpr int FONT_NOTOSANS_16_ID = 116566294;
static constexpr int FONT_NOTOSANS_18_ID = -348426591;
static constexpr int FONT_NOTOSERIF_12_ID = 778531645;
static constexpr int FONT_NOTOSERIF_14_ID = -928381217;
static constexpr int FONT_NOTOSERIF_16_ID = 17214534;
static constexpr int FONT_NOTOSERIF_18_ID = 840051567;

struct FontInfo;

class FontRenderer {
 public:
  FontRenderer();
  ~FontRenderer();

  bool loadFonts(const std::string& assetsDir);

  int getTextWidth(int fontId, const std::string& text);
  int getLineHeight(int fontId);
  int getAscender(int fontId);

  void drawText(int fontId, int x, int y, const std::string& text, bool black, uint32_t* pixels, int screenW, int screenH);
  void drawCenteredText(int fontId, int y, const std::string& text, bool black, uint32_t* pixels, int screenW, int screenH);

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace sim
