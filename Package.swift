// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ParquetViewer",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "ParquetViewer",
            type: .dynamic,
            targets: ["ParquetViewer"]),
    ],
    dependencies: [
        // No external dependencies required
    ],
    targets: [
        .target(
            name: "ParquetViewer",
            dependencies: [],
            path: "Sources/ParquetViewer",
            linkerSettings: [
                .linkedLibrary("parquet_viewer"),
                .linkedFramework("Foundation"),
                .unsafeFlags(["-L", "/Users/hengfeiyang/code/rust/github.com/hengfeiyang/parquet-viewer/target/aarch64-apple-darwin/release"])
            ]
        ),
        .testTarget(
            name: "ParquetViewerTests",
            dependencies: ["ParquetViewer"],
            path: "Tests/ParquetViewerTests"
        ),
    ]
)
