// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Stow",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "Stow", targets: ["Stow"])],
    targets: [
        .target(name: "ExamModeBridge", path: "Sources/ExamModeBridge", publicHeadersPath: "include"),
        .target(
            name: "StowKit",
            dependencies: ["ExamModeBridge"],
            path: "Sources/StowKit",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(name: "Stow", dependencies: ["StowKit"], path: "Sources/Stow"),
        .testTarget(name: "StowKitTests", dependencies: ["StowKit", "ExamModeBridge"], path: "Tests/StowKitTests"),
    ]
)
