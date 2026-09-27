#pragma once

#include <FreeInkUICore.h>
#include <functional>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "FontRenderer.h"
#include "SimDrawTarget.h"
#include "SimRenderer.h"

extern "C" {
#include "../lua/lua.h"
#include "../lua/lauxlib.h"
#include "../lua/lualib.h"
}

namespace sim {

enum class UiThemeType { Lyra = 0, RoundedRaff = 1, Classic = 2 };

using UiInvoker = std::function<int(lua_State* L, int touchX, int touchY, int16_t value)>;

struct UiCallback {
  int luaFuncRef = -1;
  std::string name;
  int16_t value = 0;
  UiInvoker invoker = nullptr;
};

class SimUiHost {
 public:
  static constexpr size_t INTERACTION_CAPACITY = 64;

  SimUiHost(SimRenderer& renderer, FontRenderer& fontRenderer);
  ~SimUiHost();

  void setTheme(UiThemeType type);
  void setThemeByName(const std::string& name);
  UiThemeType getThemeType() const { return currentTheme_; }
  std::string getThemeName() const;
  bool isTabPillFullSlot() const { return currentTheme_ == UiThemeType::RoundedRaff; }
  const freeink::ui::ThemeTokens& getTokens() const { return tokens_; }

  void beginFrame(lua_State* L);
  void endFrame();
  void detachLua();

  bool dispatchTouch(int x, int y, lua_State* L);

  freeink::ui::ActionId registerCallback(lua_State* L, int funcIndex, int16_t value = 0,
                                         const std::string& name = "");
  freeink::ui::ActionId registerCallbackWithInvoker(lua_State* L, int funcIndex, UiInvoker invoker,
                                                    int16_t value = 0, const std::string& name = "");

  struct SimTextPrompt {
    bool active = false;
    std::string title = "Enter Text";
    std::string text;
    std::string placeholder;
    std::string inputType = "text";
    size_t maxLength = 256;
    int confirmLuaRef = -1;
    int cancelLuaRef = -1;
  };

  void showPrompt(const std::string& title, const std::string& initialText,
                  const std::string& placeholder, const std::string& inputType,
                  size_t maxLength, int confirmRef, int cancelRef);
  bool isPromptActive() const { return prompt_.active; }
  const SimTextPrompt& getPrompt() const { return prompt_; }
  void promptAppendText(const char* utf8);
  void promptBackspace();
  void confirmPrompt(lua_State* L);
  void cancelPrompt(lua_State* L);
  bool dispatchPromptTouch(int x, int y, lua_State* L);
  void renderPromptOverlay();

  freeink::ui::Frame<INTERACTION_CAPACITY>* currentFrame() { return frame_.get(); }
  SimDrawTarget& drawTarget() { return drawTarget_; }

  static const freeink::ui::BitmapRef getHeaderBackIcon();

 private:
  SimRenderer& renderer_;
  FontRenderer& fontRenderer_;
  SimDrawTarget drawTarget_;
  UiThemeType currentTheme_ = UiThemeType::Lyra;
  freeink::ui::ThemeTokens tokens_;

  freeink::ui::DeviceContext deviceContext_;
  freeink::ui::InteractionBuffer<INTERACTION_CAPACITY> interactions_;
  freeink::ui::InputSnapshot emptySnap_{};
  std::unique_ptr<freeink::ui::Frame<INTERACTION_CAPACITY>> frame_;

  lua_State* activeL_ = nullptr;
  freeink::ui::ActionId nextActionId_ = 1;
  std::map<freeink::ui::ActionId, UiCallback> callbacks_;
  std::vector<int> luaRefsToClean_;
  SimTextPrompt prompt_;

  void refreshTokens();
  void clearCallbacks(lua_State* L);
};

}  // namespace sim
