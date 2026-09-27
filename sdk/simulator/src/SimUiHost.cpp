#include "SimUiHost.h"

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
            lua_pcall(L, numArgs, 0, errIdx);
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

}  // namespace sim
