// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flycut",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FlycutCore", targets: ["FlycutCore"]),
        .library(name: "FlycutPlatform", targets: ["FlycutPlatform"]),
        .executable(name: "FlycutMac", targets: ["FlycutMac"]),
    ],
    targets: [
        .target(name: "FlycutCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .target(
            name: "FlycutPlatform",
            dependencies: ["FlycutCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(name: "FlycutMac", dependencies: ["FlycutCore", "FlycutPlatform"]),
        .testTarget(name: "FlycutCoreTests", dependencies: ["FlycutCore"], resources: [.copy("Fixtures")]),
        .testTarget(name: "FlycutPlatformTests", dependencies: ["FlycutPlatform", "FlycutCore"]),
    ],
    swiftLanguageModes: [.v6]
)
