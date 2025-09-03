// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CubeTimer",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "CubeTimer",
            targets: ["CubeTimer"]
        )
    ],
    targets: [
        .target(
            name: "CubeTimer",
            path: "CubeTimer",
            exclude: ["CubeTimerApp.swift"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "CubeTimerTests",
            dependencies: ["CubeTimer"],
            path: "CubeTimerTests"
        ),
        .testTarget(
            name: "CubeTimerUITests",
            dependencies: ["CubeTimer"],
            path: "CubeTimerUITests"
        )
    ]
)
