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
let composedDependencies: [Target.Dependency] =
  ["ComposedHost", "StoreFeature", "NewsFeature"] + routerDependencies

let package = Package(
  name: "elementary-router-compile-checks",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "https://github.com/elementary-swift/elementary-ui", .upToNextMinor(from: "0.9.0")),
    .package(path: "../.."),
  ],
  targets: [
    .target(name: "RouteFixtures", dependencies: routerDependencies),
    // Mounted features and their host, each in its own module, as downstream apps compose them.
    .target(name: "NewsFeature", dependencies: routerDependencies),
    .target(name: "StoreFeature", dependencies: ["NewsFeature"] + routerDependencies),
    .target(name: "ComposedHost", dependencies: ["StoreFeature", "NewsFeature"] + routerDependencies),
    .target(name: "ValidUsage", dependencies: ["RouteFixtures"] + composedDependencies),
    .target(name: "RejectsForeignRouteGroupLink", dependencies: ["RouteFixtures"] + routerDependencies),
    .target(
      name: "RejectsForeignRouteGroupNavigation",
      dependencies: ["RouteFixtures"] + routerDependencies
    ),
    .target(name: "RejectsWrongArgumentType", dependencies: ["RouteFixtures"] + routerDependencies),
    .target(name: "RejectsWrongQueryType", dependencies: ["RouteFixtures"] + routerDependencies),
    .target(name: "RejectsMissingArgument", dependencies: ["RouteFixtures"] + routerDependencies),
    .target(name: "RejectsMissingLayoutQuery", dependencies: ["RouteFixtures"] + routerDependencies),
    .target(name: "RejectsLayoutQueryWildcardCollision", dependencies: routerDependencies),
    .target(
      name: "RejectsMountedDestinationWithStandaloneRouter",
      dependencies: ["RouteFixtures"] + composedDependencies
    ),
    .target(name: "RejectsMountedDestinationOfAnotherHost", dependencies: composedDependencies),
    .target(name: "RejectsHostDestinationInFeatureView", dependencies: composedDependencies),
    .target(name: "RejectsFeatureRouteSetOfAnotherHost", dependencies: composedDependencies),
    .target(name: "RejectsMountWithForeignRoot", dependencies: composedDependencies),
    .target(name: "RejectsRouteInsideMount", dependencies: composedDependencies),
  ],
  swiftLanguageModes: [.v6]
)
