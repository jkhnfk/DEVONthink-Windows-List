// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DEVONthinkWindowsList",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "DEVONthinkWindowsListCore",
            path: "Sources/DEVONthinkWindowsListCore"
        ),
        .executableTarget(
            name: "DEVONthinkWindowsList",
            dependencies: ["DEVONthinkWindowsListCore"],
            path: "Sources/DEVONthinkWindowsList"
        ),
        .testTarget(
            name: "DEVONthinkWindowsListTests",
            dependencies: ["DEVONthinkWindowsListCore"],
            path: "Tests/DEVONthinkWindowsListTests"
        )
    ]
)
