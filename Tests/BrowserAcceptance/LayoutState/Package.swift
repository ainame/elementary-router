// swift-tools-version:6.3
import PackageDescription

// Browser acceptance fixture for layout state across navigation. See README.md.
let package = Package(
  name: "elementary-router-layout-state-acceptance",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/elementary-swift/elementary-ui", .upToNextMinor(from: "0.9.0")),
    .package(path: "../../.."),
  ],
  targets: [
    .executableTarget(
      name: "WebApp",
      dependencies: [
        .product(name: "ElementaryUI", package: "elementary-ui"),
        .product(name: "ElementaryRouter", package: "elementary-router"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ],
    )
  ],
  swiftLanguageModes: [.v6]
)
