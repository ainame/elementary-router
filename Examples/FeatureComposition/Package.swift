// swift-tools-version:6.3
import PackageDescription

// `Shop` and `Blog` are feature modules: each declares a generic `@Routes` struct and knows
// nothing about the app that mounts it. `WebApp` is the host: it imports both features with
// ordinary imports, mounts them into one route tree, and owns the router and fallbacks.
let routerDependencies: [Target.Dependency] = [
  .product(name: "ElementaryUI", package: "elementary-ui"),
  .product(name: "ElementaryRouter", package: "elementary-router"),
]

let package = Package(
  name: "elementary-router-feature-composition",
  platforms: [.macOS(.v26)],
  products: [
    .library(name: "Shop", targets: ["Shop"]),
    .library(name: "Blog", targets: ["Blog"]),
  ],
  dependencies: [
    .package(url: "https://github.com/elementary-swift/elementary-ui", .upToNextMinor(from: "0.9.0")),
    .package(path: "../.."),
  ],
  targets: [
    .target(name: "Blog", dependencies: routerDependencies),
    // The shop links to blog reviews, so it imports the blog feature.
    .target(name: "Shop", dependencies: ["Blog"] + routerDependencies),
    .executableTarget(
      name: "WebApp",
      dependencies: ["Shop", "Blog"] + routerDependencies,
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ],
    ),
  ],
  swiftLanguageModes: [.v6]
)
