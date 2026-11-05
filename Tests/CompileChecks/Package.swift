// swift-tools-version:6.3
import PackageDescription

// Downstream compile checks for the typed destination API.
//
// `ValidUsage` must build. Every `Rejects*` target must fail to build with the diagnostic named
// by the `// expected-error:` line of its source file. Run `Scripts/check-compile-failures.sh`.
let routerDependencies: [Target.Dependency] = [
  .product(name: "ElementaryUI", package: "elementary-ui"),
  .product(name: "ElementaryRouter", package: "elementary-router"),
]

let package = Package(
  name: "elementary-router-compile-checks",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/elementary-swift/elementary-ui", .upToNextMinor(from: "0.9.0")),
    .package(path: "../.."),
  ],
  targets: [
    .target(name: "RouteFixtures", dependencies: routerDependencies),
    .target(name: "ValidUsage", dependencies: ["RouteFixtures"] + routerDependencies),
    .target(name: "RejectsForeignRouteGroupLink", dependencies: ["RouteFixtures"] + routerDependencies),
    .target(
      name: "RejectsForeignRouteGroupNavigation",
      dependencies: ["RouteFixtures"] + routerDependencies
    ),
    .target(name: "RejectsWrongArgumentType", dependencies: ["RouteFixtures"] + routerDependencies),
    .target(name: "RejectsWrongQueryType", dependencies: ["RouteFixtures"] + routerDependencies),
    .target(name: "RejectsMissingArgument", dependencies: ["RouteFixtures"] + routerDependencies),
  ],
  swiftLanguageModes: [.v6]
)
