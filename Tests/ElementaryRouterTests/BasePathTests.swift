import ElementaryUI
import Testing

@testable import ElementaryRouter

// A path-mode app served under a sub-path, such as GitHub Pages' `/<repository>/`, declares the
// sub-path once with `@Routes(basePath:)`. Routes stay declared from `/`.

/// A host served under `/SpeedMath` that also mounts a feature.
@Routes(basePath: "/SpeedMath")
struct BasePathRoutes {
  @Route("/")
  static func home() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/users/:id")
  static func user(id: Int, tab: Query<String> = Query("overview")) -> EmptyHTML {
    EmptyHTML()
  }

  @Mount("/shop")
  typealias Shop = TestShopRoutes<RouteView>

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> EmptyHTML {
    EmptyHTML()
  }
}

/// The same base path spelled without a leading slash and with a trailing one.
@Routes(basePath: "docs/v2/")
struct LooseBasePathRoutes {
  @Route("/")
  static func home() -> EmptyHTML {
    EmptyHTML()
  }
}

/// `/` means no base path.
@Routes(basePath: "/")
struct RootBasePathRoutes {
  @Route("/")
  static func home() -> EmptyHTML {
    EmptyHTML()
  }
}

private func basePathRouter(
  _ routes: BasePathRoutes.RouteSet,
  at url: String
) -> (Router<BasePathRoutes.RouteView>, MemoryHistory) {
  let document = MemoryHistory(initialPath: url)
  let router = Router(
    routes: routes.tree,
    history: BrowserHistory(history: document),
    basePath: "/SpeedMath"
  )
  return (router, document)
}

@Test func basePathNormalizesSlashesAndTreatsRootAsNone() {
  #expect(BasePath("").value == "")
  #expect(BasePath("/").value == "")
  #expect(BasePath("//").value == "")
  #expect(BasePath("SpeedMath").value == "/SpeedMath")
  #expect(BasePath("/SpeedMath").value == "/SpeedMath")
  #expect(BasePath("/SpeedMath/").value == "/SpeedMath")
  #expect(BasePath("//docs/v2//").value == "/docs/v2")
}

@Test func basePathMapsDocumentLocationsInsideItOnly() {
  let base = BasePath("/SpeedMath")

  #expect(base.routeLocation(in: RouteLocation(url: "/SpeedMath")) == RouteLocation(url: "/"))
  #expect(base.routeLocation(in: RouteLocation(url: "/SpeedMath/")) == RouteLocation(url: "/"))
  #expect(
    base.routeLocation(in: RouteLocation(url: "/SpeedMath/users/42?tab=posts#top"))
      == RouteLocation(url: "/users/42?tab=posts#top")
  )
  #expect(base.routeLocation(in: RouteLocation(url: "/SpeedMath?x=1")) == RouteLocation(url: "/?x=1"))

  // A shared prefix that is not a whole segment, another case, or another path is outside.
  #expect(base.routeLocation(in: RouteLocation(url: "/SpeedMathOld/users/42")) == nil)
  #expect(base.routeLocation(in: RouteLocation(url: "/speedmath/users/42")) == nil)
  #expect(base.routeLocation(in: RouteLocation(url: "/users/42")) == nil)
  #expect(base.routeLocation(in: RouteLocation(url: "/")) == nil)

  #expect(base.documentLocation(for: RouteLocation(url: "/")).href == "/SpeedMath/")
  #expect(base.documentLocation(for: RouteLocation(url: "/users/42?a=1#b")).href == "/SpeedMath/users/42?a=1#b")

  // Without a base path, both directions are the identity.
  let location = RouteLocation(url: "/users/42?a=1")
  #expect(BasePath.none.routeLocation(in: location) == location)
  #expect(BasePath.none.documentLocation(for: location) == location)
}

@Test func routerMatchesRoutesBelowTheBasePath() throws {
  let routes = try BasePathRoutes.routes()

  let (home, _) = basePathRouter(routes, at: "/SpeedMath/")
  #expect(home.currentRoute == routes.handles.home)
  #expect(home.location.href == "/")

  let (bare, _) = basePathRouter(routes, at: "/SpeedMath")
  #expect(bare.currentRoute == routes.handles.home)

  let (user, _) = basePathRouter(routes, at: "/SpeedMath/users/42?tab=posts")
  #expect(user.currentRoute == routes.handles.user)
  #expect(user.currentParams == ["id": "42"])
  #expect(user.location.href == "/users/42?tab=posts")
  #expect(user.isActive(try routes.user(id: 42, tab: "posts")))
  #expect(user.basePath == "/SpeedMath")
}

@Test func locationsOutsideTheBasePathRenderNotFound() throws {
  let routes = try BasePathRoutes.routes()

  // `/users/42` would match a route if it were below the base path.
  for url in ["/users/42", "/", "/SpeedMathOld/users/42"] {
    let (router, _) = basePathRouter(routes, at: url)
    #expect(router.matchedRoutes.isEmpty, "\(url)")
    #expect(router.currentRoute == nil, "\(url)")
    #expect(!router.isActive(try routes.user(id: 42)), "\(url)")

    let rendered = try router.renderCurrentRoute()
    guard case .notFound(let context) = rendered.storage else {
      Issue.record("Expected the not-found fallback for \(url), got \(rendered.storage)")
      continue
    }
    // The not-found context reports the document location, since it has no route location.
    #expect(context.location == RouteLocation(url: url))
    #expect(router.location == RouteLocation(url: url))
  }

  // A location below the base path that no route matches is also not found.
  let (missing, _) = basePathRouter(routes, at: "/SpeedMath/missing")
  guard case .notFound(let context) = try missing.renderCurrentRoute().storage else {
    Issue.record("Expected the not-found fallback for /SpeedMath/missing")
    return
  }
  #expect(context.location.path == "/missing")
}

@Test func basePathPrefixesHrefsFromEveryEntryPoint() throws {
  let routes = try BasePathRoutes.routes()
  let (router, _) = basePathRouter(routes, at: "/SpeedMath/")

  let user = try routes.user(id: 42, tab: "posts", hash: "top")
  #expect(user.location.href == "/users/42?tab=posts#top")
  #expect(try routes.href(to: user) == "/SpeedMath/users/42?tab=posts#top")
  #expect(try router.href(to: user) == "/SpeedMath/users/42?tab=posts#top")
  #expect(try router.href(to: routes.handles.user, params: ["id": 7]) == "/SpeedMath/users/7")
  #expect(try routes.href(to: routes.home()) == "/SpeedMath/")
  #expect(router.navigator.linkHref(for: user) == "/SpeedMath/users/42?tab=posts#top")
  #expect(try router.navigator.href(to: user) == "/SpeedMath/users/42?tab=posts#top")

  let link = BasePathRoutes.Link(to: user) { "User" }
  #expect(link.href == "/SpeedMath/users/42?tab=posts#top")

  // The generated router carries the declared base path.
  #expect(routes.router().basePath == "/SpeedMath")
}

@Test func basePathPrefixesPushedAndReplacedHistoryEntries() throws {
  let routes = try BasePathRoutes.routes()
  let (router, document) = basePathRouter(routes, at: "/SpeedMath/")

  try router.navigate(to: routes.user(id: 42))
  #expect(document.location.href == "/SpeedMath/users/42")
  #expect(router.location.href == "/users/42")
  #expect(router.currentRoute == routes.handles.user)

  try router.replace(to: routes.home())
  #expect(document.location.href == "/SpeedMath/")
  #expect(router.currentRoute == routes.handles.home)

  router.navigate(to: RouteLocation(url: "/users/7?tab=posts"), replace: true)
  #expect(document.location.href == "/SpeedMath/users/7?tab=posts")
  #expect(router.currentParams == ["id": "7"])

  try router.navigate(to: routes.handles.user, params: ["id": 9])
  #expect(document.location.href == "/SpeedMath/users/9")

  router.back()
  #expect(document.location.href == "/SpeedMath/users/7?tab=posts")
  #expect(router.currentParams == ["id": "7"])

  // A history entry outside the base path, such as one pushed by other code, is not found.
  document.push(RouteLocation(url: "/elsewhere"))
  #expect(router.currentRoute == nil)
  document.go(-1)
  #expect(router.currentParams == ["id": "7"])
}

@Test func mountedFeaturesGetTheHostBasePath() throws {
  let routes = try BasePathRoutes.routes()
  let (router, document) = basePathRouter(routes, at: "/SpeedMath/shop/products/7")

  #expect(
    router.matchedRoutes == [
      routes.handles.shop, routes.shop.handles.shopShell, routes.shop.handles.product,
    ]
  )

  let catalog = routes.shop.catalog(sort: "price")
  #expect(catalog.location.href == "/shop?sort=price")
  #expect(try routes.href(to: catalog) == "/SpeedMath/shop?sort=price")
  #expect(try router.navigator.href(to: catalog) == "/SpeedMath/shop?sort=price")
  // `RouteLink` takes its href from the navigator.
  #expect(router.navigator.linkHref(for: catalog) == "/SpeedMath/shop?sort=price")

  try router.navigator.navigate(to: catalog)
  #expect(document.location.href == "/SpeedMath/shop?sort=price")
  #expect(router.currentRoute == routes.shop.handles.catalog)
  #expect(router.navigator.isActive(routes.handles.shop, options: .descendant))
}

@Test func basePathSpellingsNormalizeInGeneratedCode() throws {
  let loose = try LooseBasePathRoutes.routes()
  #expect(try loose.href(to: loose.home()) == "/docs/v2/")
  #expect(LooseBasePathRoutes.Link(to: loose.home()) { "Home" }.href == "/docs/v2/")
  #expect(loose.router().basePath == "/docs/v2")

  let root = try RootBasePathRoutes.routes()
  #expect(try root.href(to: root.home()) == "/")
  #expect(RootBasePathRoutes.Link(to: root.home()) { "Home" }.href == "/")
  #expect(root.router().basePath == "")

  let router = Router(
    routes: loose.tree,
    history: BrowserHistory(history: MemoryHistory(initialPath: "/docs/v2")),
    basePath: "docs/v2/"
  )
  #expect(router.currentRoute == loose.handles.home)
}
