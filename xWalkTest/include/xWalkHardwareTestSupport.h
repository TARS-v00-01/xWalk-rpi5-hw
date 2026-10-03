/******************************************************************************
 * @file        xWalkHardwareTestSupport.h
 * @brief       Declares the common multi-board integration fixture.
 * @details     Exercises production composition with device-free HOST providers.
 * @project     xWalk Firmware
 * @module      xWalk Hardware Integration Test
 * @author      Joxy John
 * @date        2026-10-03
 * @version     1.0.0
 * @copyright   Copyright (c) 2026 Joxy John. All rights reserved.
 * @note        Developed using MISRA C++ coding guidelines.
 ******************************************************************************/

#ifndef XWALK_HARDWARE_TEST_SUPPORT_H
#define XWALK_HARDWARE_TEST_SUPPORT_H
#include <gtest/gtest.h>
#include "xControllerOperationTestSupport.h"
#include "xControllerBootPlatform.h"
/** @namespace xwalk::hardware::test
 * @brief Root-level integration sequences across Controller, Driver and HAL.
 */
namespace xwalk::hardware::test
{
    /** @brief Owns one real Boot graph; response capture outlives all borrowed worker callbacks. */
    class XWalkHardwareSequence : public ::testing::TestWithParam<const char*>
    {
        protected:
            /** @brief Writes an isolated board configuration and starts the HOST graph. */
            void SetUp() override;
            /** @brief Joins every worker before releasing graph and capture synchronization. */
            void TearDown() override;
            /** @brief Sends one request and waits for its response and operation lease release.
             * @param[in] signal Request protocol identifier.
             * @param[in] request Borrowed payload copied by Controller submission.
             * @param[in] length Payload size in bytes.
             * @param[in] expected Required terminal response signal.
             */
            void exchange(controller::uint32 signal,
                          const void* request,
                          controller::size length,
                          controller::uint32 expected);
            /** @brief Enters ACTIVE through the production request queue. */
            void activate();
            /** @brief Verifies both motor outputs are zero after cleanup. */
            void expectStopped();
            /** @brief Sends bounded forward or reverse movement through the common protocol.
             * @param[in] reverse True selects reverse; false selects forward.
             */
            void move(controller::boolean reverse);
            /** @brief Capture storage outlives the Boot callbacks. */
            controller::test::OperationCapture capture;
            /** @brief Owns all production dependencies and their worker threads. */
            hal::owningpointer<controller::XWalkBoot> boot;
            /** @brief Test-owned configuration path, never a deployment configuration. */
            controller::string configPath;
            /** @brief Number of acknowledged sequential requests; only the test thread writes it. */
            controller::uint32 responses{0U};
    };
} /* namespace xwalk::hardware::test */
#endif
