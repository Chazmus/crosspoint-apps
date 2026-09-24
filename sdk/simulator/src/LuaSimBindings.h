#pragma once

#include <string>

extern "C" {
#include "../lua/lua.h"
#include "../lua/lauxlib.h"
#include "../lua/lualib.h"
}

namespace sim {

class SimRenderer;
class SimStorage;

struct SimContext {
  SimRenderer* renderer = nullptr;
  SimStorage* storage = nullptr;
  std::string appDir;
  std::string sleepAppId;
  bool updateRequested = false;
  bool orientationChanged = false;
  bool shouldFinish = false;
  bool isTouchDown = false;
  int touchX = 0;
  int touchY = 0;
  bool wasTouchDown = false;
  bool wasTouchReleased = false;
};

void registerSimBindings(lua_State* L, SimContext* ctx);

}  // namespace sim
