cmake_minimum_required(VERSION 3.16)
project(xWalkFuzz LANGUAGES CXX)

if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "XWALK_BUILD_FUZZERS requires Clang with libFuzzer")
endif()

find_package(OpenCV 4 REQUIRED COMPONENTS core imgcodecs)
find_package(PkgConfig REQUIRED)
pkg_check_modules(JSONC REQUIRED IMPORTED_TARGET json-c)

set(XWALK_FUZZ_TARGETS
    configuration protobuf grpc http_requests camera_sources model_metadata
    scenarios i2c_payloads image_decode)

set(fuzz_kind 1)
foreach(fuzz_name IN LISTS XWALK_FUZZ_TARGETS)
    set(target_name "xWalkFuzz_${fuzz_name}")
    add_executable(${target_name} src/xWalk_Rpi5CarFuzzHarness.cpp)
    target_compile_definitions(${target_name} PRIVATE XWALK_FUZZ_KIND=${fuzz_kind})
    target_compile_options(${target_name} PRIVATE
        -fsanitize=fuzzer,address,undefined -fno-omit-frame-pointer)
    target_link_options(${target_name} PRIVATE
        -fsanitize=fuzzer,address,undefined -fno-omit-frame-pointer)
    target_link_libraries(${target_name} PRIVATE
        xWalkLibraryCommon xWalkIwGrpc xWalkCamera xWalkVideoStreaming
        PkgConfig::JSONC opencv_core opencv_imgcodecs)
    math(EXPR fuzz_kind "${fuzz_kind} + 1")
endforeach()

add_custom_target(xWalkFuzzers DEPENDS
    xWalkFuzz_configuration xWalkFuzz_protobuf xWalkFuzz_grpc
    xWalkFuzz_http_requests xWalkFuzz_camera_sources xWalkFuzz_model_metadata
    xWalkFuzz_scenarios xWalkFuzz_i2c_payloads xWalkFuzz_image_decode)
