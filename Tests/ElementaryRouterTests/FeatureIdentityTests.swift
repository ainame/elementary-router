import ElementaryUI
import SameNameFeatureAlpha
import SameNameFeatureBeta
import Testing

@testable import ElementaryRouter

// Mounted features are identified by their specialized route set types, never by their names.
// This file imports two modules that both declare a feature named `Routes`, so `@Routes` is
// module-qualified here.

/// A host that mounts two unrelated features that share the name `Routes`.
@ElementaryRouter.Routes
struct SameNameHost {
  @Mount("/alpha")
  typealias Alpha = SameNameFeatureAlpha.Routes<RouteView>

  @Mount("/beta")
  typealias Beta = SameNameFeatureBeta.Routes<RouteView>
}

/// A generic alias of a feature, as a host or a shared module might declare one.
typealias AliasedTestShopRoutes<Root: View> = TestShopRoutes<Root>

/// Mounts one feature twice, the second time with a module-qualified spelling.
@ElementaryRouter.Routes
struct QualifiedDuplicateRoutes {
  @Mount("/shop")
  typealias Shop = TestShopRoutes<RouteView>

  @Mount("/store")
  typealias Store = ElementaryRouterTests.TestShopRoutes<RouteView>
}

/// Mounts one feature twice, the second time through a generic alias.
@ElementaryRouter.Routes
struct AliasedDuplicateRoutes {
  @Mount("/blog")
  typealias Blog = TestBlogRoutes<RouteView>

  @Mount("/shop")
  typealias Shop = TestShopRoutes<RouteView>

  @Mount("/market")
  typealias Market = AliasedTestShopRoutes<RouteView>
}

@Test func sameNamedFeaturesOfSeparateModulesMountSideBySide() throws {
  let routes = try SameNameHost.routes()
  let router = Router(routes: routes.tree, history: BrowserHistory(history: MemoryHistory()))

  // Each feature route set builds destinations of its own routes, under its own mount.
  #expect(routes.alpha.index().location.href == "/alpha")
  #expect(routes.beta.index().location.href == "/beta")
  #expect(try routes.alpha.entry(id: 3).location.href == "/alpha/entries/3")
  #expect(try routes.beta.note(slug: "hello").location.href == "/beta/notes/hello")

  try router.navigate(to: routes.beta.note(slug: "hello"))
  #expect(router.matchedRoutes == [routes.handles.beta, routes.beta.handles.note])
  try router.navigate(to: routes.alpha.entry(id: 3))
  #expect(router.matchedRoutes == [routes.handles.alpha, routes.alpha.handles.entry])

  // The environment keys of the two route sets are their types, which differ although both
  // features are named `Routes`.
  #expect(
    SameNameFeatureAlpha.Routes<SameNameHost.RouteView>.RouteSet._environmentIdentity
      != SameNameFeatureBeta.Routes<SameNameHost.RouteView>.RouteSet._environmentIdentity
  )
}

@Test func environmentIdentitiesSeparateHostsAndFeatures() {
  // One feature mounted by two hosts has one environment key per host.
  #expect(
    TestShopRoutes<ComposedRoutes.RouteView>.RouteSet._environmentIdentity
      != TestShopRoutes<HashComposedRoutes.RouteView>.RouteSet._environmentIdentity
  )
  // Each host's navigator has its own key, so a nested host never reads an outer host's router.
  #expect(
    RouteNavigator<ComposedRoutes.RouteView>._environmentIdentity
      != RouteNavigator<HashComposedRoutes.RouteView>._environmentIdentity
  )
  #expect(
    RouteNavigator<SameNameHost.RouteView>._environmentIdentity
      != SameNameFeatureAlpha.Routes<SameNameHost.RouteView>.RouteSet._environmentIdentity
  )
  // The identity is stable for one type.
  #expect(
    TestShopRoutes<ComposedRoutes.RouteView>.RouteSet._environmentIdentity
      == TestShopRoutes<ComposedRoutes.RouteView>.RouteSet._environmentIdentity
  )
}

@Test func oneFeatureMountedTwiceIsRejectedHoweverItIsSpelled() {
  #expect(throws: RouteTreeError.duplicateFeature(path: "/store", conflictingPath: "/shop")) {
    _ = try QualifiedDuplicateRoutes.routes()
  }
  #expect(throws: RouteTreeError.duplicateFeature(path: "/market", conflictingPath: "/shop")) {
    _ = try AliasedDuplicateRoutes.routes()
  }
}

@Test func distinctFeatureCheckComparesIdentitiesInMountOrder() {
  let shop = TestShopRoutes<EmptyHTML>.RouteSet._environmentIdentity
  let blog = TestBlogRoutes<EmptyHTML>.RouteSet._environmentIdentity

  #expect(throws: Never.self) {
    try RouteBuilder<EmptyHTML>._checkDistinctFeatures([
      (identity: shop, path: "/shop"), (identity: blog, path: "/blog"),
    ])
  }
  #expect(throws: RouteTreeError.duplicateFeature(path: "/c", conflictingPath: "/a")) {
    try RouteBuilder<EmptyHTML>._checkDistinctFeatures([
      (identity: shop, path: "/a"), (identity: blog, path: "/b"), (identity: shop, path: "/c"),
    ])
  }
}
