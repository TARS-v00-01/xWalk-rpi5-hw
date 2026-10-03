find_package(GTest CONFIG REQUIRED)
add_executable(xWalkHardwareSequenceTest
    src/xWalkHardwareSequenceTest.cpp
    src/xWalkHardwareTestSupport.cpp
    ${PROJECT_SOURCE_DIR}/xWalkController/test/src/xControllerOperationTestSupport.cpp)
target_include_directories(xWalkHardwareSequenceTest PRIVATE include
    ${PROJECT_SOURCE_DIR}/xWalkController/test/include)
target_compile_features(xWalkHardwareSequenceTest PRIVATE cxx_std_17)
target_link_libraries(xWalkHardwareSequenceTest PRIVATE GTest::gtest_main xWalkControllerBoot xWalkUtilsLinux xWalkRobotHatSimulation)
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/test-data/device-tree")
target_compile_definitions(xWalkHardwareSequenceTest PRIVATE
    XWALK_HW_TEST_DIRECTORY="${CMAKE_CURRENT_BINARY_DIR}/test-data")
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(xWalkHardwareSequenceTest PRIVATE
        -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -UNDEBUG)
endif()
add_test(NAME xWalkHardwareSequenceHostTest COMMAND xWalkHardwareSequenceTest)
set_tests_properties(xWalkHardwareSequenceHostTest PROPERTIES
    LABELS "host;hw-integration;sequence" TIMEOUT 90 RUN_SERIAL TRUE)
add_custom_target(xWalkHardwareFullTest
    COMMAND python3 "${PROJECT_SOURCE_DIR}/ci/run-module-tests.py"
        --build-dir "${CMAKE_BINARY_DIR}" --no-build
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    USES_TERMINAL)
find_package(Python3 COMPONENTS Interpreter REQUIRED)
add_test(NAME xWalkHardwareRunnerHostTest
    COMMAND ${Python3_EXECUTABLE} -B "${PROJECT_SOURCE_DIR}/ci/test-module-runner.py")
set_tests_properties(xWalkHardwareRunnerHostTest PROPERTIES LABELS "host;hw-integration" TIMEOUT 15)
