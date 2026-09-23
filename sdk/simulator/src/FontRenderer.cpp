#include "FontRenderer.h"

#include <cmath>
#include <fstream>
#include <iostream>
#include <memory>
#include <unordered_map>

#define STB_TRUETYPE_IMPLEMENTATION
#include "../stb/stb_truetype.h"

namespace sim {

struct LoadedFont {
  std::shared_ptr<std::vector<uint8_t>> buffer;
  stbtt_fontinfo info;
  float scale = 1.0f;
  int ascent = 0;
  int descent = 0;
  int lineGap = 0;
  int lineHeight = 16;
  int pixelHeight = 16;
};

struct FontRenderer::Impl {
  std::unordered_map<int, LoadedFont> fonts;
  int defaultFontId = FONT_UI_10_ID;

  std::shared_ptr<std::vector<uint8_t>> loadTtf(const std::string& path) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file) {
      std::cerr << "[FontRenderer] Cannot open font file: " << path << std::endl;
      return nullptr;
    }
    const std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);
    auto buf = std::make_shared<std::vector<uint8_t>>(size);
    if (!file.read(reinterpret_cast<char*>(buf->data()), size)) {
      std::cerr << "[FontRenderer] Failed to read font file: " << path << std::endl;
      return nullptr;
    }
    return buf;
  }

  void configureFont(int fontId, std::shared_ptr<std::vector<uint8_t>> buf, int pixelHeight) {
    if (!buf || buf->empty()) return;
    LoadedFont lf;
    lf.buffer = buf;
    if (!stbtt_InitFont(&lf.info, lf.buffer->data(), stbtt_GetFontOffsetForIndex(lf.buffer->data(), 0))) {
      std::cerr << "[FontRenderer] Failed to initialize TTF for font ID: " << fontId << std::endl;
      return;
    }
    lf.pixelHeight = pixelHeight;
    lf.scale = stbtt_ScaleForPixelHeight(&lf.info, static_cast<float>(pixelHeight));

    int a, d, lg;
    stbtt_GetFontVMetrics(&lf.info, &a, &d, &lg);
    lf.ascent = static_cast<int>(std::round(a * lf.scale));
    lf.descent = static_cast<int>(std::round(d * lf.scale));
    lf.lineGap = static_cast<int>(std::round(lg * lf.scale));
    lf.lineHeight = lf.ascent - lf.descent + lf.lineGap;
    if (lf.lineHeight <= 0) lf.lineHeight = pixelHeight + 4;

    fonts[fontId] = std::move(lf);
  }

  LoadedFont* getFont(int fontId) {
    auto it = fonts.find(fontId);
    if (it != fonts.end()) return &it->second;
    auto defIt = fonts.find(defaultFontId);
    if (defIt != fonts.end()) return &defIt->second;
    if (!fonts.empty()) return &fonts.begin()->second;
    return nullptr;
  }
};

FontRenderer::FontRenderer() : impl_(std::make_unique<Impl>()) {}
FontRenderer::~FontRenderer() = default;

bool FontRenderer::loadFonts(const std::string& assetsDir) {
  const std::string sansPath = assetsDir + "/fonts/NotoSans-Regular.ttf";
  const std::string sansBoldPath = assetsDir + "/fonts/NotoSans-Bold.ttf";
  const std::string serifPath = assetsDir + "/fonts/NotoSerif-Regular.ttf";

  auto sansBuf = impl_->loadTtf(sansPath);
  auto sansBoldBuf = impl_->loadTtf(sansBoldPath);
  auto serifBuf = impl_->loadTtf(serifPath);

  if (!sansBuf && !sansBoldBuf && !serifBuf) {
    std::cerr << "[FontRenderer] Warning: No fonts could be loaded from " << assetsDir << std::endl;
    return false;
  }

  // Fallbacks if some files are missing
  auto uiSansBuf = sansBoldBuf ? sansBoldBuf : (sansBuf ? sansBuf : serifBuf);
  auto bodySansBuf = sansBuf ? sansBuf : uiSansBuf;
  auto serifBodyBuf = serifBuf ? serifBuf : bodySansBuf;

  // Map CrossPoint font IDs
  // UI_10: ~20px (line height 24)
  impl_->configureFont(FONT_UI_10_ID, uiSansBuf, 20);
  // UI_12: ~28px (line height 32)
  impl_->configureFont(FONT_UI_12_ID, uiSansBuf, 28);
  // SMALL: ~14px (line height 16)
  impl_->configureFont(FONT_SMALL_ID, bodySansBuf, 14);

  // Noto Sans sizes
  impl_->configureFont(FONT_NOTOSANS_12_ID, bodySansBuf, 22);
  impl_->configureFont(FONT_NOTOSANS_14_ID, bodySansBuf, 26);
  impl_->configureFont(FONT_NOTOSANS_16_ID, bodySansBuf, 30);
  impl_->configureFont(FONT_NOTOSANS_18_ID, bodySansBuf, 34);

  // Noto Serif sizes
  impl_->configureFont(FONT_NOTOSERIF_12_ID, serifBodyBuf, 22);
  impl_->configureFont(FONT_NOTOSERIF_14_ID, serifBodyBuf, 26);
  impl_->configureFont(FONT_NOTOSERIF_16_ID, serifBodyBuf, 30);
  impl_->configureFont(FONT_NOTOSERIF_18_ID, serifBodyBuf, 34);

  return true;
}

int FontRenderer::getTextWidth(int fontId, const std::string& text) {
  LoadedFont* font = impl_->getFont(fontId);
  if (!font) return static_cast<int>(text.size() * 10);

  float width = 0.0f;
  for (size_t i = 0; i < text.size(); ++i) {
    const char c = text[i];
    int advance, lsb;
    stbtt_GetCodepointHMetrics(&font->info, c, &advance, &lsb);
    width += advance * font->scale;
    if (i + 1 < text.size()) {
      width += stbtt_GetCodepointKernAdvance(&font->info, c, text[i + 1]) * font->scale;
    }
  }
  return static_cast<int>(std::round(width));
}

int FontRenderer::getLineHeight(int fontId) {
  LoadedFont* font = impl_->getFont(fontId);
  return font ? font->lineHeight : 20;
}

int FontRenderer::getAscender(int fontId) {
  LoadedFont* font = impl_->getFont(fontId);
  return font ? font->ascent : 16;
}

void FontRenderer::drawText(int fontId, int x, int y, const std::string& text, bool black, uint32_t* pixels,
                           int screenW, int screenH) {
  LoadedFont* font = impl_->getFont(fontId);
  if (!font || text.empty() || !pixels) return;

  // In CrossPoint, y is the top edge of the line box. Baseline is y + ascender.
  const int baselineY = y + font->ascent;
  float curX = static_cast<float>(x);

  const uint32_t targetColor = black ? 0xFF181818 : 0xFFFBFBFB;
  const uint8_t tr = (targetColor >> 16) & 0xFF;
  const uint8_t tg = (targetColor >> 8) & 0xFF;
  const uint8_t tb = targetColor & 0xFF;

  for (size_t i = 0; i < text.size(); ++i) {
    const char c = text[i];
    if (c == '\n') continue;

    int advance, lsb;
    stbtt_GetCodepointHMetrics(&font->info, c, &advance, &lsb);

    int c_x1, c_y1, c_x2, c_y2;
    stbtt_GetCodepointBitmapBox(&font->info, c, font->scale, font->scale, &c_x1, &c_y1, &c_x2, &c_y2);

    const int gw = c_x2 - c_x1;
    const int gh = c_y2 - c_y1;

    if (gw > 0 && gh > 0) {
      std::vector<uint8_t> bitmap(gw * gh);
      stbtt_MakeCodepointBitmap(&font->info, bitmap.data(), gw, gh, gw, font->scale, font->scale, c);

      const int drawX = static_cast<int>(std::round(curX)) + c_x1;
      const int drawY = baselineY + c_y1;

      for (int row = 0; row < gh; ++row) {
        const int py = drawY + row;
        if (py < 0 || py >= screenH) continue;

        for (int col = 0; col < gw; ++col) {
          const int px = drawX + col;
          if (px < 0 || px >= screenW) continue;

          const uint8_t alpha = bitmap[row * gw + col];
          if (alpha == 0) continue;

          const int idx = py * screenW + px;
          const uint32_t bg = pixels[idx];
          const uint8_t bgR = (bg >> 16) & 0xFF;
          const uint8_t bgG = (bg >> 8) & 0xFF;
          const uint8_t bgB = bg & 0xFF;

          // Alpha blend towards target e-ink tone
          const uint8_t outR = static_cast<uint8_t>((tr * alpha + bgR * (255 - alpha)) / 255);
          const uint8_t outG = static_cast<uint8_t>((tg * alpha + bgG * (255 - alpha)) / 255);
          const uint8_t outB = static_cast<uint8_t>((tb * alpha + bgB * (255 - alpha)) / 255);

          pixels[idx] = 0xFF000000 | (outR << 16) | (outG << 8) | outB;
        }
      }
    }

    curX += advance * font->scale;
    if (i + 1 < text.size()) {
      curX += stbtt_GetCodepointKernAdvance(&font->info, c, text[i + 1]) * font->scale;
    }
  }
}

void FontRenderer::drawCenteredText(int fontId, int y, const std::string& text, bool black, uint32_t* pixels,
                                   int screenW, int screenH) {
  const int textW = getTextWidth(fontId, text);
  const int x = (screenW - textW) / 2;
  drawText(fontId, x, y, text, black, pixels, screenW, screenH);
}

}  // namespace sim
