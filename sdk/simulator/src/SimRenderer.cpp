#include "SimRenderer.h"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <iostream>

#include "FontRenderer.h"
#include "qrcode.h"

namespace sim {

SimRenderer::SimRenderer(FontRenderer& fontRenderer, int width, int height)
    : fontRenderer_(fontRenderer), width_(width), height_(height), pixels_(width * height, COLOR_ARGB_WHITE) {}

void SimRenderer::setDimensions(int w, int h) {
  if (width_ == w && height_ == h) return;
  width_ = w;
  height_ = h;
  pixels_.assign(width_ * height_, COLOR_ARGB_WHITE);
}

void SimRenderer::setOrientation(Orientation o) {
  orientation_ = o;
  if (o == Orientation::Landscape || o == Orientation::LandscapeCounterClockwise) {
    setDimensions(LANDSCAPE_WIDTH, LANDSCAPE_HEIGHT);
  } else {
    setDimensions(PORTRAIT_WIDTH, PORTRAIT_HEIGHT);
  }
}

void SimRenderer::clearScreen(uint8_t color) {
  const uint32_t val = (color == 0) ? COLOR_ARGB_BLACK : COLOR_ARGB_WHITE;
  std::fill(pixels_.begin(), pixels_.end(), val);
}

void SimRenderer::drawPixel(int x, int y, bool black) {
  if (x >= 0 && x < width_ && y >= 0 && y < height_) {
    pixels_[y * width_ + x] = black ? COLOR_ARGB_BLACK : COLOR_ARGB_WHITE;
  }
}

void SimRenderer::drawLine(int x1, int y1, int x2, int y2, int lineWidth, bool black) {
  const uint32_t col = black ? COLOR_ARGB_BLACK : COLOR_ARGB_WHITE;
  const int dx = std::abs(x2 - x1);
  const int dy = std::abs(y2 - y1);
  const int sx = (x1 < x2) ? 1 : -1;
  const int sy = (y1 < y2) ? 1 : -1;
  int err = dx - dy;

  int x = x1;
  int y = y1;

  while (true) {
    if (lineWidth <= 1) {
      if (x >= 0 && x < width_ && y >= 0 && y < height_) {
        pixels_[y * width_ + x] = col;
      }
    } else {
      const int half = lineWidth / 2;
      for (int ox = -half; ox <= half; ++ox) {
        for (int oy = -half; oy <= half; ++oy) {
          const int px = x + ox;
          const int py = y + oy;
          if (px >= 0 && px < width_ && py >= 0 && py < height_) {
            pixels_[py * width_ + px] = col;
          }
        }
      }
    }

    if (x == x2 && y == y2) break;
    const int e2 = 2 * err;
    if (e2 > -dy) {
      err -= dy;
      x += sx;
    }
    if (e2 < dx) {
      err += dx;
      y += sy;
    }
  }
}

void SimRenderer::drawRect(int x, int y, int w, int h, int lineWidth, bool black) {
  if (w <= 0 || h <= 0) return;
  for (int i = 0; i < lineWidth; ++i) {
    drawLine(x, y + i, x + w - 1, y + i, 1, black);
    drawLine(x, y + h - 1 - i, x + w - 1, y + h - 1 - i, 1, black);
    drawLine(x + i, y, x + i, y + h - 1, 1, black);
    drawLine(x + w - 1 - i, y, x + w - 1 - i, y + h - 1, 1, black);
  }
}

void SimRenderer::fillRect(int x, int y, int w, int h, bool black) {
  if (w <= 0 || h <= 0) return;
  const uint32_t col = black ? COLOR_ARGB_BLACK : COLOR_ARGB_WHITE;
  const int xStart = std::max(0, x);
  const int xEnd = std::min(width_, x + w);
  const int yStart = std::max(0, y);
  const int yEnd = std::min(height_, y + h);

  for (int py = yStart; py < yEnd; ++py) {
    uint32_t* row = &pixels_[py * width_ + xStart];
    std::fill(row, row + (xEnd - xStart), col);
  }
}

void SimRenderer::fillRectDither(int x, int y, int w, int h, Color color) {
  if (w <= 0 || h <= 0) return;
  const int xStart = std::max(0, x);
  const int xEnd = std::min(width_, x + w);
  const int yStart = std::max(0, y);
  const int yEnd = std::min(height_, y + h);

  // 4-level e-ink 2x2 Bayer dither pattern
  static constexpr int bayer2x2[2][2] = {
      {0, 2},
      {3, 1},
  };

  const int threshold = (color == Color::LightGray) ? 1 : ((color == Color::DarkGray) ? 3 : 0);
  if (color == Color::Black) {
    fillRect(x, y, w, h, true);
    return;
  }
  if (color == Color::White) {
    fillRect(x, y, w, h, false);
    return;
  }

  for (int py = yStart; py < yEnd; ++py) {
    for (int px = xStart; px < xEnd; ++px) {
      const bool isBlack = (bayer2x2[py & 1][px & 1] < threshold);
      pixels_[py * width_ + px] = isBlack ? COLOR_ARGB_BLACK : COLOR_ARGB_WHITE;
    }
  }
}

void SimRenderer::drawRoundedRect(int x, int y, int w, int h, int radius, int lineWidth, bool black) {
  if (w <= 0 || h <= 0) return;
  radius = std::min(radius, std::min(w / 2, h / 2));
  if (radius <= 0) {
    drawRect(x, y, w, h, lineWidth, black);
    return;
  }

  // Draw 4 straight sides
  for (int i = 0; i < lineWidth; ++i) {
    drawLine(x + radius, y + i, x + w - 1 - radius, y + i, 1, black);
    drawLine(x + radius, y + h - 1 - i, x + w - 1 - radius, y + h - 1 - i, 1, black);
    drawLine(x + i, y + radius, x + i, y + h - 1 - radius, 1, black);
    drawLine(x + w - 1 - i, y + radius, x + w - 1 - i, y + h - 1 - radius, 1, black);
  }

  // Draw 4 corner arcs
  const auto drawCorner = [&](int cx, int cy, int quadX, int quadY) {
    int px = 0;
    int py = radius;
    int d = 3 - 2 * radius;
    while (py >= px) {
      for (int lw = 0; lw < lineWidth; ++lw) {
        drawPixel(cx + quadX * px, cy + quadY * (py - lw), black);
        drawPixel(cx + quadX * py, cy + quadY * (px - lw), black);
      }
      if (d < 0) {
        d += 4 * px + 6;
      } else {
        d += 4 * (px - py) + 10;
        py--;
      }
      px++;
    }
  };

  drawCorner(x + radius, y + radius, -1, -1);                  // Top-left
  drawCorner(x + w - 1 - radius, y + radius, 1, -1);          // Top-right
  drawCorner(x + radius, y + h - 1 - radius, -1, 1);          // Bottom-left
  drawCorner(x + w - 1 - radius, y + h - 1 - radius, 1, 1);  // Bottom-right
}

void SimRenderer::fillRoundedRect(int x, int y, int w, int h, int radius, Color color) {
  if (w <= 0 || h <= 0) return;
  radius = std::min(radius, std::min(w / 2, h / 2));
  if (radius <= 0) {
    if (color == Color::Black || color == Color::White) {
      fillRect(x, y, w, h, color == Color::Black);
    } else {
      fillRectDither(x, y, w, h, color);
    }
    return;
  }

  // Fill central body
  if (color == Color::Black || color == Color::White) {
    fillRect(x + radius, y, w - 2 * radius, h, color == Color::Black);
    fillRect(x, y + radius, radius, h - 2 * radius, color == Color::Black);
    fillRect(x + w - radius, y + radius, radius, h - 2 * radius, color == Color::Black);
  } else {
    fillRectDither(x + radius, y, w - 2 * radius, h, color);
    fillRectDither(x, y + radius, radius, h - 2 * radius, color);
    fillRectDither(x + w - radius, y + radius, radius, h - 2 * radius, color);
  }

  // Fill corner segments
  const uint32_t col = resolveColor(color);
  for (int cy = 0; cy < radius; ++cy) {
    const int span = static_cast<int>(std::round(std::sqrt(radius * radius - (radius - cy) * (radius - cy))));
    const int startOffset = radius - span;

    for (int cx = startOffset; cx < radius; ++cx) {
      // Top-left
      drawPixel(x + cx, y + cy, color == Color::Black);
      // Top-right
      drawPixel(x + w - 1 - cx, y + cy, color == Color::Black);
      // Bottom-left
      drawPixel(x + cx, y + h - 1 - cy, color == Color::Black);
      // Bottom-right
      drawPixel(x + w - 1 - cx, y + h - 1 - cy, color == Color::Black);
    }
  }
}

void SimRenderer::drawCircle(int cx, int cy, int r, int lineWidth, bool black) {
  if (r <= 0) return;
  int x = 0;
  int y = r;
  int d = 3 - 2 * r;

  while (y >= x) {
    for (int i = 0; i < lineWidth; ++i) {
      drawPixel(cx + x, cy + y - i, black);
      drawPixel(cx - x, cy + y - i, black);
      drawPixel(cx + x, cy - y + i, black);
      drawPixel(cx - x, cy - y + i, black);
      drawPixel(cx + y - i, cy + x, black);
      drawPixel(cx - y + i, cy + x, black);
      drawPixel(cx + y - i, cy - x, black);
      drawPixel(cx - y + i, cy - x, black);
    }
    if (d < 0) {
      d += 4 * x + 6;
    } else {
      d += 4 * (x - y) + 10;
      y--;
    }
    x++;
  }
}

void SimRenderer::fillCircle(int cx, int cy, int r, bool black) {
  if (r <= 0) return;
  for (int dy = -r; dy <= r; ++dy) {
    const int dx = static_cast<int>(std::round(std::sqrt(r * r - dy * dy)));
    drawLine(cx - dx, cy + dy, cx + dx, cy + dy, 1, black);
  }
}

void SimRenderer::drawText(int fontId, int x, int y, const std::string& text, bool black) {
  fontRenderer_.drawText(fontId, x, y, text, black, pixels_.data(), width_, height_);
}

void SimRenderer::drawCenteredText(int fontId, int y, const std::string& text, bool black) {
  fontRenderer_.drawCenteredText(fontId, y, text, black, pixels_.data(), width_, height_);
}

int SimRenderer::getTextWidth(int fontId, const std::string& text) {
  return fontRenderer_.getTextWidth(fontId, text);
}

int SimRenderer::getLineHeight(int fontId) {
  return fontRenderer_.getLineHeight(fontId);
}

bool SimRenderer::drawBitmapFile(int x, int y, const std::string& fullPath) {
  std::ifstream file(fullPath, std::ios::binary);
  if (!file) return false;

  uint8_t header[54];
  if (!file.read(reinterpret_cast<char*>(header), 54)) return false;
  if (header[0] != 'B' || header[1] != 'M') return false;

  const int32_t width = *reinterpret_cast<int32_t*>(&header[18]);
  const int32_t height = *reinterpret_cast<int32_t*>(&header[22]);
  const uint16_t bpp = *reinterpret_cast<uint16_t*>(&header[28]);
  const uint32_t dataOffset = *reinterpret_cast<uint32_t*>(&header[10]);

  if (width <= 0 || height <= 0 || bpp != 24) {
    // Basic 24-bit BMP support for sim
    return false;
  }

  file.seekg(dataOffset, std::ios::beg);
  const int rowBytes = (width * 3 + 3) & ~3;
  std::vector<uint8_t> rowBuffer(rowBytes);

  for (int row = height - 1; row >= 0; --row) {
    if (!file.read(reinterpret_cast<char*>(rowBuffer.data()), rowBytes)) break;
    const int py = y + row;
    if (py < 0 || py >= height_) continue;

    for (int col = 0; col < width; ++col) {
      const int px = x + col;
      if (px < 0 || px >= width_) continue;

      const uint8_t b = rowBuffer[col * 3];
      const uint8_t g = rowBuffer[col * 3 + 1];
      const uint8_t r = rowBuffer[col * 3 + 2];
      const uint8_t gray = static_cast<uint8_t>(0.299f * r + 0.587f * g + 0.114f * b);
      drawPixel(px, py, gray < 128);
    }
  }

  return true;
}

void SimRenderer::drawSprite(int x, int y, int w, int h, const uint8_t* ink, const uint8_t* sil) {
  if (!ink || w <= 0 || h <= 0) return;
  const int bytesPerRow = (w + 7) / 8;

  for (int r = 0; r < h; ++r) {
    const int py = y + r;
    if (py < 0 || py >= height_) continue;

    for (int c = 0; c < w; ++c) {
      const int px = x + c;
      if (px < 0 || px >= width_) continue;

      const int idx = r * bytesPerRow + (c >> 3);
      const int shift = 7 - (c & 7);

      if (sil) {
        const bool isSil = (sil[idx] >> shift) & 1;
        if (!isSil) continue;
      }

      const bool isInk = (ink[idx] >> shift) & 1;
      drawPixel(px, py, isInk);
    }
  }
}

void SimRenderer::drawQrCode(int x, int y, int w, int h, const std::string& text) {
  size_t len = text.length();
  static constexpr size_t MAX_QR_CAPACITY = 2953;
  if (len > MAX_QR_CAPACITY) {
    len = MAX_QR_CAPACITY;
  }
  std::string payload = text.substr(0, len);

  int version = 4;
  if (len > 114) version = 10;
  if (len > 395) version = 20;
  if (len > 1066) version = 30;
  if (len > 2110) version = 40;

  uint32_t bufferSize = qrcode_getBufferSize(version);
  std::vector<uint8_t> qrcodeBytes(bufferSize);

  QRCode qrcode;
  int8_t res = qrcode_initText(&qrcode, qrcodeBytes.data(), version, ECC_LOW, payload.c_str());
  if (res == 0) {
    const int maxDim = std::min(w, h);
    int px = maxDim / qrcode.size;
    if (px < 1) px = 1;

    const int qrDisplaySize = qrcode.size * px;
    const int xOff = x + (w - qrDisplaySize) / 2;
    const int yOff = y + (h - qrDisplaySize) / 2;

    for (uint8_t cy = 0; cy < qrcode.size; cy++) {
      for (uint8_t cx = 0; cx < qrcode.size; cx++) {
        if (qrcode_getModule(&qrcode, cx, cy)) {
          fillRect(xOff + px * cx, yOff + px * cy, px, px, true);
        }
      }
    }
  }
}

bool SimRenderer::saveBmp(const std::string& path) const {
  std::ofstream out(path, std::ios::binary);
  if (!out) {
    std::cerr << "[SimRenderer] Cannot open " << path << " for writing BMP" << std::endl;
    return false;
  }

  const uint32_t width = width_;
  const uint32_t height = height_;
  const uint32_t imageSize = width * height * 4;
  const uint32_t fileSize = 54 + imageSize;
  const uint32_t dataOffset = 54;

  const uint8_t fileHeader[14] = {
      'B', 'M',
      static_cast<uint8_t>(fileSize), static_cast<uint8_t>(fileSize >> 8),
      static_cast<uint8_t>(fileSize >> 16), static_cast<uint8_t>(fileSize >> 24),
      0, 0, 0, 0,
      static_cast<uint8_t>(dataOffset), static_cast<uint8_t>(dataOffset >> 8),
      static_cast<uint8_t>(dataOffset >> 16), static_cast<uint8_t>(dataOffset >> 24)
  };

  const int32_t h = -static_cast<int32_t>(height);
  const uint8_t dibHeader[40] = {
      40, 0, 0, 0,
      static_cast<uint8_t>(width), static_cast<uint8_t>(width >> 8),
      static_cast<uint8_t>(width >> 16), static_cast<uint8_t>(width >> 24),
      static_cast<uint8_t>(h), static_cast<uint8_t>(h >> 8),
      static_cast<uint8_t>(h >> 16), static_cast<uint8_t>(h >> 24),
      1, 0,
      32, 0,
      0, 0, 0, 0,
      static_cast<uint8_t>(imageSize), static_cast<uint8_t>(imageSize >> 8),
      static_cast<uint8_t>(imageSize >> 16), static_cast<uint8_t>(imageSize >> 24),
      0, 0, 0, 0,
      0, 0, 0, 0,
      0, 0, 0, 0,
      0, 0, 0, 0
  };

  out.write(reinterpret_cast<const char*>(fileHeader), sizeof(fileHeader));
  out.write(reinterpret_cast<const char*>(dibHeader), sizeof(dibHeader));
  out.write(reinterpret_cast<const char*>(pixels_.data()), imageSize);
  return true;
}

}  // namespace sim
