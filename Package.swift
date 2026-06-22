// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "LLMeter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LLMeterCore", targets: ["LLMeterCore"]),
        .executable(name: "llmeter-probe", targets: ["llmeter-probe"]),
    ],
    targets: [
        .target(name: "LLMeterCore"),
        .executableTarget(name: "llmeter-probe", dependencies: ["LLMeterCore"]),
        .testTarget(
            name: "LLMeterCoreTests",
            dependencies: ["LLMeterCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
