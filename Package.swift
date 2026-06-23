// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "LLMeter",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LLMeterCore", targets: ["LLMeterCore"]),
        .executable(name: "llmeter-probe", targets: ["llmeter-probe"]),
        .executable(name: "llmeter-login", targets: ["llmeter-login"]),
        .executable(name: "LLMeter", targets: ["LLMeter"]),
    ],
    targets: [
        .target(name: "LLMeterCore"),
        .executableTarget(name: "llmeter-probe", dependencies: ["LLMeterCore"]),
        .executableTarget(name: "llmeter-login", dependencies: ["LLMeterCore"]),
        .executableTarget(name: "LLMeter", dependencies: ["LLMeterCore"],
                          resources: [.process("Resources")]),
        .testTarget(
            name: "LLMeterCoreTests",
            dependencies: ["LLMeterCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
