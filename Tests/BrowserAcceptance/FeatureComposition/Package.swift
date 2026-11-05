// swift-tools-version:6.3
import PackageDescription

// Browser acceptance fixture for mounted features. See README.md.
//
// The hosts mount the `Shop` and `Blog` feature modules of Examples/FeatureComposition, so the
// same feature modules are checked under a path-mode host and a hash-mode host.
let guideDependencies: [Target.Dependency] = [
  .product(name: "ElementaryUI", package: "elementary-ui"),
  .product(name: "ElementaryRouter", package: "elementary-router"),
]

let package = Package(
  name: "elementary-router-feature-composition-acceptance",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/elementary-swift/elementary-ui", .upToNextMinor(from: "0.9.0")),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.50.0"),
    .package(path: "../../.."),
    .package(path: "../../../Examples/FeatureModules"),
  ],
  targets: [
    // Two features that share the name `Routes` with each other and with the path-mode host.
    .target(name: "GuideAlpha", dependencies: guideDependencies),
    .target(name: "GuideBeta", dependencies: guideDependencies),
    .executableTarget(
      name: "CompositionAcceptance",
      dependencies: [
        "GuideAlpha",
        "GuideBeta",
        .product(name: "ElementaryUI", package: "elementary-ui"),
        .product(name: "ElementaryRouter", package: "elementary-router"),
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "Shop", package: "FeatureModules"),
        .product(name: "Blog", package: "FeatureModules"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ],
    ),
  ],
  swiftLanguageModes: [.v6]
)
