/******************************************************************************
 * @file        xWalkLeakSanitizerProbe.cpp
 * @brief       Verifies that the host LeakSanitizer runtime detects a leak.
 *
 * @details
 * Allocates one intentionally unreachable block so the quality script can
 * distinguish a working LeakSanitizer runtime from an unavailable one.
 *
 * @project     xWalk Firmware
 * @module      xWalk-rpi5-tool Quality
 *
 * @author      Joxy John
 * @date        2026-08-13
 * @version     1.0.0
 *
 * @copyright
 * Copyright (c) 2026 Joxy John.
 * All rights reserved.
 *
 * @note
 * Developed using MISRA C++ coding guidelines.
 ******************************************************************************/

/******************************************************************************
 * Includes
 ******************************************************************************/

#include <cstdlib>

/******************************************************************************
 * Global function definitions
 ******************************************************************************/

/**
 * @brief Allocates one intentionally leaked block for the sanitizer probe.
 *
 * @return
 * Zero when allocation succeeds; one when allocation fails.
 *
 * @post
 * A successful allocation is unreachable when LeakSanitizer performs its
 * process-exit analysis.
 */
int main()
{
    void* volatile allocation = std::malloc(64U);
    const bool allocationFailed = allocation == nullptr;
    allocation = nullptr;
    return allocationFailed ? 1 : 0;
}
