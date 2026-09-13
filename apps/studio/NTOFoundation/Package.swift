// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "NTOFoundation", platforms: [.macOS("26.0")], products: [.library(name: "NTOFoundation", targets: ["NTOFoundation"])], targets: [.target(name: "NTOFoundation"), .testTarget(name: "NTOFoundationTests", dependencies: ["NTOFoundation"], resources: [.copy("Fixtures")])])
