// swift-tools-version:6.3
import PackageDescription

let package = Package(
  name: "elementary-router-example",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(url: "https://github.com/elementary-swift/elementary-ui", from: "0.2.2"),
    .package(path: "../.."),
  ],
  targets: [
    .executableTarget(
      name: "WebApp",
      dependencies: [
        .product(name: "ElementaryUI", package: "elementary-ui"),
        .product(name: "ElementaryUIRouter", package: "elementary-ui-router"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ],
    )
  ],
  swiftLanguageModes: [.v6]
)
