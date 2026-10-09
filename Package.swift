// swift-tools-version: 6.0

import Foundation
import PackageDescription

/// Embedded in the binary so `asc --version` and the publish script read the same version.
let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("src/asc/Resources/Info.plist").path

let package = Package(
    name: "asc",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "asc",
            path: "src/asc",
            exclude: ["Resources"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker",
                    "-sectcreate",
                    "-Xlinker",
                    "__TEXT",
                    "-Xlinker",
                    "__info_plist",
                    "-Xlinker",
                    infoPlist,
                ]),
            ]
        ),
        .testTarget(
            name: "ascTests",
            dependencies: ["asc"],
            path: "src/ascTests"
        ),
    ]
)
