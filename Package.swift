// swift-tools-version: 6.0
import PackageDescription

// Flux is built and packaged as a real `.app` via Xcode (MenuBarExtra needs an
// app bundle + LSUIElement). This SPM manifest exists so the collectors, models,
// store, and engine can be built and iterated on from the command line
// (`swift build`) without opening Xcode. See README.md for the Xcode path.
let package = Package(
    name: "Flux",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Flux",
            path: "Sources/Flux",
            resources: [
                .process("Resources")
            ]
        )
    ],
    // Stay in Swift 5 language mode for now to keep the early scaffold simple;
    // tighten to full Swift 6 strict concurrency once the data flow settles.
    swiftLanguageModes: [.v5]
)
