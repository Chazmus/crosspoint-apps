cmake_minimum_required(VERSION 3.16)
project(crosspoint-sim LANGUAGES C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED IMPORTED_TARGET sdl2)
pkg_check_modules(CURL REQUIRED IMPORTED_TARGET libcurl)

file(GLOB LUA_SOURCES "lua/*.c")
file(GLOB SIM_SOURCES "src/*.cpp")

add_executable(crosspoint-sim ${LUA_SOURCES} ${SIM_SOURCES})

target_include_directories(crosspoint-sim PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/lua
    ${CMAKE_CURRENT_SOURCE_DIR}/stb
)

target_link_libraries(crosspoint-sim PRIVATE
    PkgConfig::SDL2
    PkgConfig::CURL
    pthread
    dl
    m
)

# Ensure assets are copied next to binary for convenient portable runs
add_custom_command(TARGET crosspoint-sim POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_SOURCE_DIR}/assets
        $<TARGET_FILE_DIR:crosspoint-sim>/assets
)
