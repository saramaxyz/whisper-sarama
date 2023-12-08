// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "whisper",
    platforms: [
      .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "whisper",
            targets: ["whisper"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
          name: "whisper-coreml",
          path: "Sources/whisper/coreml/",
          sources: [
            "whisper-decoder-impl.m",
            "whisper-encoder-impl.m",
            "whisper-encoder.mm"
          ],
          publicHeadersPath: "."
        ),
        .target(
            name: "whisper",
            dependencies: [
              .target(name: "whisper-coreml")
            ],
            sources: [
                "ggml.c",
                "whisper.cpp",
                "ggml-alloc.c",
                "ggml-backend.c",
                "ggml-quants.c",
                "ggml-metal.m",
                "stream.cpp"
            ],
            publicHeadersPath: "spm-headers",
            cSettings: [
              .unsafeFlags(["-Wno-shorten-64-to-32", "-O3", "-DNDEBUG"]),
              .unsafeFlags(["-fno-objc-arc"]),
              .define("GGML_USE_ACCELERATE"),
              .define("GGML_USE_METAL"),
              .define("WHISPER_USE_COREML")
            ],
            linkerSettings: [
                .linkedFramework("Accelerate")
            ]
        ),
        .testTarget(
            name: "whisperTests",
            dependencies: ["whisper"]),
    ],
    cxxLanguageStandard: .cxx11
)
