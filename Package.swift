// swift-tools-version: 6.3
import CompilerPluginSupport
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
    .testTarget(
      name: "ElementaryRouterTests",
      dependencies: [
        "ElementaryRouter",
        "ElementaryRouterMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
