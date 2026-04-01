// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ClipPin",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipPin", targets: ["ClipPin"])
    ],
    targets: [
        .executableTarget(
            name: "ClipPin",
            path: "Sources/ClipPin",
            swiftSettings: [
                .unsafeFlags(["-Osize"], .when(configuration: .release))
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-dead_strip", "-Xlinker", "-x"], .when(configuration: .release))
            ]
        )
    ]
)
