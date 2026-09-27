#include "SimUiHost.h"

#include <SDL2/SDL.h>
#include <algorithm>
#include <cstring>
#include <iostream>

namespace sim {

// Standard CrossPoint 32px back arrow icon
static const uint8_t icon_header_back_32_bits[] = {
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFC, 0x7F, 0xFF, 0xFF, 0xF8, 0x7F, 0xFF, 0xFF, 0xF0, 0xFF, 0xFF, 0xFF, 0xE1,
    0xFF, 0xFF, 0xFF, 0xC3, 0xFF, 0xFF, 0xFF, 0x87, 0xFF, 0xFF, 0xFF, 0x0F, 0xFF, 0xFF, 0xFE, 0x1F, 0xFF, 0xFF, 0xFC,
    0x3F, 0xFF, 0xFF, 0xF8, 0x00, 0x00, 0x3F, 0xF8, 0x00, 0x00, 0x3F, 0xFC, 0x3F, 0xFF, 0xFF, 0xFE, 0x1F, 0xFF, 0xFF,
    0xFF, 0x0F, 0xFF, 0xFF, 0xFF, 0x87, 0xFF, 0xFF, 0xFF, 0xC3, 0xFF, 0xFF, 0xFF, 0xE1, 0xFF, 0xFF, 0xFF, 0xF0, 0xFF,
    0xFF, 0xFF, 0xF8, 0x7F, 0xFF, 0xFF, 0xFC, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

const freeink::ui::BitmapRef SimUiHost::getHeaderBackIcon() {
  freeink::ui::BitmapRef bmp;
  bmp.data = icon_header_back_32_bits;
  bmp.width = 32;
  bmp.height = 32;
  bmp.format = freeink::ui::BitmapFormat::Mask1;
  bmp.progmem = true;
  return bmp;
}

SimUiHost::SimUiHost(SimRenderer& renderer, FontRenderer& fontRenderer)
    : renderer_(renderer), fontRenderer_(fontRenderer), drawTarget_(renderer, fontRenderer) {
  refreshTokens();
}

SimUiHost::~SimUiHost() {
  detachLua();
}

void SimUiHost::detachLua() {
  if (prompt_.confirmLuaRef != -1 && prompt_.confirmLuaRef != LUA_NOREF && activeL_) {
    luaL_unref(activeL_, LUA_REGISTRYINDEX, prompt_.confirmLuaRef);
    prompt_.confirmLuaRef = -1;
  }
  if (prompt_.cancelLuaRef != -1 && prompt_.cancelLuaRef != LUA_NOREF && activeL_) {
    luaL_unref(activeL_, LUA_REGISTRYINDEX, prompt_.cancelLuaRef);
    prompt_.cancelLuaRef = -1;
  }
  prompt_.active = false;
  clearCallbacks(activeL_);
  activeL_ = nullptr;
}

void SimUiHost::setTheme(UiThemeType type) {
  currentTheme_ = type;
  refreshTokens();
}

void SimUiHost::setThemeByName(const std::string& name) {
  if (name == "RoundedRaff" || name == "roundedraff" || name == "rounded") {
    setTheme(UiThemeType::RoundedRaff);
  } else if (name == "Classic" || name == "classic") {
    setTheme(UiThemeType::Classic);
  } else {
    setTheme(UiThemeType::Lyra);
  }
}

std::string SimUiHost::getThemeName() const {
  switch (currentTheme_) {
    case UiThemeType::RoundedRaff:
      return "RoundedRaff";
    case UiThemeType::Classic:
      return "Classic";
    case UiThemeType::Lyra:
    default:
      return "Lyra";
  }
}

void SimUiHost::refreshTokens() {
  tokens_ = freeink::ui::themeTokensForLineHeight(drawTarget_.lineHeight(SimDrawTarget::FONT_BODY));

  switch (currentTheme_) {
    case UiThemeType::RoundedRaff:
      tokens_.headerHeight = 48;
      tokens_.headerUnderline = 0;
      tokens_.headerTitleAlign = freeink::ui::TextAlign::Center;
      tokens_.controlRadius = 12;
      tokens_.listRowRadius = 10;
      tokens_.sheetRadius = 12;
      tokens_.capsuleRadius = 16;
      break;

    case UiThemeType::Classic:
      tokens_.headerHeight = 44;
      tokens_.headerUnderline = 1;
      tokens_.headerTitleAlign = freeink::ui::TextAlign::Left;
      tokens_.controlRadius = 0;
      tokens_.listRowRadius = 0;
      tokens_.sheetRadius = 0;
      tokens_.capsuleRadius = 0;
      break;

    case UiThemeType::Lyra:
    default:
      tokens_.headerHeight = 44;
      tokens_.headerUnderline = 1;
      tokens_.headerTitleAlign = freeink::ui::TextAlign::Left;
      tokens_.controlRadius = 6;
      tokens_.listRowRadius = 6;
      tokens_.sheetRadius = 8;
      tokens_.capsuleRadius = 12;
      break;
  }
}

void SimUiHost::clearCallbacks(lua_State* L) {
  if (L) {
    for (int ref : luaRefsToClean_) {
      if (ref != -1 && ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, ref);
      }
    }
  }
  luaRefsToClean_.clear();
  callbacks_.clear();
}

void SimUiHost::beginFrame(lua_State* L) {
  clearCallbacks(activeL_);
  activeL_ = L;
  nextActionId_ = 1;

  interactions_.beginPublishCycle();
  interactions_.clear();

  deviceContext_ = drawTarget_.deviceContext();
  emptySnap_ = freeink::ui::InputSnapshot{};
  frame_ = std::make_unique<freeink::ui::Frame<INTERACTION_CAPACITY>>(
      drawTarget_, deviceContext_, emptySnap_, interactions_);
}

void SimUiHost::endFrame() {
  if (prompt_.active) {
    renderPromptOverlay();
  }
  interactions_.publish();
}

freeink::ui::ActionId SimUiHost::registerCallback(lua_State* L, int funcIndex, int16_t value,
                                                  const std::string& name) {
  return registerCallbackWithInvoker(L, funcIndex, nullptr, value, name);
}

freeink::ui::ActionId SimUiHost::registerCallbackWithInvoker(lua_State* L, int funcIndex,
                                                            UiInvoker invoker, int16_t value,
                                                            const std::string& name) {
  freeink::ui::ActionId action = nextActionId_++;
  int ref = -1;
  if (L && funcIndex != 0 && lua_isfunction(L, funcIndex)) {
    lua_pushvalue(L, funcIndex);
    ref = luaL_ref(L, LUA_REGISTRYINDEX);
    luaRefsToClean_.push_back(ref);
  }
  callbacks_[action] = UiCallback{ref, name, value, std::move(invoker)};
  return action;
}

bool SimUiHost::dispatchTouch(int x, int y, lua_State* L) {
  const size_t count = interactions_.publishedCount();
  const freeink::ui::Interaction* data = interactions_.publishedData();

  for (int i = static_cast<int>(count) - 1; i >= 0; --i) {
    const freeink::ui::Interaction& hit = data[i];
    if (hit.rect.contains(static_cast<int16_t>(x), static_cast<int16_t>(y)) &&
        !freeink::ui::hasState(hit.state, freeink::ui::StateDisabled)) {
      auto it = callbacks_.find(hit.action);
      if (it != callbacks_.end()) {
        const UiCallback& cb = it->second;

        // 1. If explicit Lua callback is registered:
        if (cb.luaFuncRef != -1 && L) {
          const int errIdx = lua_gettop(L) + 1;
          lua_pushcfunction(L, [](lua_State* s) -> int {
            const char* msg = lua_tostring(s, 1);
            std::cerr << "[Lua UI Callback Error] " << (msg ? msg : "") << std::endl;
            return 1;
          });
          lua_rawgeti(L, LUA_REGISTRYINDEX, cb.luaFuncRef);
          if (lua_isfunction(L, -1)) {
            int numArgs = 1;
            if (cb.invoker) {
              numArgs = cb.invoker(L, x, y, hit.value != 0 ? hit.value : cb.value);
            } else {
              lua_pushinteger(L, hit.value != 0 ? hit.value : cb.value);
            }
            if (numArgs >= 0) {
              lua_pcall(L, numArgs, 0, errIdx);
            } else {
              lua_pop(L, 1);
            }
          } else {
            lua_pop(L, 1);
          }
          lua_remove(L, errIdx);
          return true;
        }

        // 2. If it's a default back button action
        if (cb.name == "back" && L) {
          lua_getglobal(L, "onBack");
          if (lua_isfunction(L, -1)) {
            lua_pcall(L, 0, 0, 0);
          } else {
            lua_pop(L, 1);
          }
          return true;
        }

        return true;  // Handled hit even if no callback
      }
    }
  }

  return false;  // Fall through to onTouch(x, y)
}

void SimUiHost::showPrompt(const std::string& title, const std::string& initialText,
                           const std::string& placeholder, const std::string& inputType,
                           const size_t maxLength, const int confirmRef, const int cancelRef) {
  if (prompt_.confirmLuaRef != -1 && prompt_.confirmLuaRef != LUA_NOREF && activeL_) {
    luaL_unref(activeL_, LUA_REGISTRYINDEX, prompt_.confirmLuaRef);
  }
  if (prompt_.cancelLuaRef != -1 && prompt_.cancelLuaRef != LUA_NOREF && activeL_) {
    luaL_unref(activeL_, LUA_REGISTRYINDEX, prompt_.cancelLuaRef);
  }

  prompt_.active = true;
  prompt_.title = title.empty() ? "Enter Text" : title;
  prompt_.text = initialText;
  prompt_.placeholder = placeholder;
  prompt_.inputType = inputType.empty() ? "text" : inputType;
  prompt_.maxLength = maxLength > 0 ? maxLength : 256;
  prompt_.confirmLuaRef = confirmRef;
  prompt_.cancelLuaRef = cancelRef;

  SDL_StartTextInput();
}

void SimUiHost::promptAppendText(const char* utf8) {
  if (!prompt_.active || !utf8 || !*utf8) return;
  if (prompt_.maxLength == 0 || prompt_.text.size() + strlen(utf8) <= prompt_.maxLength) {
    prompt_.text.append(utf8);
  }
}

void SimUiHost::promptBackspace() {
  if (!prompt_.active || prompt_.text.empty()) return;
  while (!prompt_.text.empty()) {
    const char c = prompt_.text.back();
    prompt_.text.pop_back();
    if ((static_cast<uint8_t>(c) & 0xC0) != 0x80) {
      break;
    }
  }
}

void SimUiHost::confirmPrompt(lua_State* L) {
  if (!prompt_.active) return;
  prompt_.active = false;
  SDL_StopTextInput();

  const int confirmRef = prompt_.confirmLuaRef;
  const int cancelRef = prompt_.cancelLuaRef;
  prompt_.confirmLuaRef = -1;
  prompt_.cancelLuaRef = -1;

  if (confirmRef != -1 && confirmRef != LUA_NOREF && L) {
    const int errIdx = lua_gettop(L) + 1;
    lua_pushcfunction(L, [](lua_State* s) -> int {
      const char* msg = lua_tostring(s, 1);
      std::cerr << "[Prompt Confirm Error] " << (msg ? msg : "") << std::endl;
      return 1;
    });
    lua_rawgeti(L, LUA_REGISTRYINDEX, confirmRef);
    if (lua_isfunction(L, -1)) {
      lua_pushlstring(L, prompt_.text.data(), prompt_.text.size());
      lua_pcall(L, 1, 0, errIdx);
    } else {
      lua_pop(L, 1);
    }
    lua_remove(L, errIdx);
  }

  if (confirmRef != -1 && confirmRef != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, confirmRef);
  if (cancelRef != -1 && cancelRef != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, cancelRef);
}

void SimUiHost::cancelPrompt(lua_State* L) {
  if (!prompt_.active) return;
  prompt_.active = false;
  SDL_StopTextInput();

  const int confirmRef = prompt_.confirmLuaRef;
  const int cancelRef = prompt_.cancelLuaRef;
  prompt_.confirmLuaRef = -1;
  prompt_.cancelLuaRef = -1;

  if (cancelRef != -1 && cancelRef != LUA_NOREF && L) {
    const int errIdx = lua_gettop(L) + 1;
    lua_pushcfunction(L, [](lua_State* s) -> int {
      const char* msg = lua_tostring(s, 1);
      std::cerr << "[Prompt Cancel Error] " << (msg ? msg : "") << std::endl;
      return 1;
    });
    lua_rawgeti(L, LUA_REGISTRYINDEX, cancelRef);
    if (lua_isfunction(L, -1)) {
      lua_pcall(L, 0, 0, errIdx);
    } else {
      lua_pop(L, 1);
    }
    lua_remove(L, errIdx);
  }

  if (confirmRef != -1 && confirmRef != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, confirmRef);
  if (cancelRef != -1 && cancelRef != LUA_NOREF && L) luaL_unref(L, LUA_REGISTRYINDEX, cancelRef);
}

bool SimUiHost::dispatchPromptTouch(int x, int y, lua_State* L) {
  if (!prompt_.active) return false;

  const int sw = renderer_.getWidth();
  const int sh = renderer_.getHeight();
  const int dw = std::min(440, sw - 32);
  const int dh = 200;
  const int dx = (sw - dw) / 2;
  const int dy = (sh - dh) / 2;

  const int btnW = (dw - 48) / 2;
  const int btnH = 40;
  const int btnY = dy + dh - btnH - 16;
  const int cancelX = dx + 16;
  const int okX = cancelX + btnW + 16;

  if (x >= cancelX && x < cancelX + btnW && y >= btnY && y < btnY + btnH) {
    cancelPrompt(L);
    return true;
  }
  if (x >= okX && x < okX + btnW && y >= btnY && y < btnY + btnH) {
    confirmPrompt(L);
    return true;
  }

  return true;  // Consume any tap inside or outside prompt dialog
}

void SimUiHost::renderPromptOverlay() {
  if (!prompt_.active) return;

  const int sw = renderer_.getWidth();
  const int sh = renderer_.getHeight();

  // 1. Dithered backdrop
  freeink::ui::Rect fullScreen{0, 0, static_cast<int16_t>(sw), static_cast<int16_t>(sh)};
  drawTarget_.fill(fullScreen, freeink::ui::Paint::dither(freeink::ui::Color::LightGray));

  // 2. Dialog box
  const int dw = std::min(440, sw - 32);
  const int dh = 200;
  const int dx = (sw - dw) / 2;
  const int dy = (sh - dh) / 2;
  const int radius = tokens_.sheetRadius > 0 ? tokens_.sheetRadius : 8;

  freeink::ui::Rect dlgRect{static_cast<int16_t>(dx), static_cast<int16_t>(dy), static_cast<int16_t>(dw), static_cast<int16_t>(dh)};
  drawTarget_.fill(dlgRect, freeink::ui::Paint::solid(freeink::ui::Color::White), static_cast<uint8_t>(radius));
  drawTarget_.stroke(dlgRect, freeink::ui::Paint::solid(freeink::ui::Color::Black), 2, static_cast<uint8_t>(radius));

  // 3. Title
  freeink::ui::Rect titleRect{static_cast<int16_t>(dx + 20), static_cast<int16_t>(dy + 18), static_cast<int16_t>(dw - 40), 24};
  freeink::ui::TextStyle titleStyle;
  titleStyle.font = SimDrawTarget::FONT_BODY;
  titleStyle.bold = true;
  drawTarget_.text(titleRect, prompt_.title.c_str(), titleStyle);

  // 4. Text input box
  const int bx = dx + 20;
  const int by = dy + 56;
  const int bw = dw - 40;
  const int bh = 44;
  const int fieldRadius = tokens_.controlRadius > 0 ? tokens_.controlRadius : 6;

  freeink::ui::Rect boxRect{static_cast<int16_t>(bx), static_cast<int16_t>(by), static_cast<int16_t>(bw), static_cast<int16_t>(bh)};
  drawTarget_.fill(boxRect, freeink::ui::Paint::solid(freeink::ui::Color::White), static_cast<uint8_t>(fieldRadius));
  drawTarget_.stroke(boxRect, freeink::ui::Paint::solid(freeink::ui::Color::Black), 1, static_cast<uint8_t>(fieldRadius));

  // Text display
  std::string displayStr;
  if (prompt_.inputType == "password") {
    displayStr = std::string(prompt_.text.size(), '*') + "|";
  } else if (!prompt_.text.empty()) {
    displayStr = prompt_.text + "|";
  } else if (!prompt_.placeholder.empty()) {
    displayStr = "|" + (prompt_.placeholder.empty() ? "" : (" (" + prompt_.placeholder + ")"));
  } else {
    displayStr = "|";
  }

  const int textLh = drawTarget_.lineHeight(SimDrawTarget::FONT_BODY);
  freeink::ui::Rect textRect{static_cast<int16_t>(bx + 10), static_cast<int16_t>(by + (bh - textLh) / 2),
                             static_cast<int16_t>(bw - 20), static_cast<int16_t>(textLh)};
  freeink::ui::TextStyle textStyle;
  textStyle.font = SimDrawTarget::FONT_BODY;
  drawTarget_.text(textRect, displayStr.c_str(), textStyle);

  // 5. Buttons
  const int btnW = (dw - 48) / 2;
  const int btnH = 40;
  const int btnY = dy + dh - btnH - 16;
  const int cancelX = dx + 16;
  const int okX = cancelX + btnW + 16;
  const int btnRadius = tokens_.controlRadius > 0 ? tokens_.controlRadius : 6;

  // Cancel Button
  freeink::ui::Rect cancelRect{static_cast<int16_t>(cancelX), static_cast<int16_t>(btnY), static_cast<int16_t>(btnW), static_cast<int16_t>(btnH)};
  drawTarget_.fill(cancelRect, freeink::ui::Paint::solid(freeink::ui::Color::White), static_cast<uint8_t>(btnRadius));
  drawTarget_.stroke(cancelRect, freeink::ui::Paint::solid(freeink::ui::Color::Black), 1, static_cast<uint8_t>(btnRadius));

  freeink::ui::TextStyle cancelStyle;
  cancelStyle.font = SimDrawTarget::FONT_BODY;
  cancelStyle.align = freeink::ui::TextAlign::Center;
  freeink::ui::Rect cancelTextRect{static_cast<int16_t>(cancelX), static_cast<int16_t>(btnY + (btnH - textLh) / 2),
                                   static_cast<int16_t>(btnW), static_cast<int16_t>(textLh)};
  drawTarget_.text(cancelTextRect, "Cancel", cancelStyle);

  // OK Button
  freeink::ui::Rect okRect{static_cast<int16_t>(okX), static_cast<int16_t>(btnY), static_cast<int16_t>(btnW), static_cast<int16_t>(btnH)};
  drawTarget_.fill(okRect, freeink::ui::Paint::solid(freeink::ui::Color::Black), static_cast<uint8_t>(btnRadius));

  freeink::ui::TextStyle okStyle;
  okStyle.font = SimDrawTarget::FONT_BODY;
  okStyle.align = freeink::ui::TextAlign::Center;
  okStyle.color = freeink::ui::Color::White;
  freeink::ui::Rect okTextRect{static_cast<int16_t>(okX), static_cast<int16_t>(btnY + (btnH - textLh) / 2),
                               static_cast<int16_t>(btnW), static_cast<int16_t>(textLh)};
  drawTarget_.text(okTextRect, "OK", okStyle);
}

}  // namespace sim
