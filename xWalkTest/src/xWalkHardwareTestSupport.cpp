/******************************************************************************
 * @file        xWalkHardwareTestSupport.cpp
 * @brief       Implements shared board configuration and bounded request execution.
 * @details     Exercises production composition with device-free HOST providers.
 * @project     xWalk Firmware
 * @module      xWalk Hardware Integration Test
 * @author      Joxy John
 * @date        2026-10-03
 * @version     1.0.0
 * @copyright   Copyright (c) 2026 Joxy John. All rights reserved.
 * @note        Developed using MISRA C++ coding guidelines.
 ******************************************************************************/

#include "xWalkHardwareTestSupport.h"
#include "xHal_Rpi5CarFileFunctions.h"
#include <chrono>
#include <thread>
/** @namespace xwalk::hardware::test
 * @brief Host-only integration fixture implementation.
 */
namespace xwalk::hardware::test
{
    using namespace controller;
    /** @brief Constructs the parameter-selected production graph without physical providers. */
    void XWalkHardwareSequence::SetUp()
    {
        configPath = string(XWALK_HW_TEST_DIRECTORY) + "/" + GetParam() + ".conf";
        outputfilestream output(configPath);
        output << "hardware_board = " << GetParam() << "\n"
               << "hardware_device_tree_root = " XWALK_HW_TEST_DIRECTORY "/device-tree\n"
               << "hardware_mcu_reset_settle_ms = 1\n"
               << "picarx_calibration_verified = true\n"
               << "picarx_max_motor_output_percent = 20\n";
        output.close();
        ASSERT_TRUE(static_cast<boolean>(output));
        XWalkCoreCallbacks hooks;
        hooks.response = controller::test::captureOperation;
        hooks.context = &capture;
        boot.reset(XWalkBoot::create(hooks, configPath.c_str()));
        ASSERT_NE(boot, nullptr);
        ASSERT_STREQ(boot->platform(), "host");
        capture.observedMotors = boot->modules()->motors;
        const boolean started = boot->start();
        ASSERT_TRUE(started);
    }
    /** @brief Stops workers and releases synchronization only after graph destruction. */
    void XWalkHardwareSequence::TearDown()
    {
        const boolean created = boot != nullptr;
        if (created)
        {
            const boolean stopped = boot->stop();
            EXPECT_TRUE(stopped);
            expectStopped();
            boot.reset();
        }
        pthread_cond_destroy(&capture.ready);
        pthread_mutex_destroy(&capture.mutex);
    }
    /** @brief Waits for one terminal response and idle operation before inspecting shared state.
     * @param[in] signal Request protocol identifier.
     * @param[in] request Borrowed request copied before return from submit.
     * @param[in] length Payload bytes.
     * @param[in] expected Required terminal response identifier.
     */
    void XWalkHardwareSequence::exchange(uint32 signal, const void* request, size length, uint32 expected)
    {
        const boolean submitted = boot->submit(signal, request, length);
        ASSERT_TRUE(submitted);
        controller::test::waitOperations(capture, ++responses);
        boolean idle = false;
        for (uint32 attempt = 0U; attempt < 5000U && !idle; ++attempt)
        {
            idle = boot->operationIdle();
            if (!idle)
            {
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
            }
        }
        ASSERT_TRUE(idle);
        EXPECT_EQ(capture.signals[responses - 1U], expected);
    }
    /** @brief Activates all simulated actuators through the Controller lifecycle. */
    void XWalkHardwareSequence::activate()
    {
        LifeMoveReq request{};
        request.target = iw::v1::plain::XWALK_LIFE_STATE_ACTIVE;
        exchange(XWALK_LIFE_MOVE_REQ, &request, sizeof(request), XWALK_LIFE_MOVE_CFM);
        EXPECT_TRUE(boot->modules()->picarx->isInitialized());
    }
    /** @brief Checks settled outputs only after a completed operation or joined workers. */
    void XWalkHardwareSequence::expectStopped()
    {
        EXPECT_DOUBLE_EQ(boot->modules()->motors->left().speed(), 0.0);
        EXPECT_DOUBLE_EQ(boot->modules()->motors->right().speed(), 0.0);
    }
    /** @brief Executes bounded motion and verifies terminal motor cleanup.
     * @param[in] reverse Selects backward rather than forward drive.
     */
    void XWalkHardwareSequence::move(boolean reverse)
    {
        boot->modules()->platform->simulation.clearEvents();
        MoveReq request{};
        request.has_request = true;
        request.request.action = static_cast<decltype(request.request.action)>(reverse ? 1 : 0);
        request.request.has_speed_percent = true;
        request.request.speed_percent = 10.0;
        request.request.has_duration_ms = true;
        request.request.duration_ms = 10U;
        exchange(XWALK_CNTRL_MOVE_REQ, &request, sizeof(request), XWALK_CNTRL_MOVE_CFM);
        expectStopped();
        boolean poweredMotor = false;
        const auto events = boot->modules()->platform->simulation.events();
        for (const auto& event : events)
        {
            const boolean motorOutput = event.operation == hal::simulation::XWalkRobotHatOperation::I2cWrite &&
                                        event.target >= 0x2CU && event.target <= 0x2FU && event.data.size() == 2U;
            if (motorOutput)
            {
                poweredMotor = poweredMotor || event.data[0U] != 0U || event.data[1U] != 0U;
            }
        }
        EXPECT_TRUE(poweredMotor) << "Movement must reach a real HAL motor PWM write";
    }
} /* namespace xwalk::hardware::test */
