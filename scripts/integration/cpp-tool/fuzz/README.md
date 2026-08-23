# xWalk fuzzing

The nine Clang/libFuzzer targets exercise the production JSON-C, generated Protobuf, bounded HTTP, camera-source and OpenCV decode entry points. Every harness rejects oversized input before parsing. JSON depth is limited to 32, Protobuf and gRPC inputs to 64 KiB, HTTP headers to 8 KiB, I2C payloads to 4 KiB, and encoded images to 256 KiB with an OpenCV decoded-pixel limit of 1920 by 1080.

Configure and build with:

```bash
CC=clang CXX=clang++ cmake -S xWalk-rpi5-hw -B build-host/fuzz -G Ninja -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=OFF -DXWALK_BUILD_FUZZERS=ON
```

Run a short smoke pass for one target with:

```bash
build-host/fuzz/scripts/integration/cpp-tool/fuzz/xWalkFuzz_http_requests -runs=1000 scripts/integration/cpp-tool/fuzz/corpus/http_requests
```

For a longer local run, replace `-runs=1000` with `-max_total_time=3600`. Corpus inputs are data only and must never be executed. A fuzzer crash, timeout, sanitizer finding or out-of-memory result is a failure; a target that was only compiled must not be reported as passed.
