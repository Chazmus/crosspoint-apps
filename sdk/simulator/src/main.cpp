#include <SDL2/SDL.h>
#include <sys/stat.h>
#include <unistd.h>

#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

#include "FontRenderer.h"
#include "LuaSimBindings.h"
#include "SimRenderer.h"
#include "SimStorage.h"

namespace fs = std::filesystem;

namespace {

time_t getFileModTime(const std::string& path) {
  struct stat st;
  if (stat(path.c_str(), &st) == 0) {
    return st.st_mtime;
  }
  return 0;
}

std::string findAssetsDir(const std::string& execPath) {
  // Check relative to executable
  fs::path p(execPath);
  fs::path dir = p.parent_path();
  std::vector<fs::path> candidates = {
      dir / "assets",
      dir / "../assets",
      dir / "../../assets",
      fs::current_path() / "sdk/simulator/assets",
      fs::current_path() / "simulator/assets",
      fs::current_path() / "assets",
  };
  for (const auto& c : candidates) {
    if (fs::exists(c) && fs::exists(c / "fonts")) {
      return fs::canonical(c).string();
    }
  }
  return "./assets";
}

std::string getManifestOrientation(const std::string& appDir) {
  const std::string manifestPath = appDir + "/manifest.json";
  std::ifstream f(manifestPath);
  if (!f) return "portrait";
  std::string content((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
  const size_t pos = content.find("\"orientation\"");
  if (pos != std::string::npos) {
    const size_t colon = content.find(':', pos);
    if (colon != std::string::npos) {
      const size_t quote1 = content.find('\"', colon);
      if (quote1 != std::string::npos) {
        const size_t quote2 = content.find('\"', quote1 + 1);
        if (quote2 != std::string::npos) {
          return content.substr(quote1 + 1, quote2 - quote1 - 1);
        }
      }
    }
  }
  return "portrait";
}

int luaTraceback(lua_State* L) {
  const char* msg = lua_tostring(L, 1);
  if (!msg) {
    if (luaL_callmeta(L, 1, "__tostring") && lua_type(L, -1) == LUA_TSTRING) {
      return 1;
    }
    msg = "(error object is not a string)";
  }
  luaL_traceback(L, L, msg, 1);
  return 1;
}

}  // namespace

int main(int argc, char* argv[]) {
  std::string appDir;
  std::string screenshotPath;
  bool screenshotSleep = false;
  std::string forcedOrientation;
  bool enableProfiling = false;

  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    if (arg == "--screenshot" && i + 1 < argc) {
      screenshotPath = argv[++i];
    } else if (arg == "--screenshot-sleep" && i + 1 < argc) {
      screenshotPath = argv[++i];
      screenshotSleep = true;
    } else if (arg == "--landscape" || arg == "-l") {
      forcedOrientation = "landscape";
    } else if (arg == "--portrait" || arg == "-p") {
      forcedOrientation = "portrait";
    } else if (arg == "--profile") {
      enableProfiling = true;
    } else if (arg[0] != '-') {
      appDir = arg;
    }
  }

  if (appDir.empty()) {
    std::cout << "CrossPoint Lua App Simulator" << std::endl;
    std::cout << "Usage: " << argv[0] << " [options] <path_to_app_dir>" << std::endl;
    std::cout << "Options:" << std::endl;
    std::cout << "  -p, --portrait                Run in Portrait mode (480x800)" << std::endl;
    std::cout << "  -l, --landscape               Run in Landscape mode (800x480)" << std::endl;
    std::cout << "  --profile                     Enable performance profiling logs" << std::endl;
    std::cout << "  --screenshot <out.bmp>        Render app initial frame and save BMP" << std::endl;
    std::cout << "  --screenshot-sleep <out.bmp>  Render app sleep screen and save BMP" << std::endl;
    std::cout << "Example: " << argv[0] << " apps/counter" << std::endl;
    return 1;
  }

  // Remove trailing slash if present
  while (!appDir.empty() && appDir.back() == '/') {
    appDir.pop_back();
  }

  const std::string mainLuaPath = appDir + "/main.lua";
  if (!fs::exists(mainLuaPath)) {
    std::cerr << "Error: App main script not found at " << mainLuaPath << std::endl;
    return 1;
  }

  std::string orientStr = forcedOrientation;
  if (orientStr.empty()) {
    orientStr = getManifestOrientation(appDir);
  }

  const bool isLandscape = (orientStr == "landscape" || orientStr == "landscape_cw" || orientStr == "landscape_ccw");
  const int initWidth = isLandscape ? sim::SimRenderer::LANDSCAPE_WIDTH : sim::SimRenderer::PORTRAIT_WIDTH;
  const int initHeight = isLandscape ? sim::SimRenderer::LANDSCAPE_HEIGHT : sim::SimRenderer::PORTRAIT_HEIGHT;
  const sim::Orientation initOrient = isLandscape ? sim::Orientation::Landscape : sim::Orientation::Portrait;

  if (!screenshotPath.empty()) {
    const std::string assetsDir = findAssetsDir(argv[0]);
    sim::FontRenderer fontRenderer;
    fontRenderer.loadFonts(assetsDir);

    sim::SimRenderer simRenderer(fontRenderer, initWidth, initHeight);
    simRenderer.setOrientation(initOrient);

    sim::SimStorage simStorage(appDir);
    sim::SimContext simCtx;
    simCtx.renderer = &simRenderer;
    simCtx.storage = &simStorage;
    simCtx.appDir = appDir;

    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    sim::registerSimBindings(L, &simCtx);

    std::ifstream file(mainLuaPath, std::ios::binary);
    std::string script((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());

    const int errIdx = lua_gettop(L) + 1;
    lua_pushcfunction(L, luaTraceback);

    if (luaL_loadbuffer(L, script.data(), script.size(), mainLuaPath.c_str()) != LUA_OK ||
        lua_pcall(L, 0, 0, errIdx) != LUA_OK) {
      std::cerr << "[Lua Load Error] " << lua_tostring(L, -1) << std::endl;
      lua_close(L);
      return 1;
    }
    lua_remove(L, errIdx);

    lua_getglobal(L, "onEnter");
    if (lua_isfunction(L, -1)) {
      const int enterErrIdx = lua_gettop(L);
      lua_pushcfunction(L, luaTraceback);
      lua_insert(L, enterErrIdx);
      if (lua_pcall(L, 0, 0, enterErrIdx) != LUA_OK) {
        std::cerr << "[Lua onEnter Error] " << lua_tostring(L, -1) << std::endl;
      }
      lua_remove(L, enterErrIdx);
    } else {
      lua_pop(L, 1);
    }

    simRenderer.clearScreen(1);
    const char* drawFn = screenshotSleep ? "onSleepDraw" : "onDraw";
    const auto drawT0 = std::chrono::steady_clock::now();
    lua_getglobal(L, drawFn);
    if (lua_isfunction(L, -1)) {
      const int drawErrIdx = lua_gettop(L);
      lua_pushcfunction(L, luaTraceback);
      lua_insert(L, drawErrIdx);
      if (lua_pcall(L, 0, 0, drawErrIdx) != LUA_OK) {
        std::cerr << "[Lua " << drawFn << " Error] " << lua_tostring(L, -1) << std::endl;
      }
      lua_remove(L, drawErrIdx);
    } else {
      lua_pop(L, 1);
    }
    const auto drawT1 = std::chrono::steady_clock::now();
    if (enableProfiling) {
      const double ms = std::chrono::duration<double, std::milli>(drawT1 - drawT0).count();
      const int memKb = lua_gc(L, LUA_GCCOUNT, 0);
      std::cout << "[Profile] " << drawFn << " execution: " << ms << " ms | Lua RAM: " << memKb << " KB" << std::endl;
    }

    if (simRenderer.saveBmp(screenshotPath)) {
      std::cout << "[Simulator] Screenshot saved to " << screenshotPath << std::endl;
    } else {
      std::cerr << "[Simulator] Failed to save screenshot to " << screenshotPath << std::endl;
    }

    lua_getglobal(L, "onExit");
    if (lua_isfunction(L, -1)) {
      const int exitErrIdx = lua_gettop(L);
      lua_pushcfunction(L, luaTraceback);
      lua_insert(L, exitErrIdx);
      lua_pcall(L, 0, 0, exitErrIdx);
      lua_remove(L, exitErrIdx);
    } else {
      lua_pop(L, 1);
    }
    lua_close(L);
    return 0;
  }

  // Initialize SDL2
  if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0) {
    std::cerr << "SDL_Init Error: " << SDL_GetError() << std::endl;
    return 1;
  }

  const std::string appName = fs::path(appDir).filename().string();
  const std::string windowTitle = "CrossPoint Simulator - " + appName + "  [O: Rotate | S: Sleep | R: Reload | P: Screenshot | T: Profile]";

  SDL_Window* window = SDL_CreateWindow(windowTitle.c_str(), SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                                        initWidth, initHeight,
                                        SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);
  if (!window) {
    std::cerr << "SDL_CreateWindow Error: " << SDL_GetError() << std::endl;
    SDL_Quit();
    return 1;
  }

  SDL_Renderer* sdlRenderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!sdlRenderer) {
    sdlRenderer = SDL_CreateRenderer(window, -1, 0);
  }
  if (!sdlRenderer) {
    std::cerr << "SDL_CreateRenderer Error: " << SDL_GetError() << std::endl;
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
  }

  SDL_RenderSetLogicalSize(sdlRenderer, initWidth, initHeight);

  SDL_Texture* texture = SDL_CreateTexture(sdlRenderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING,
                                          initWidth, initHeight);
  if (!texture) {
    std::cerr << "SDL_CreateTexture Error: " << SDL_GetError() << std::endl;
    SDL_DestroyRenderer(sdlRenderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 1;
  }

  // Initialize Simulator Subsystems
  const std::string assetsDir = findAssetsDir(argv[0]);
  sim::FontRenderer fontRenderer;
  if (!fontRenderer.loadFonts(assetsDir)) {
    std::cerr << "[Simulator] Warning: TTF fonts not found in " << assetsDir << std::endl;
  }

  sim::SimRenderer simRenderer(fontRenderer, initWidth, initHeight);
  simRenderer.setOrientation(initOrient);

  sim::SimStorage simStorage(appDir);
  sim::SimContext simCtx;
  simCtx.renderer = &simRenderer;
  simCtx.storage = &simStorage;
  simCtx.appDir = appDir;

  lua_State* L = nullptr;
  time_t lastModTime = 0;
  bool isSleepPreview = false;

  const auto callLua = [&](const char* fnName) {
    if (!L) return;
    const int errIdx = lua_gettop(L) + 1;
    lua_pushcfunction(L, luaTraceback);
    lua_getglobal(L, fnName);
    if (lua_isfunction(L, -1)) {
      if (lua_pcall(L, 0, 0, errIdx) != LUA_OK) {
        std::cerr << "[Lua Error in " << fnName << "] " << lua_tostring(L, -1) << std::endl;
        lua_pop(L, 1);
      }
    } else {
      lua_pop(L, 1);
    }
    lua_remove(L, errIdx);
  };

  const auto redraw = [&]() {
    const auto t0 = std::chrono::steady_clock::now();
    simRenderer.clearScreen(1);
    if (isSleepPreview) {
      callLua("onSleepDraw");
    } else {
      callLua("onDraw");
    }
    SDL_UpdateTexture(texture, nullptr, simRenderer.getPixels(), simRenderer.getWidth() * sizeof(uint32_t));
    SDL_RenderClear(sdlRenderer);
    SDL_RenderCopy(sdlRenderer, texture, nullptr, nullptr);
    SDL_RenderPresent(sdlRenderer);
    const auto t1 = std::chrono::steady_clock::now();
    if (enableProfiling) {
      const double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
      const int memKb = L ? lua_gc(L, LUA_GCCOUNT, 0) : 0;
      std::cout << "[Profile] " << (isSleepPreview ? "onSleepDraw" : "onDraw")
                << " frame: " << ms << " ms | Lua RAM: " << memKb << " KB" << std::endl;
    }
  };

  const auto applyOrientationChange = [&](int newW, int newH, sim::Orientation newOrient) {
    simRenderer.setDimensions(newW, newH);
    simRenderer.setOrientation(newOrient);
    SDL_SetWindowSize(window, newW, newH);
    SDL_RenderSetLogicalSize(sdlRenderer, newW, newH);
    if (texture) SDL_DestroyTexture(texture);
    texture = SDL_CreateTexture(sdlRenderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, newW, newH);
    std::cout << "[Simulator] Orientation is now " << (newW > newH ? "Landscape (800x480)" : "Portrait (480x800)") << std::endl;
    redraw();
  };

  const auto loadApp = [&]() {
    if (L) {
      callLua("onExit");
      lua_close(L);
      L = nullptr;
    }

    std::cout << "[Simulator] Loading " << mainLuaPath << "..." << std::endl;
    L = luaL_newstate();
    luaL_openlibs(L);
    sim::registerSimBindings(L, &simCtx);

    std::ifstream file(mainLuaPath, std::ios::binary);
    std::string script((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());

    const int errIdx = lua_gettop(L) + 1;
    lua_pushcfunction(L, luaTraceback);

    if (luaL_loadbuffer(L, script.data(), script.size(), mainLuaPath.c_str()) != LUA_OK ||
        lua_pcall(L, 0, 0, errIdx) != LUA_OK) {
      std::cerr << "[Lua Load Error] " << lua_tostring(L, -1) << std::endl;
      lua_pop(L, 1);
      lua_remove(L, errIdx);
      return;
    }
    lua_remove(L, errIdx);

    lastModTime = getFileModTime(mainLuaPath);
    callLua("onEnter");
    redraw();
    std::cout << "[Simulator] App loaded successfully!" << std::endl;
  };

  loadApp();

  bool running = true;
  auto lastUpdateTick = std::chrono::steady_clock::now();
  auto lastCheckTick = std::chrono::steady_clock::now();

  while (running) {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) {
        running = false;
        break;
      }

      if (e.type == SDL_MOUSEBUTTONDOWN && e.button.button == SDL_BUTTON_LEFT) {
        simCtx.isTouchDown = true;
        simCtx.touchX = e.button.x;
        simCtx.touchY = e.button.y;
        simCtx.wasTouchDown = true;
        if (!isSleepPreview && L) {
          const int errIdx = lua_gettop(L) + 1;
          lua_pushcfunction(L, luaTraceback);
          lua_getglobal(L, "onTouchDown");
          if (lua_isfunction(L, -1)) {
            lua_pushinteger(L, e.button.x);
            lua_pushinteger(L, e.button.y);
            if (lua_pcall(L, 2, 0, errIdx) != LUA_OK) {
              std::cerr << "[Lua onTouchDown Error] " << lua_tostring(L, -1) << std::endl;
              lua_pop(L, 1);
            }
          } else {
            lua_pop(L, 1);
          }
          lua_remove(L, errIdx);
        }
      }

      if (e.type == SDL_MOUSEMOTION) {
        if (simCtx.isTouchDown) {
          simCtx.touchX = e.motion.x;
          simCtx.touchY = e.motion.y;
        }
      }

      if (e.type == SDL_MOUSEBUTTONUP && e.button.button == SDL_BUTTON_LEFT) {
        simCtx.isTouchDown = false;
        simCtx.touchX = e.button.x;
        simCtx.touchY = e.button.y;
        simCtx.wasTouchReleased = true;
        if (!isSleepPreview && L) {
          const int upErrIdx = lua_gettop(L) + 1;
          lua_pushcfunction(L, luaTraceback);
          lua_getglobal(L, "onTouchUp");
          if (lua_isfunction(L, -1)) {
            lua_pushinteger(L, e.button.x);
            lua_pushinteger(L, e.button.y);
            if (lua_pcall(L, 2, 0, upErrIdx) != LUA_OK) {
              std::cerr << "[Lua onTouchUp Error] " << lua_tostring(L, -1) << std::endl;
              lua_pop(L, 1);
            }
          } else {
            lua_pop(L, 1);
          }
          lua_remove(L, upErrIdx);

          const auto t0 = std::chrono::steady_clock::now();
          const int errIdx = lua_gettop(L) + 1;
          lua_pushcfunction(L, luaTraceback);
          lua_getglobal(L, "onTouch");
          if (lua_isfunction(L, -1)) {
            lua_pushinteger(L, e.button.x);
            lua_pushinteger(L, e.button.y);
            if (lua_pcall(L, 2, 0, errIdx) != LUA_OK) {
              std::cerr << "[Lua onTouch Error] " << lua_tostring(L, -1) << std::endl;
              lua_pop(L, 1);
            }
          } else {
            lua_pop(L, 1);
          }
          lua_remove(L, errIdx);
          const auto t1 = std::chrono::steady_clock::now();
          if (enableProfiling) {
            const double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
            std::cout << "[Profile] onTouch(" << e.button.x << ", " << e.button.y << "): " << ms << " ms" << std::endl;
          }
          redraw();
        }
      }

      if (e.type == SDL_KEYDOWN) {
        const SDL_Keycode key = e.key.keysym.sym;

        if (key == SDLK_o) {
          const bool toLandscape = (simRenderer.getWidth() == sim::SimRenderer::PORTRAIT_WIDTH);
          const int newW = toLandscape ? sim::SimRenderer::LANDSCAPE_WIDTH : sim::SimRenderer::PORTRAIT_WIDTH;
          const int newH = toLandscape ? sim::SimRenderer::LANDSCAPE_HEIGHT : sim::SimRenderer::PORTRAIT_HEIGHT;
          applyOrientationChange(newW, newH, toLandscape ? sim::Orientation::Landscape : sim::Orientation::Portrait);
          continue;
        }

        if (key == SDLK_s) {
          // Toggle Sleep Screen Preview
          isSleepPreview = !isSleepPreview;
          std::cout << "[Simulator] Sleep preview: " << (isSleepPreview ? "ON" : "OFF") << std::endl;
          if (isSleepPreview) {
            callLua("onEnter");  // Match firmware: onEnter is called before onSleepDraw
          }
          redraw();
          continue;
        }

        if (key == SDLK_r) {
          // Hot reload
          std::cout << "[Simulator] Manual reload requested." << std::endl;
          loadApp();
          continue;
        }

        if (key == SDLK_p) {
          std::string shotFile = "screenshot.bmp";
          if (simRenderer.saveBmp(shotFile)) {
            std::cout << "[Simulator] Screenshot saved to " << shotFile << std::endl;
          }
          continue;
        }

        if (key == SDLK_t) {
          enableProfiling = !enableProfiling;
          std::cout << "[Simulator] Performance Profiling: " << (enableProfiling ? "ENABLED" : "DISABLED") << std::endl;
          continue;
        }

        if (!isSleepPreview && L) {
          int buttonId = -1;
          switch (key) {
            case SDLK_ESCAPE:
            case SDLK_BACKSPACE:
              buttonId = 0;  // BTN_BACK
              break;
            case SDLK_RETURN:
            case SDLK_SPACE:
              buttonId = 1;  // BTN_CONFIRM
              break;
            case SDLK_LEFT:
              buttonId = 2;  // BTN_LEFT
              break;
            case SDLK_RIGHT:
              buttonId = 3;  // BTN_RIGHT
              break;
            case SDLK_UP:
            case SDLK_PAGEUP:
              buttonId = 4;  // BTN_UP (Left physical button on X4)
              break;
            case SDLK_DOWN:
            case SDLK_PAGEDOWN:
              buttonId = 5;  // BTN_DOWN (Right physical button on X4)
              break;
            default:
              break;
          }

          if (buttonId == 0) {
            // Check onBack()
            const int errIdx = lua_gettop(L) + 1;
            lua_pushcfunction(L, luaTraceback);
            lua_getglobal(L, "onBack");
            if (lua_isfunction(L, -1)) {
              if (lua_pcall(L, 0, 1, errIdx) == LUA_OK) {
                const bool consumed = lua_toboolean(L, -1);
                lua_pop(L, 1);
                lua_remove(L, errIdx);
                if (consumed) {
                  redraw();
                  continue;
                }
              } else {
                std::cerr << "[Lua onBack Error] " << lua_tostring(L, -1) << std::endl;
                lua_pop(L, 1);
                lua_remove(L, errIdx);
              }
            } else {
              lua_pop(L, 2);
            }
          }

          if (buttonId >= 0) {
            const int errIdx = lua_gettop(L) + 1;
            lua_pushcfunction(L, luaTraceback);
            lua_getglobal(L, "onInput");
            if (lua_isfunction(L, -1)) {
              lua_pushinteger(L, buttonId);
              lua_pushinteger(L, 1);  // isDown
              if (lua_pcall(L, 2, 0, errIdx) != LUA_OK) {
                std::cerr << "[Lua onInput Error] " << lua_tostring(L, -1) << std::endl;
                lua_pop(L, 1);
              }
            } else {
              lua_pop(L, 1);
            }
            lua_remove(L, errIdx);
            redraw();
          }
        }
      }
    }

    // Clear one-shot touch transition flags after event pump
    simCtx.wasTouchDown = false;
    simCtx.wasTouchReleased = false;

    if (simCtx.shouldFinish) {
      std::cout << "[Simulator] App requested finish." << std::endl;
      running = false;
      break;
    }

    if (simCtx.orientationChanged) {
      simCtx.orientationChanged = false;
      applyOrientationChange(simRenderer.getWidth(), simRenderer.getHeight(), simRenderer.getOrientation());
    }

    if (simCtx.updateRequested) {
      simCtx.updateRequested = false;
      redraw();
    }

    const auto now = std::chrono::steady_clock::now();

    // 50ms onUpdate(dt) tick
    const auto updateElapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastUpdateTick).count();
    if (updateElapsed >= 50) {
      const float dt = updateElapsed / 1000.0f;
      lastUpdateTick = now;
      if (!isSleepPreview && L) {
        const int errIdx = lua_gettop(L) + 1;
        lua_pushcfunction(L, luaTraceback);
        lua_getglobal(L, "onUpdate");
        if (lua_isfunction(L, -1)) {
          lua_pushnumber(L, dt);
          if (lua_pcall(L, 1, 0, errIdx) != LUA_OK) {
            std::cerr << "[Lua onUpdate Error] " << lua_tostring(L, -1) << std::endl;
            lua_pop(L, 1);
          }
        } else {
          lua_pop(L, 1);
        }
        lua_remove(L, errIdx);
      }
    }

    // Live Hot-Reload: check file modification every 300ms
    const auto checkElapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastCheckTick).count();
    if (checkElapsed >= 300) {
      lastCheckTick = now;
      const time_t curMod = getFileModTime(mainLuaPath);
      if (curMod > lastModTime) {
        std::cout << "[Simulator] Detected file change in " << mainLuaPath << ". Hot reloading..." << std::endl;
        loadApp();
      }
    }

    SDL_Delay(10);
  }

  if (L) {
    callLua("onExit");
    lua_close(L);
  }

  SDL_DestroyTexture(texture);
  SDL_DestroyRenderer(sdlRenderer);
  SDL_DestroyWindow(window);
  SDL_Quit();

  return 0;
}
