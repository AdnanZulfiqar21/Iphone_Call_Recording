// swift-tools-version: 6.0
import PackageDescription

// CallCaptureCore: platform-light domain logic (Foundation only) so it can be
// tested on any host, including Linux CI. CallCaptureMedia: Apple media
// frameworks (AVFoundation, ReplayKit); its sources compile to an empty module
// where those frameworks are unavailable.
let package = Package(
    name: "CallCaptureCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CallCaptureCore", targets: ["CallCaptureCore"]),
        .library(name: "CallCaptureMedia", targets: ["CallCaptureMedia"]),
    ],
    targets: [
        .target(
            name: "CallCaptureCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "CallCaptureMedia",
            dependencies: ["CallCaptureCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CallCaptureCoreTests",
            dependencies: ["CallCaptureCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CallCaptureMediaTests",
            dependencies: ["CallCaptureMedia", "CallCaptureCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
