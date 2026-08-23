/******************************************************************************
 * @file        xWalk_Rpi5CarFuzzHarness.cpp
 * @brief       Exercises bounded production parsers through libFuzzer.
 * @project     xWalk Firmware
 * @module      xWalkFuzz
 * @copyright   Copyright (c) 2026 Joxy John. All rights reserved.
 ******************************************************************************/

#include "xAgent_Rpi5CarMjpegHttpServer.h"
#include "xHal_Rpi5CarCamera.h"
#include "xHal_Rpi5CarXIwMessageReq.pb.h"

#include <json-c/json.h>
#include <opencv2/imgcodecs.hpp>

#include <cstddef>
#include <cstdint>
#include <cstdlib>

namespace
{
    [[maybe_unused]] constexpr std::size_t MAXIMUM_INPUT_BYTES{1U * 1'024U * 1'024U};
    [[maybe_unused]] constexpr std::size_t MAXIMUM_PROTOBUF_BYTES{64U * 1'024U};
    [[maybe_unused]] constexpr std::size_t MAXIMUM_JSON_BYTES{64U * 1'024U};
    [[maybe_unused]] constexpr std::size_t MAXIMUM_SCENARIO_EVENTS{1'024U};
    [[maybe_unused]] constexpr std::size_t MAXIMUM_I2C_PAYLOAD_BYTES{4U * 1'024U};

    [[maybe_unused]] void
    parseBoundedJson(const std::uint8_t* data, std::size_t size, const char* boundedArrayName) noexcept
    {
        if (size > MAXIMUM_JSON_BYTES)
        {
            return;
        }
        json_tokener* tokener = json_tokener_new_ex(32);
        if (tokener == nullptr)
        {
            return;
        }
        json_tokener_set_flags(tokener, JSON_TOKENER_STRICT);
        json_object* object =
            json_tokener_parse_ex(tokener, reinterpret_cast<const char*>(data), static_cast<int>(size));
        if ((object != nullptr) && (boundedArrayName != nullptr))
        {
            json_object* array{};
            if (json_object_object_get_ex(object, boundedArrayName, &array) &&
                json_object_is_type(array, json_type_array))
            {
                const std::size_t count = json_object_array_length(array);
                if (count > MAXIMUM_SCENARIO_EVENTS)
                {
                    static_cast<void>(count);
                }
            }
        }
        if (object != nullptr)
        {
            json_object_put(object);
        }
        json_tokener_free(tokener);
    }
} /* namespace */

extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size)
{
    if ((data == nullptr) || (size > MAXIMUM_INPUT_BYTES))
    {
        return 0;
    }
#if XWALK_FUZZ_KIND == 1
    parseBoundedJson(data, size, nullptr);
#elif XWALK_FUZZ_KIND == 2
    if (size <= MAXIMUM_PROTOBUF_BYTES)
    {
        xwalk::iw::v1::XWalkI2cRequestPayload request;
        static_cast<void>(request.ParseFromArray(data, static_cast<int>(size)));
    }
#elif XWALK_FUZZ_KIND == 3
    if (size <= MAXIMUM_PROTOBUF_BYTES)
    {
        xwalk::iw::v1::XWalkMoveCommandRequest request;
        static_cast<void>(request.ParseFromArray(data, static_cast<int>(size)));
    }
#elif XWALK_FUZZ_KIND == 4
    xwalk::agent::XWalkMjpegHttpRequest request;
    static_cast<void>(xwalk::agent::parseMjpegHttpRequest(
        xwalk::agent::stringview(reinterpret_cast<const char*>(data), size), 8U * 1'024U, request));
#elif XWALK_FUZZ_KIND == 5
    static_cast<void>(
        xwalk::hal::validCameraSourceString(xwalk::hal::stringview(reinterpret_cast<const char*>(data), size)));
#elif XWALK_FUZZ_KIND == 6
    parseBoundedJson(data, size, "classes");
#elif XWALK_FUZZ_KIND == 7
    parseBoundedJson(data, size, "events");
#elif XWALK_FUZZ_KIND == 8
    if (size <= MAXIMUM_I2C_PAYLOAD_BYTES)
    {
        xwalk::iw::v1::XWalkI2cRequestPayload request;
        static_cast<void>(request.ParseFromArray(data, static_cast<int>(size)));
    }
#elif XWALK_FUZZ_KIND == 9
    if ((size > 0U) && (size <= 256U * 1'024U))
    {
        static const int environmentConfigured = ::setenv("OPENCV_IO_MAX_IMAGE_PIXELS", "2073600", 0);
        static_cast<void>(environmentConfigured);
        const cv::Mat encoded(1, static_cast<int>(size), CV_8UC1, const_cast<std::uint8_t*>(data));
        const cv::Mat decoded = cv::imdecode(encoded, cv::IMREAD_UNCHANGED);
        if (!decoded.empty() && ((decoded.cols > 1'920) || (decoded.rows > 1'080)))
        {
            return 0;
        }
    }
#endif
    return 0;
}
