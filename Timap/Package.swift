// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Timap",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Timap", targets: ["Timap"]),
        .executable(name: "TimapVerify", targets: ["TimapVerify"]),
        .executable(name: "TimapShot", targets: ["TimapShot"]),
        .library(name: "TimapCore", targets: ["TimapCore"])
    ],
    targets: [
        .target(
            name: "TimapCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Timap",
            dependencies: ["TimapCore"]
        ),
        .executableTarget(
            name: "TimapVerify",
            dependencies: ["TimapCore"]
        ),
        .executableTarget(
            name: "TimapShot"
        )
    ]
)
