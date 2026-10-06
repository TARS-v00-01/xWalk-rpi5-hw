/******************************************************************************
 * @file        xWalkHardwareSequenceTest.cpp
 * @brief       Verifies multi-device sequences on both supported Robot HAT profiles.
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
#include "xControllerBattery.h"
/** @namespace xwalk::hardware::test
 * @brief Parameterized full-graph regression sequences.
 */
namespace xwalk::hardware::test
{
    using namespace controller;
    /** @brief Movement, camera servos, sensors and diagnostics share one active graph. */
    TEST_P(XWalkHardwareSequence, MultiDeviceLifecycleAndRestart)
    {
        MoveReq premature{};
        premature.has_request = true;
        exchange(XWALK_CNTRL_MOVE_REQ, &premature, sizeof(premature), XWALK_CNTRL_MOVE_REJ);
        expectStopped();
        for (uint32 cycle = 0U; cycle < 3U; ++cycle)
        {
            SCOPED_TRACE(cycle);
            activate();
            move(false);
            for (int axis = 0; axis < 2; ++axis)
            {
                CameraReq camera{};
                camera.has_request = true;
                camera.request.axis = static_cast<decltype(camera.request.axis)>(axis);
                camera.request.angle_degrees = 10.0;
                camera.has_clientAddress = true;
                camera.clientAddress.xwalk_local_index = 41U;
                exchange(XWALK_CNTRL_CAMERA_REQ, &camera, sizeof(camera), XWALK_CNTRL_CAMERA_CFM);
                EXPECT_EQ(capture.clients[responses - 1U], 41U);
            }
            SensorReq sensor{};
            sensor.has_request = true;
            sensor.request.type = static_cast<decltype(sensor.request.type)>(1);
            exchange(XWALK_CNTRL_SENSOR_REQ, &sensor, sizeof(sensor), XWALK_CNTRL_SENSOR_CFM);
            move(true);
            HealthReq health{};
            exchange(XWALK_HEALTH_REQ, &health, sizeof(health), XWALK_HEALTH_CFM);
            const boolean stopped = boot->stop();
            ASSERT_TRUE(stopped);
            expectStopped();
            const boolean restarted = boot->start();
            ASSERT_TRUE(restarted);
        }
        const auto events = boot->modules()->platform->simulation.events();
        ASSERT_FALSE(events.empty());
        hal::uint64 previous = 0U;
        for (const auto& event : events)
        {
            EXPECT_GT(event.sequence, previous);
            previous = event.sequence;
        }
    }
    /** @brief A real ADC failure crosses HAL, Driver and Controller, then the next sensor request recovers. */
    TEST_P(XWalkHardwareSequence, SensorFailureRecoveryAndCorrelation)
    {
        activate();
        move(false);
        SensorReq sensor{};
        sensor.has_request = true;
        sensor.request.type = static_cast<decltype(sensor.request.type)>(1);
        sensor.has_clientAddress = true;
        sensor.clientAddress.xwalk_local_index = 23U;
        boot->modules()->platform->simulation.failNext(hal::simulation::XWalkRobotHatOperation::I2cRead, 0x14U);
        exchange(XWALK_CNTRL_SENSOR_REQ, &sensor, sizeof(sensor), XWALK_CNTRL_SENSOR_REJ);
        EXPECT_EQ(capture.clients[responses - 1U], 23U);
        EXPECT_NE(capture.errors[responses - 1U], 0U);
        expectStopped();
        exchange(XWALK_CNTRL_SENSOR_REQ, &sensor, sizeof(sensor), XWALK_CNTRL_SENSOR_CFM);
        EXPECT_EQ(capture.clients[responses - 1U], 23U);
        expectStopped();
    }
    /** @brief ADC and BoardControl feed the production rolling-minute average without wall-clock waits. */
    TEST_P(XWalkHardwareSequence, BatteryWindowWithSharedSensorBus)
    {
        auto& simulation = boot->modules()->platform->simulation;
        XWalkBatteryWindow window;
        for (uint32 sample = 1U; sample <= 12U; ++sample)
        {
            simulation.setBatteryVoltage(sample <= 6U ? 7.2 : 8.0);
            const float64 voltage = boot->modules()->boardControl->batteryVoltage();
            window.sample(static_cast<float64>(sample * 5U), voltage);
            if (sample == 1U)
            {
                // The first sample already gives a value.
                EXPECT_NEAR(window.average, 7.2, 0.02);
            }
        }
        EXPECT_EQ(window.samples, 12U);
        EXPECT_NEAR(window.average, 7.6, 0.02);
        simulation.setBatteryVoltage(8.2);
        const float64 voltage = boot->modules()->boardControl->batteryVoltage();
        window.sample(65.0, voltage);
        // The minute rolls on: the oldest 7.2 V sample is replaced by the new 8.2 V one.
        EXPECT_NEAR(window.average, 7.68, 0.02);
        SensorReq sensor{};
        sensor.has_request = true;
        sensor.request.type = static_cast<decltype(sensor.request.type)>(1);
        exchange(XWALK_CNTRL_SENSOR_REQ, &sensor, sizeof(sensor), XWALK_CNTRL_SENSOR_CFM);
        expectStopped();
    }
    /** @brief Host speech and camera servo work remain usable after movement and repeated lifecycle stops. */
    TEST_P(XWalkHardwareSequence, AnnouncementAndShutdownSequence)
    {
        activate();
        move(false);
        SoundReq announcement{};
        announcement.has_request = true;
        announcement.request.has_operation = true;
        announcement.request.operation = iw::v1::plain::XWALK_SOUND_OPERATION_ANNOUNCE;
        announcement.request.announcement_id = {"hw-sequence", 11U};
        announcement.request.announcement_title = {"Test", 4U};
        announcement.request.announcement_body = {"Host sequence", 13U};
        exchange(XWALK_CNTRL_SOUND_REQ, &announcement, sizeof(announcement), XWALK_CNTRL_SOUND_CFM);
        const boolean stopped = boot->stop();
        ASSERT_TRUE(stopped);
        const boolean stoppedAgain = boot->stop();
        EXPECT_TRUE(stoppedAgain);
        expectStopped();
        const boolean restarted = boot->start();
        ASSERT_TRUE(restarted);
        HealthReq health{};
        exchange(XWALK_HEALTH_REQ, &health, sizeof(health), XWALK_HEALTH_CFM);
    }
    /** @brief Camera failure and recovery do not corrupt the shared motor and sensor graph. */
    TEST_P(XWalkHardwareSequence, CameraFailureRecoveryBetweenMovements)
    {
        activate();
        move(false);
        auto& simulation = boot->modules()->platform->simulation;
        simulation.setCameraAvailable(false);
        const string missing = agent::XWalkCameraCapture::captureImage(boot->modules()->cameraCapture);
        EXPECT_TRUE(missing.empty());
        expectStopped();
        simulation.setCameraAvailable(true);
        const string captured = agent::XWalkCameraCapture::captureImage(boot->modules()->cameraCapture);
        EXPECT_FALSE(captured.empty());
        move(true);
    }
    INSTANTIATE_TEST_SUITE_P(RobotHatProfiles,
                             XWalkHardwareSequence,
                             ::testing::Values("robot_hat_v4", "robot_hat_v5"));
} /* namespace xwalk::hardware::test */
