// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "any-error-swift",
    products: [
        .library(name: "AnyError", targets: ["AnyError"]),
    ],
    traits: [
        .default(enabledTraits: [
            "FullFoundation",
        ]),
        .trait(name: "FullFoundation", description: "Enables full Foundation imports on non-Apple platforms"),
        .trait(name: "Embedded", description: "Builds for Embedded Swift (no Foundation, no reflection)"),
    ],
    targets: [
        // Note: the Embedded trait only builds on Linux with this manifest. There is no `platforms:`
        // floor, so on a macOS host the target defaults to macOS 10.13 and the Embedded standard
        // library (which requires macOS 14) fails to load. Build Embedded with `swift build
        // --disable-default-traits --traits Embedded` on Linux; see the `linux embedded` CI job.
        .target(
            name: "AnyError",
            swiftSettings: [
                .enableExperimentalFeature("Embedded", .when(traits: ["Embedded"])),
            ],
        ),
        .testTarget(
            name: "AnyErrorTests",
            dependencies: ["AnyError"],
        ),
    ],
)
