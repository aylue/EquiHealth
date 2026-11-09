// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "EquiCore",
  platforms: [.iOS(.v27), .macOS(.v27)],
  products: [
    .library(name: "EquiCore", targets: ["EquiCore"])
  ],
  targets: [
    .target(name: "EquiCore"),
    .testTarget(name: "EquiCoreTests", dependencies: ["EquiCore"]),
  ],
  swiftLanguageModes: [.v6]
)
