// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Structure",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Structure", targets: ["Structure"])
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .executableTarget(
            name: "Structure",
            dependencies: ["CSQLite"]
        )
    ]
)
