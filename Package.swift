// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "elementary-ui-router",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "ElementaryUIRouter", targets: ["ElementaryUIRouter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/elementary-swift/elementary-ui", from: "0.2.2"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", .upToNextMinor(from: "0.50.0")),
    ],
    targets: [
        .target(
            name: "ElementaryUIRouter",
            dependencies: [
                .product(name: "ElementaryUI", package: "elementary-ui"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ]
        ),
        .testTarget(
            name: "ElementaryUIRouterTests",
            dependencies: ["ElementaryUIRouter"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
