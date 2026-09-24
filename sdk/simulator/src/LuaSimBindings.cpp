#include "LuaSimBindings.h"

#include <curl/curl.h>
#include <SDL2/SDL.h>

#include <iostream>
#include <cmath>

#include "FontRenderer.h"
#include "SimRenderer.h"
#include "SimStorage.h"

namespace sim {

namespace {

SimContext* getContext(lua_State* L) {
  return static_cast<SimContext*>(lua_touserdata(L, lua_upvalueindex(1)));
}

inline int checkInt(lua_State* L, int arg) {
  if (lua_isinteger(L, arg)) {
    return static_cast<int>(lua_tointeger(L, arg));
  }
  return static_cast<int>(luaL_checknumber(L, arg));
}

inline int optInt(lua_State* L, int arg, int def) {
  if (lua_isnoneornil(L, arg)) return def;
  if (lua_isinteger(L, arg)) {
    return static_cast<int>(lua_tointeger(L, arg));
  }
  return static_cast<int>(luaL_optnumber(L, arg, def));
}

// ---------------------------------------------------------------------------
// Gfx API
// ---------------------------------------------------------------------------

int l_gfx_getWidth(lua_State* L) {
  auto* ctx = getContext(L);
  lua_pushinteger(L, ctx && ctx->renderer ? ctx->renderer->getWidth() : 800);
  return 1;
}

int l_gfx_getHeight(lua_State* L) {
  auto* ctx = getContext(L);
  lua_pushinteger(L, ctx && ctx->renderer ? ctx->renderer->getHeight() : 480);
  return 1;
}

int l_gfx_setOrientation(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->renderer) return 0;

  Orientation target = Orientation::Portrait;
  if (lua_isinteger(L, 1)) {
    const int val = static_cast<int>(lua_tointeger(L, 1));
    switch (val) {
      case 1: target = Orientation::Landscape; break;
      case 2: target = Orientation::PortraitInverted; break;
      case 3: target = Orientation::LandscapeCounterClockwise; break;
      default: target = Orientation::Portrait; break;
    }
  } else if (lua_isstring(L, 1)) {
    const char* str = lua_tostring(L, 1);
    if (strcmp(str, "landscape") == 0 || strcmp(str, "landscape_cw") == 0) {
      target = Orientation::Landscape;
    } else if (strcmp(str, "landscape_ccw") == 0) {
      target = Orientation::LandscapeCounterClockwise;
    } else if (strcmp(str, "portrait_inverted") == 0) {
      target = Orientation::PortraitInverted;
    } else {
      target = Orientation::Portrait;
    }
  }

  if (ctx->renderer->getOrientation() != target) {
    ctx->renderer->setOrientation(target);
    ctx->orientationChanged = true;
    ctx->updateRequested = true;
  }
  return 0;
}

int l_gfx_getOrientation(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->renderer) {
    lua_pushstring(L, "portrait");
    return 1;
  }
  switch (ctx->renderer->getOrientation()) {
    case Orientation::Landscape:
      lua_pushstring(L, "landscape");
      break;
    case Orientation::LandscapeCounterClockwise:
      lua_pushstring(L, "landscape_ccw");
      break;
    case Orientation::PortraitInverted:
      lua_pushstring(L, "portrait_inverted");
      break;
    case Orientation::Portrait:
    default:
      lua_pushstring(L, "portrait");
      break;
  }
  return 1;
}

int l_gfx_clearScreen(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int color = optInt(L, 1, 1);
    ctx->renderer->clearScreen(color);
  }
  return 0;
}

int l_gfx_drawPixel(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int x = checkInt(L, 1);
    const int y = checkInt(L, 2);
    const bool black = lua_isnone(L, 3) ? true : lua_toboolean(L, 3);
    ctx->renderer->drawPixel(x, y, black);
  }
  return 0;
}

int l_gfx_drawLine(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int x1 = checkInt(L, 1);
    const int y1 = checkInt(L, 2);
    const int x2 = checkInt(L, 3);
    const int y2 = checkInt(L, 4);
    const int lineWidth = optInt(L, 5, 1);
    const bool black = lua_isnone(L, 6) ? true : lua_toboolean(L, 6);
    ctx->renderer->drawLine(x1, y1, x2, y2, lineWidth, black);
  }
  return 0;
}

int l_gfx_drawRect(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int x = checkInt(L, 1);
    const int y = checkInt(L, 2);
    const int w = checkInt(L, 3);
    const int h = checkInt(L, 4);
    const int lineWidth = optInt(L, 5, 1);
    const bool black = lua_isnone(L, 6) ? true : lua_toboolean(L, 6);
    ctx->renderer->drawRect(x, y, w, h, lineWidth, black);
  }
  return 0;
}

int l_gfx_fillRect(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int x = checkInt(L, 1);
    const int y = checkInt(L, 2);
    const int w = checkInt(L, 3);
    const int h = checkInt(L, 4);
    const bool black = lua_isnone(L, 5) ? true : lua_toboolean(L, 5);
    ctx->renderer->fillRect(x, y, w, h, black);
  }
  return 0;
}

int l_gfx_fillRectDither(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int x = checkInt(L, 1);
    const int y = checkInt(L, 2);
    const int w = checkInt(L, 3);
    const int h = checkInt(L, 4);
    const int col = optInt(L, 5, static_cast<int>(Color::LightGray));
    ctx->renderer->fillRectDither(x, y, w, h, static_cast<Color>(col));
  }
  return 0;
}

static bool isColorBlack(lua_State* L, int idx) {
  if (lua_isnone(L, idx)) return true;
  if (lua_isboolean(L, idx)) return lua_toboolean(L, idx);
  if (lua_isinteger(L, idx) || lua_isnumber(L, idx)) {
    const int val = lua_tointeger(L, idx);
    if (val == static_cast<int>(Color::White) || val == 1 || val == 3) {
      return false;
    }
    return true;
  }
  return lua_toboolean(L, idx);
}

int l_gfx_drawRoundedRect(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int x = checkInt(L, 1);
    const int y = checkInt(L, 2);
    const int w = checkInt(L, 3);
    const int h = checkInt(L, 4);
    const int radius = checkInt(L, 5);
    const int lineWidth = optInt(L, 6, 1);
    const bool black = isColorBlack(L, 7);
    ctx->renderer->drawRoundedRect(x, y, w, h, radius, lineWidth, black);
  }
  return 0;
}

int l_gfx_fillRoundedRect(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int x = checkInt(L, 1);
    const int y = checkInt(L, 2);
    const int w = checkInt(L, 3);
    const int h = checkInt(L, 4);
    const int radius = checkInt(L, 5);
    Color col = Color::Black;
    if (lua_isboolean(L, 6)) {
      col = lua_toboolean(L, 6) ? Color::Black : Color::White;
    } else if (lua_isinteger(L, 6) || lua_isnumber(L, 6)) {
      const int val = lua_tointeger(L, 6);
      if (val == static_cast<int>(Color::White) || val == 1 || val == 3) {
        col = Color::White;
      } else if (val == static_cast<int>(Color::Black) || val == 0 || val == 16) {
        col = Color::Black;
      } else {
        col = static_cast<Color>(val);
      }
    }
    ctx->renderer->fillRoundedRect(x, y, w, h, radius, col);
  }
  return 0;
}

int l_gfx_drawCircle(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int cx = checkInt(L, 1);
    const int cy = checkInt(L, 2);
    const int r = checkInt(L, 3);
    const int lineWidth = optInt(L, 4, 1);
    const bool black = isColorBlack(L, 5);
    ctx->renderer->drawCircle(cx, cy, r, lineWidth, black);
  }
  return 0;
}

int l_gfx_drawText(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int fontId = luaL_checkinteger(L, 1);
    const int x = checkInt(L, 2);
    const int y = checkInt(L, 3);
    const char* text = luaL_checkstring(L, 4);
    const bool black = isColorBlack(L, 5);
    ctx->renderer->drawText(fontId, x, y, text, black);
  }
  return 0;
}

int l_gfx_drawCenteredText(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int fontId = luaL_checkinteger(L, 1);
    const int y = checkInt(L, 2);
    const char* text = luaL_checkstring(L, 3);
    const bool black = isColorBlack(L, 4);
    ctx->renderer->drawCenteredText(fontId, y, text, black);
  }
  return 0;
}

int l_gfx_getTextWidth(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int fontId = luaL_checkinteger(L, 1);
    const char* text = luaL_checkstring(L, 2);
    lua_pushinteger(L, ctx->renderer->getTextWidth(fontId, text));
    return 1;
  }
  lua_pushinteger(L, 0);
  return 1;
}

int l_gfx_getLineHeight(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer) {
    const int fontId = luaL_checkinteger(L, 1);
    lua_pushinteger(L, ctx->renderer->getLineHeight(fontId));
    return 1;
  }
  lua_pushinteger(L, 16);
  return 1;
}

int l_gfx_drawBitmapFile(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->renderer && ctx->storage) {
    const int x = checkInt(L, 1);
    const int y = checkInt(L, 2);
    const char* relPath = luaL_checkstring(L, 3);
    const std::string fullPath = ctx->storage->resolvePath(relPath);
    lua_pushboolean(L, ctx->renderer->drawBitmapFile(x, y, fullPath));
    return 1;
  }
  lua_pushboolean(L, false);
  return 1;
}

int l_gfx_drawSprite(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->renderer) return 0;

  const int x = checkInt(L, 1);
  const int y = checkInt(L, 2);
  const int w = checkInt(L, 3);
  const int h = checkInt(L, 4);

  size_t inkLen = 0;
  const uint8_t* ink = reinterpret_cast<const uint8_t*>(luaL_checklstring(L, 5, &inkLen));

  size_t silLen = 0;
  const uint8_t* sil =
      lua_isnoneornil(L, 6) ? nullptr : reinterpret_cast<const uint8_t*>(luaL_checklstring(L, 6, &silLen));

  ctx->renderer->drawSprite(x, y, w, h, ink, sil);
  return 0;
}

int l_gfx_displayBuffer(lua_State*) {
  // In simulator, display buffer is flushed to SDL window on frame end
  return 0;
}

// ---------------------------------------------------------------------------
// Storage API
// ---------------------------------------------------------------------------

int l_storage_readFile(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->storage) {
    lua_pushnil(L);
    return 1;
  }
  const char* relPath = luaL_checkstring(L, 1);
  std::string content;
  if (ctx->storage->readFile(relPath, content)) {
    lua_pushlstring(L, content.data(), content.size());
    return 1;
  }
  lua_pushnil(L);
  return 1;
}

int l_storage_writeFile(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->storage) {
    lua_pushboolean(L, false);
    return 1;
  }
  const char* relPath = luaL_checkstring(L, 1);
  size_t len = 0;
  const char* data = luaL_checklstring(L, 2, &len);
  lua_pushboolean(L, ctx->storage->writeFile(relPath, std::string(data, len)));
  return 1;
}

int l_storage_exists(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->storage) {
    lua_pushboolean(L, false);
    return 1;
  }
  const char* relPath = luaL_checkstring(L, 1);
  lua_pushboolean(L, ctx->storage->exists(relPath));
  return 1;
}

int l_storage_remove(lua_State* L) {
  auto* ctx = getContext(L);
  if (!ctx || !ctx->storage) {
    lua_pushboolean(L, false);
    return 1;
  }
  const char* relPath = luaL_checkstring(L, 1);
  lua_pushboolean(L, ctx->storage->remove(relPath));
  return 1;
}

// ---------------------------------------------------------------------------
// Crosspoint / System API
// ---------------------------------------------------------------------------

int l_crosspoint_millis(lua_State* L) {
  lua_pushinteger(L, static_cast<lua_Integer>(SDL_GetTicks()));
  return 1;
}

int l_crosspoint_requestUpdate(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx) {
    ctx->updateRequested = true;
  }
  return 0;
}

int l_crosspoint_finish(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx) {
    ctx->shouldFinish = true;
  }
  return 0;
}

static void extractLogArgs(lua_State* L, const char*& tag, const char*& msg) {
  if (lua_gettop(L) >= 2) {
    tag = luaL_tolstring(L, 1, nullptr);
    msg = luaL_tolstring(L, 2, nullptr);
  } else if (lua_gettop(L) == 1) {
    tag = "LUA";
    msg = luaL_tolstring(L, 1, nullptr);
  } else {
    tag = "LUA";
    msg = "";
  }
}

int l_log_debug(lua_State* L) {
  const char *tag = nullptr, *msg = nullptr;
  extractLogArgs(L, tag, msg);
  std::cout << "\033[90m[DBG] [" << tag << "] " << msg << "\033[0m" << std::endl;
  return 0;
}

int l_log_info(lua_State* L) {
  const char *tag = nullptr, *msg = nullptr;
  extractLogArgs(L, tag, msg);
  std::cout << "\033[36m[INF] [" << tag << "] " << msg << "\033[0m" << std::endl;
  return 0;
}

int l_log_warn(lua_State* L) {
  const char *tag = nullptr, *msg = nullptr;
  extractLogArgs(L, tag, msg);
  std::cout << "\033[33m[WRN] [" << tag << "] " << msg << "\033[0m" << std::endl;
  return 0;
}

int l_log_error(lua_State* L) {
  const char *tag = nullptr, *msg = nullptr;
  extractLogArgs(L, tag, msg);
  std::cerr << "\033[31m[ERR] [" << tag << "] " << msg << "\033[0m" << std::endl;
  return 0;
}

int l_crosspoint_log(lua_State* L) {
  return l_log_info(L);
}

int l_crosspoint_getMemoryInfo(lua_State* L) {
  lua_newtable(L);
  const int luaKb = lua_gc(L, LUA_GCCOUNT, 0);
  lua_pushinteger(L, luaKb);
  lua_setfield(L, -2, "luaMemoryKb");
  lua_pushinteger(L, 8192);
  lua_setfield(L, -2, "freeHeapKb");
  lua_pushinteger(L, 8192);
  lua_setfield(L, -2, "freePsramKb");
  return 1;
}

int simModuleSearcher(lua_State* L) {
  auto* ctx = getContext(L);
  const char* rawModName = luaL_checkstring(L, 1);
  std::string modPath = rawModName;
  for (char& c : modPath) {
    if (c == '.') c = '/';
  }

  std::vector<std::string> candidates = {
      modPath + ".lua",
      modPath + "/init.lua",
  };

  std::string errorLog;
  for (const auto& relPath : candidates) {
    std::string content;
    if (ctx && ctx->storage && ctx->storage->readFile(relPath, content)) {
      std::string fullPath = (ctx ? ctx->appDir : ".") + "/" + relPath;
      if (luaL_loadbuffer(L, content.data(), content.size(), ("@" + fullPath).c_str()) == LUA_OK) {
        return 1;
      }
      return lua_error(L);
    }
    errorLog += "\n\tno file '" + relPath + "'";
  }

  lua_pushstring(L, errorLog.c_str());
  return 1;
}

int l_crosspoint_isWifiConnected(lua_State* L) {
  lua_pushboolean(L, true);
  return 1;
}

static size_t curlWriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
  auto* s = static_cast<std::string*>(userp);
  s->append(static_cast<char*>(contents), size * nmemb);
  return size * nmemb;
}

int l_crosspoint_httpGet(lua_State* L) {
  const char* url = luaL_checkstring(L, 1);
  CURL* curl = curl_easy_init();
  if (!curl) {
    lua_pushnil(L);
    return 1;
  }

  std::string response;
  curl_easy_setopt(curl, CURLOPT_URL, url);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curlWriteCallback);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
  curl_easy_setopt(curl, CURLOPT_USERAGENT, "CrossPoint-Simulator/1.0");
  curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);
  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

  const CURLcode res = curl_easy_perform(curl);
  curl_easy_cleanup(curl);

  if (res == CURLE_OK) {
    lua_pushlstring(L, response.data(), response.size());
    return 1;
  }

  std::cerr << "[SimNetwork] httpGet error for " << url << ": " << curl_easy_strerror(res) << std::endl;
  lua_pushnil(L);
  return 1;
}

int l_crosspoint_setSleepApp(lua_State* L) {
  auto* ctx = getContext(L);
  const char* id = luaL_checkstring(L, 1);
  if (ctx) {
    ctx->sleepAppId = id;
    std::cout << "[Simulator] Set sleep app to: " << id << std::endl;
  }
  return 0;
}

int l_crosspoint_getSleepApp(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && !ctx->sleepAppId.empty()) {
    lua_pushstring(L, ctx->sleepAppId.c_str());
  } else {
    lua_pushliteral(L, "");
  }
  return 1;
}

int l_crosspoint_clearSleepApp(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx) {
    ctx->sleepAppId.clear();
    std::cout << "[Simulator] Cleared sleep app" << std::endl;
  }
  return 0;
}

// ---------------------------------------------------------------------------
// Input API
// ---------------------------------------------------------------------------

int l_input_wasPressed(lua_State* L) {
  // Simulator dispatches via onInput callback
  lua_pushboolean(L, false);
  return 1;
}

int l_input_isPressed(lua_State* L) {
  lua_pushboolean(L, false);
  return 1;
}

int l_input_wasScreenTapped(lua_State* L) {
  lua_pushnil(L);
  return 1;
}

int l_input_isTouchDown(lua_State* L) {
  auto* ctx = getContext(L);
  lua_pushboolean(L, ctx && ctx->isTouchDown);
  return 1;
}

int l_input_getTouch(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->isTouchDown) {
    lua_pushboolean(L, true);
    lua_pushinteger(L, ctx->touchX);
    lua_pushinteger(L, ctx->touchY);
    return 3;
  }
  lua_pushboolean(L, false);
  return 1;
}

int l_input_wasTouchDown(lua_State* L) {
  auto* ctx = getContext(L);
  if (ctx && ctx->wasTouchDown) {
    lua_pushboolean(L, true);
    lua_pushinteger(L, ctx->touchX);
    lua_pushinteger(L, ctx->touchY);
    return 3;
  }
  lua_pushboolean(L, false);
  return 1;
}

int l_input_wasTouchReleased(lua_State* L) {
  auto* ctx = getContext(L);
  lua_pushboolean(L, ctx && ctx->wasTouchReleased);
  return 1;
}

void registerModule(lua_State* L, const char* name, const luaL_Reg* funcs, SimContext* ctx) {
  lua_newtable(L);
  for (; funcs->name != nullptr; ++funcs) {
    lua_pushlightuserdata(L, ctx);
    lua_pushcclosure(L, funcs->func, 1);
    lua_setfield(L, -2, funcs->name);
  }
  lua_setglobal(L, name);
}

}  // namespace

void registerSimBindings(lua_State* L, SimContext* ctx) {
  static const luaL_Reg gfxFuncs[] = {
      {"getWidth", l_gfx_getWidth},
      {"getHeight", l_gfx_getHeight},
      {"clearScreen", l_gfx_clearScreen},
      {"drawPixel", l_gfx_drawPixel},
      {"drawLine", l_gfx_drawLine},
      {"drawRect", l_gfx_drawRect},
      {"fillRect", l_gfx_fillRect},
      {"fillRectDither", l_gfx_fillRectDither},
      {"drawRoundedRect", l_gfx_drawRoundedRect},
      {"fillRoundedRect", l_gfx_fillRoundedRect},
      {"drawCircle", l_gfx_drawCircle},
      {"drawText", l_gfx_drawText},
      {"drawCenteredText", l_gfx_drawCenteredText},
      {"getTextWidth", l_gfx_getTextWidth},
      {"getLineHeight", l_gfx_getLineHeight},
      {"drawBitmapFile", l_gfx_drawBitmapFile},
      {"drawSprite", l_gfx_drawSprite},
      {"displayBuffer", l_gfx_displayBuffer},
      {"setOrientation", l_gfx_setOrientation},
      {"getOrientation", l_gfx_getOrientation},
      {nullptr, nullptr},
  };
  registerModule(L, "gfx", gfxFuncs, ctx);

  // Set gfx constants
  lua_getglobal(L, "gfx");
  lua_pushinteger(L, static_cast<int>(Orientation::Portrait));
  lua_setfield(L, -2, "ORIENTATION_PORTRAIT");
  lua_pushinteger(L, static_cast<int>(Orientation::Landscape));
  lua_setfield(L, -2, "ORIENTATION_LANDSCAPE");
  lua_pushinteger(L, static_cast<int>(Orientation::PortraitInverted));
  lua_setfield(L, -2, "ORIENTATION_PORTRAIT_INVERTED");
  lua_pushinteger(L, static_cast<int>(Orientation::LandscapeCounterClockwise));
  lua_setfield(L, -2, "ORIENTATION_LANDSCAPE_CCW");
  lua_pushinteger(L, FONT_UI_10_ID);
  lua_setfield(L, -2, "FONT_UI_10");
  lua_pushinteger(L, FONT_UI_12_ID);
  lua_setfield(L, -2, "FONT_UI_12");
  lua_pushinteger(L, FONT_SMALL_ID);
  lua_setfield(L, -2, "FONT_SMALL");
  lua_pushinteger(L, FONT_NOTOSANS_12_ID);
  lua_setfield(L, -2, "FONT_NOTOSANS_12");
  lua_pushinteger(L, FONT_NOTOSANS_14_ID);
  lua_setfield(L, -2, "FONT_NOTOSANS_14");
  lua_pushinteger(L, FONT_NOTOSANS_16_ID);
  lua_setfield(L, -2, "FONT_NOTOSANS_16");
  lua_pushinteger(L, FONT_NOTOSERIF_12_ID);
  lua_setfield(L, -2, "FONT_NOTOSERIF_12");
  lua_pushinteger(L, FONT_NOTOSERIF_14_ID);
  lua_setfield(L, -2, "FONT_NOTOSERIF_14");

  lua_pushinteger(L, 0);
  lua_setfield(L, -2, "REFRESH_FAST");
  lua_pushinteger(L, 1);
  lua_setfield(L, -2, "REFRESH_HALF");
  lua_pushinteger(L, 2);
  lua_setfield(L, -2, "REFRESH_FULL");

  lua_pushinteger(L, static_cast<int>(Color::Black));
  lua_setfield(L, -2, "COLOR_BLACK");
  lua_pushinteger(L, static_cast<int>(Color::DarkGray));
  lua_setfield(L, -2, "COLOR_DARK_GRAY");
  lua_pushinteger(L, static_cast<int>(Color::LightGray));
  lua_setfield(L, -2, "COLOR_LIGHT_GRAY");
  lua_pushinteger(L, static_cast<int>(Color::White));
  lua_setfield(L, -2, "COLOR_WHITE");
  lua_pop(L, 1);

  // Set input module & constants
  static const luaL_Reg inputFuncs[] = {
      {"wasPressed", l_input_wasPressed},
      {"isPressed", l_input_isPressed},
      {"wasScreenTapped", l_input_wasScreenTapped},
      {"isTouchDown", l_input_isTouchDown},
      {"getTouch", l_input_getTouch},
      {"wasTouchDown", l_input_wasTouchDown},
      {"wasTouchReleased", l_input_wasTouchReleased},
      {nullptr, nullptr},
  };
  registerModule(L, "input", inputFuncs, ctx);

  lua_getglobal(L, "input");
  lua_pushinteger(L, 0);  // Back
  lua_setfield(L, -2, "BTN_BACK");
  lua_pushinteger(L, 1);  // Confirm
  lua_setfield(L, -2, "BTN_CONFIRM");
  lua_pushinteger(L, 2);  // Left
  lua_setfield(L, -2, "BTN_LEFT");
  lua_pushinteger(L, 3);  // Right
  lua_setfield(L, -2, "BTN_RIGHT");
  lua_pushinteger(L, 4);  // Up
  lua_setfield(L, -2, "BTN_UP");
  lua_pushinteger(L, 5);  // Down
  lua_setfield(L, -2, "BTN_DOWN");
  lua_pushinteger(L, 7);  // PageBack
  lua_setfield(L, -2, "BTN_PAGE_BACK");
  lua_pushinteger(L, 8);  // PageForward
  lua_setfield(L, -2, "BTN_PAGE_FORWARD");
  lua_pop(L, 1);

  // Set storage module
  static const luaL_Reg storageFuncs[] = {
      {"readFile", l_storage_readFile},
      {"writeFile", l_storage_writeFile},
      {"exists", l_storage_exists},
      {"remove", l_storage_remove},
      {nullptr, nullptr},
  };
  registerModule(L, "storage", storageFuncs, ctx);

  // Set log module
  static const luaL_Reg logFuncs[] = {
      {"debug", l_log_debug},
      {"info", l_log_info},
      {"warn", l_log_warn},
      {"error", l_log_error},
      {nullptr, nullptr},
  };
  registerModule(L, "log", logFuncs, ctx);

  // Set crosspoint module
  static const luaL_Reg crosspointFuncs[] = {
      {"millis", l_crosspoint_millis},
      {"requestUpdate", l_crosspoint_requestUpdate},
      {"finish", l_crosspoint_finish},
      {"log", l_crosspoint_log},
      {"getMemoryInfo", l_crosspoint_getMemoryInfo},
      {"isWifiConnected", l_crosspoint_isWifiConnected},
      {"httpGet", l_crosspoint_httpGet},
      {"setSleepApp", l_crosspoint_setSleepApp},
      {"getSleepApp", l_crosspoint_getSleepApp},
      {"clearSleepApp", l_crosspoint_clearSleepApp},
      {nullptr, nullptr},
  };
  registerModule(L, "crosspoint", crosspointFuncs, ctx);

  // Register custom package searcher for modular require(...)
  lua_getglobal(L, "package");
  if (lua_istable(L, -1)) {
    lua_getfield(L, -1, "searchers");
    if (lua_istable(L, -1)) {
      const int count = static_cast<int>(lua_rawlen(L, -1));
      for (int i = count; i >= 2; --i) {
        lua_rawgeti(L, -1, i);
        lua_rawseti(L, -2, i + 1);
      }
      lua_pushlightuserdata(L, ctx);
      lua_pushcclosure(L, simModuleSearcher, 1);
      lua_rawseti(L, -2, 2);
    }
    lua_pop(L, 1);
  }
  lua_pop(L, 1);
}

}  // namespace sim
