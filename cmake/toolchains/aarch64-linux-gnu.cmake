set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Compiler ABI checks re-enter this toolchain in an isolated try-compile
# project. Preserve the reviewed sysroot selection there so the guard below
# cannot fail merely because CMake dropped a caller cache variable.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES XWALK_AARCH64_SYSROOT)

if(NOT DEFINED XWALK_AARCH64_SYSROOT OR XWALK_AARCH64_SYSROOT STREQUAL "")
    message(FATAL_ERROR
        "Set XWALK_AARCH64_SYSROOT to a reviewed ARM64 root filesystem containing usr/include and usr/lib")
endif()

file(REAL_PATH "${XWALK_AARCH64_SYSROOT}" XWALK_AARCH64_SYSROOT_REAL)
if(NOT IS_DIRECTORY "${XWALK_AARCH64_SYSROOT_REAL}/usr/include" OR
    NOT IS_DIRECTORY "${XWALK_AARCH64_SYSROOT_REAL}/usr/lib")
    message(FATAL_ERROR
        "XWALK_AARCH64_SYSROOT must contain ARM64 usr/include and usr/lib directories")
endif()

find_program(XWALK_AARCH64_C_COMPILER aarch64-linux-gnu-gcc REQUIRED)
find_program(XWALK_AARCH64_CXX_COMPILER aarch64-linux-gnu-g++ REQUIRED)
set(CMAKE_C_COMPILER "${XWALK_AARCH64_C_COMPILER}")
set(CMAKE_CXX_COMPILER "${XWALK_AARCH64_CXX_COMPILER}")
set(CMAKE_SYSROOT "${XWALK_AARCH64_SYSROOT_REAL}")
set(CMAKE_FIND_ROOT_PATH
    "${XWALK_AARCH64_SYSROOT_REAL}"
    "${CMAKE_CURRENT_LIST_DIR}/../../xWalkLibrary/aarch64")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(XWALK_LIBRARY_ARCHITECTURE aarch64 CACHE STRING "Target dependency architecture" FORCE)

# pkg-config is a host tool, but every .pc file and path that it returns must
# come from the reviewed target sysroot. Clearing PKG_CONFIG_PATH prevents a
# developer shell setting from silently introducing x86 metadata.
set(XWALK_AARCH64_PKG_CONFIG_DIRECTORIES
    "${XWALK_AARCH64_SYSROOT_REAL}/usr/lib/aarch64-linux-gnu/pkgconfig:"
    "${XWALK_AARCH64_SYSROOT_REAL}/usr/lib/pkgconfig:"
    "${XWALK_AARCH64_SYSROOT_REAL}/usr/share/pkgconfig")
string(CONCAT XWALK_AARCH64_PKG_CONFIG_LIBDIR
    ${XWALK_AARCH64_PKG_CONFIG_DIRECTORIES})
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${XWALK_AARCH64_SYSROOT_REAL}")
set(ENV{PKG_CONFIG_LIBDIR} "${XWALK_AARCH64_PKG_CONFIG_LIBDIR}")
set(ENV{PKG_CONFIG_PATH} "")
set(PKG_CONFIG_USE_CMAKE_PREFIX_PATH FALSE CACHE BOOL
    "Keep host CMake prefixes out of target pkg-config lookup" FORCE)

message(STATUS "xWalk AArch64 sysroot: ${XWALK_AARCH64_SYSROOT_REAL}")
