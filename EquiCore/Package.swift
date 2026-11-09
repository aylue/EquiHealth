// swift-tools-version: 6.2
// ANNAHME: SPEC nennt Swift 6.4 / Xcode 27. Installiert ist Xcode 26.1.1 mit Swift 6.2.1,
// daher Tools-Version 6.2 und Plattform v26. Siehe OPEN_QUESTIONS.md (Q-001).
import PackageDescription

let package = Package(
  name: "EquiCore",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "EquiCore", targets: ["EquiCore"])
  ],
  targets: [
    .target(name: "EquiCore"),
    .testTarget(name: "EquiCoreTests", dependencies: ["EquiCore"]),
  ],
  swiftLanguageModes: [.v6]
)
