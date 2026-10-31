// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AulaControl",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AulaKit", targets: ["AulaKit"]),
        .executable(name: "AulaControl", targets: ["AulaControl"]),
        .executable(name: "aula", targets: ["aula"]),
    ],
    targets: [
        .target(
            name: "AulaKit",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(name: "AulaControl", dependencies: ["AulaKit"]),
        .executableTarget(name: "aula", dependencies: ["AulaKit"]),
        .testTarget(name: "AulaKitTests", dependencies: ["AulaKit"]),
    ]
)
