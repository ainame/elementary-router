// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "elementary-router",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "ElementaryRouter", targets: ["ElementaryRouter"])
  ],
  dependencies: [
    .package(url: "https://github.com/elementary-swift/elementary-ui", from: "0.2.2"),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", .upToNextMinor(from: "0.50.0")),
  ],
  targets: [
    .target(
      name: "ElementaryRouter",
      dependencies: [
        .product(name: "ElementaryUI", package: "elementary-ui"),
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
      ]
    ),
    .testTarget(
      name: "ElementaryRouterTests",
      dependencies: ["ElementaryRouter"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
