// swift-tools-version:5.9
import PackageDescription

// NovaCore: everything in the iPhone app that does not need a screen or Bluetooth (protocol, widget compiler, CRC,
// image packing, themes). It builds and is tested on Linux and macOS: `swift run NovaChecks <repo root>`.
let package = Package(
    name: "NovaCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "NovaCore", targets: ["NovaCore"])],
    targets: [
        .target(name: "NovaCore"),
        .executableTarget(name: "NovaChecks", dependencies: ["NovaCore"]),
    ]
)
