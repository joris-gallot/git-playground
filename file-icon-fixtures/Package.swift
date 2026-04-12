// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Fixture",
  products: [
    .library(name: "Fixture", targets: ["Fixture"]),
  ],
  targets: [
    .target(name: "Fixture"),
  ]
)
