// swift-tools-version: 6.3
import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "elementary-router",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(name: "ElementaryRouter", targets: ["ElementaryRouter"])
  ],
  dependencies: [
    .package(url: "https://github.com/elementary-swift/elementary-ui", .upToNextMinor(from: "0.9.0")),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.50.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "603.0.0"),
  ],
  targets: [
    .target(
      name: "ElementaryRouter",
      dependencies: [
        "ElementaryRouterMacros",
        .product(name: "ElementaryUI", package: "elementary-ui"),
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
      ]
    ),
    .macro(
      name: "ElementaryRouterMacros",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      ]
    ),
    // Two test-only feature modules that both declare a feature named `Routes`, so tests can
    // mount same-named features from separate modules into one host.
    .target(
      name: "SameNameFeatureAlpha",
      dependencies: [
        "ElementaryRouter",
        .product(name: "ElementaryUI", package: "elementary-ui"),
      ],
      path: "Tests/Fixtures/SameNameFeatureAlpha"
    ),
    .target(
      name: "SameNameFeatureBeta",
      dependencies: [
        "ElementaryRouter",
        .product(name: "ElementaryUI", package: "elementary-ui"),
      ],
      path: "Tests/Fixtures/SameNameFeatureBeta"
    ),
    .testTarget(
      name: "ElementaryRouterTests",
      dependencies: [
        "ElementaryRouter",
        "ElementaryRouterMacros",
        "SameNameFeatureAlpha",
        "SameNameFeatureBeta",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
