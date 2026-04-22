// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceFlow",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VoiceFlow", targets: ["VoiceFlow"])
    ],
    dependencies: [
        // No heavy MLX dependencies in main app for faster startup and small size
    ],
    targets: [
        .executableTarget(
            name: "VoiceFlow",
            dependencies: [],
            path: "Sources/VoiceFlow",
            exclude: ["System/Info.plist"],
            resources: [
                .process("UI/Shaders.metal")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/VoiceFlow/System/Info.plist",
                ])
            ]
        )
    ]
)
