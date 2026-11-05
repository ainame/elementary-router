import ElementaryUI
import Testing

@testable import ElementaryRouter

// Features are generic `@Routes` structs that a host mounts into its own route tree. The
// downstream fixture in Tests/CompileChecks and Examples/FeatureComposition declare features and
// hosts in separate modules; these tests cover the same generated code within one module.

/// A mountable shop feature with a feature layout, an index route, and a parameter route.
@Routes
struct TestShopRoutes<Root: View> {
  @Layout("/")
  static func shopShell<Content: View>(context: RouteContext, outlet: Outlet<Content>) -> EmptyHTML {
    CallRecorder.record(RecordedCall("shopShell", context: context))
    renderOutlet(outlet)
    return EmptyHTML()
  }

  @Route("/")
  static func catalog(sort: Query<String> = Query("name")) -> EmptyHTML {
    CallRecorder.record(RecordedCall("catalog", ["sort=\(sort.value)"]))
    return EmptyHTML()
  }

  @Route("/products/:id")
  static func product(id: Int, context: RouteContext) -> EmptyHTML {
    CallRecorder.record(RecordedCall("product", ["id=\(id)"], context: context))
    return EmptyHTML()
  }
}

/// A second feature without layouts.
@Routes
struct TestBlogRoutes<Root: View> {
  @Route("/")
  static func posts() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/:slug")
  static func post(slug: String) -> EmptyHTML {
    EmptyHTML()
  }
}

/// A path-mode host that mounts both features inside its root layout.
@Routes
struct ComposedRoutes {
  @Layout("/")
  static func shell<Content: View>(
    context: RouteContext,
    tab: Query<String> = Query("none"),
    outlet: Outlet<Content>
  ) -> EmptyHTML {
    CallRecorder.record(RecordedCall("shell", ["tab=\(tab.value)"], context: context))
    renderOutlet(outlet)
    return EmptyHTML()
  }

  @Route("/")
  static func home() -> EmptyHTML {
    EmptyHTML()
  }

  @Mount("/shop")
  typealias Shop = TestShopRoutes<RouteView>

  @Mount("/blog")
  typealias Blog = TestBlogRoutes<RouteView>

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> EmptyHTML {
    EmptyHTML()
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> EmptyHTML {
    EmptyHTML()
  }
}

/// A hash-mode host that mounts the same features at the top level.
@Routes(mode: .hash)
struct HashComposedRoutes {
  @Mount("/shop")
  typealias Shop = TestShopRoutes<RouteView>

  @Mount("/blog")
  typealias Blog = TestBlogRoutes<RouteView>
}

private func composedRouter(
  _ routes: ComposedRoutes.RouteSet,
  at url: String = "/"
) -> Router<ComposedRoutes.RouteView> {
  Router(routes: routes.tree, history: BrowserHistory(history: MemoryHistory(initialPath: url)))
}

/// Records the context paths each mount wrapper receives.
private final class WrapLog {
  var paths: [[String]] = []
}

@Test func mountedFeaturesJoinTheHostTreeWithParentToLeafStacks() throws {
  let routes = try ComposedRoutes.routes()
  let router = composedRouter(routes)

  let product = try routes.shop.product(id: 7, hash: "reviews")
  #expect(product.route == routes.shop.handles.product)
  #expect(product.location.href == "/shop/products/7#reviews")
  #expect(try routes.href(to: product) == "/shop/products/7#reviews")
  #expect(try router.href(to: product) == "/shop/products/7#reviews")

  try router.navigate(to: product)
  #expect(
    router.matchedRoutes == [
      routes.handles.shell, routes.handles.shop, routes.shop.handles.shopShell, routes.shop.handles.product,
    ]
  )
  #expect(router.currentParams == ["id": "7"])
  #expect(router.isActive(product, includeHash: true))
  #expect(router.isActive(routes.handles.shop, options: .descendant))
  #expect(router.isActive(routes.shop.handles.shopShell, options: .descendant))
  #expect(!router.isActive(routes.handles.blog, options: .descendant))

  // The feature's index route is the mount path itself.
  let catalog = routes.shop.catalog(sort: "price")
  #expect(catalog.location.href == "/shop?sort=price")
  try router.navigate(to: catalog)
  #expect(router.matchedRoutes.last == routes.shop.handles.catalog)

  // Cross-feature navigation uses the same router and destination type.
  let post = try routes.blog.post(slug: "hello")
  #expect(post.location.href == "/blog/hello")
  try router.navigate(to: post)
  #expect(router.matchedRoutes == [routes.handles.shell, routes.handles.blog, routes.blog.handles.post])
  #expect(router.currentParams == ["slug": "hello"])
  #expect(routes.blog.posts().location.href == "/blog")

  // Host routes and feature routes share one tree.
  try router.navigate(to: routes.home())
  #expect(router.matchedRoutes == [routes.handles.shell, routes.handles.home])
}

@Test func mountedFeatureViewsRenderInsideTheHostLayouts() throws {
  let routes = try ComposedRoutes.routes()
  let view = try composedRouter(routes, at: "/shop/products/7?tab=shop").renderCurrentRoute()

  // The host shell's outlet holds the feature's route view as one concrete case.
  guard case .shell(_, let tab, let shellOutlet) = view.storage,
    case .shop(let shop) = shellOutlet.storage,
    case .shopShell(_, let shopOutlet) = shop.storage,
    case .product(let id, _) = shopOutlet.storage
  else {
    Issue.record("Expected the shop feature inside the shell layout, got \(view.storage)")
    return
  }
  #expect(tab == "shop")
  #expect(id == 7)

  let hostCalls = CallRecorder.calls(rendering: view)
  #expect(hostCalls.map(\.description) == ["shell(tab=shop)"])
  #expect(hostCalls[0].route == routes.handles.shell)

  // Feature records read their own contexts from the end of the host match stack.
  let featureCalls = CallRecorder.calls(rendering: shop)
  #expect(featureCalls.map(\.description) == ["shopShell()", "product(id=7)"])
  #expect(featureCalls[0].route == routes.shop.handles.shopShell)
  #expect(featureCalls[0].path == "/shop")
  #expect(featureCalls[1].route == routes.shop.handles.product)
  #expect(featureCalls[1].path == "/shop/products/:id")
  #expect(featureCalls[1].params == ["id=7"])

  // Navigating inside the feature keeps the host shell and the feature shell on their cases.
  let catalog = try composedRouter(routes, at: "/shop").renderCurrentRoute()
  guard case .shell(_, _, let catalogShell) = catalog.storage,
    case .shop(let catalogShop) = catalogShell.storage,
    case .shopShell(_, let catalogOutlet) = catalogShop.storage,
    case .catalog(let sort) = catalogOutlet.storage
  else {
    Issue.record("Expected the shop catalog inside the shell layout, got \(catalog.storage)")
    return
  }
  #expect(sort == "name")
}

@Test func hostFallbackPolicyCoversMountedFeatures() throws {
  let routes = try ComposedRoutes.routes()

  let missing = try composedRouter(routes, at: "/shop/missing").renderCurrentRoute()
  guard case .notFound(let notFound) = missing.storage else {
    Issue.record("Expected the host not-found fallback, got \(missing.storage)")
    return
  }
  #expect(notFound.location.path == "/shop/missing")

  let invalid = try composedRouter(routes, at: "/shop/products/abc").renderCurrentRoute()
  guard case .routeError(let error) = invalid.storage else {
    Issue.record("Expected the host route error fallback, got \(invalid.storage)")
    return
  }
  #expect(error.routeContext.route == routes.shop.handles.product)
  #expect(error.error == .invalid(name: "id", rawValue: "abc", expected: "Int"))
}

@Test func mountedDestinationsHaveOneLocationInPathAndHashHosts() throws {
  let pathRoutes = try ComposedRoutes.routes()
  let hashRoutes = try HashComposedRoutes.routes()

  let pathProduct = try pathRoutes.shop.product(id: 7, hash: "top")
  let hashProduct = try hashRoutes.shop.product(id: 7, hash: "top")
  #expect(pathProduct.location == hashProduct.location)
  #expect(try pathRoutes.href(to: pathProduct) == "/shop/products/7#top")
  #expect(try hashRoutes.href(to: hashProduct) == "#/shop/products/7#top")

  let pathNavigator = composedRouter(pathRoutes).navigator
  #expect(try pathNavigator.href(to: pathProduct) == "/shop/products/7#top")
  #expect(pathNavigator.linkHref(for: pathProduct) == "/shop/products/7#top")

  let hashRouter = HashRouter(
    routes: hashRoutes.tree,
    history: BrowserHistory(history: MemoryHistory(initialPath: "/app/"))
  )
  let hashNavigator = hashRouter.navigator
  #expect(try hashRouter.href(to: hashProduct) == "#/shop/products/7#top")
  #expect(try hashNavigator.href(to: hashProduct) == "#/shop/products/7#top")
  #expect(hashNavigator.linkHref(for: hashProduct) == "#/shop/products/7#top")

  // A navigator drives its router: a feature view can navigate across features with it.
  let post = try hashRoutes.blog.post(slug: "hello")
  try hashNavigator.navigate(to: post)
  #expect(hashRouter.matchedRoutes == [hashRoutes.handles.blog, hashRoutes.blog.handles.post])
  #expect(hashNavigator.matchedRoutes == hashRouter.matchedRoutes)
  #expect(hashNavigator.location == hashRouter.location)
  #expect(hashNavigator.isActive(post))
  #expect(hashNavigator.isActive(hashRoutes.handles.blog, options: .descendant))
  try hashNavigator.replace(to: hashProduct)
  #expect(hashRouter.matchedRoutes.last == hashRoutes.shop.handles.product)
}

@Test func routersRejectMountedDestinationsOfAnotherRouteSet() throws {
  let routes = try ComposedRoutes.routes()
  let other = try ComposedRoutes.routes()
  let router = composedRouter(routes)
  let navigator = router.navigator
  let foreign = try other.shop.product(id: 7)

  #expect(other.shop.handles.product != routes.shop.handles.product)
  #expect(throws: RouteMatchError.foreignRoute) { try routes.href(to: foreign) }
  #expect(throws: RouteMatchError.foreignRoute) { try router.navigate(to: foreign) }
  #expect(throws: RouteMatchError.foreignRoute) { try navigator.navigate(to: foreign) }
  #expect(throws: RouteMatchError.foreignRoute) { try navigator.href(to: foreign) }
  #expect(!router._accepts(foreign))
  #expect(!navigator.accepts(foreign))
  #expect(!navigator.isActive(foreign))
  #expect(router.location.path == "/")

  // A link to a foreign destination keeps its href but does not navigate on the client.
  let link = RouteLink(to: foreign) { "Product" }
  #expect(link.href == "/shop/products/7")
}

@Test func generatedHostProviderSharesOneRouterWithMountedFeatures() throws {
  let routes = try ComposedRoutes.routes()
  let router = routes.router()

  let provider = ComposedRoutes.Provider(routes, router: router) {
    RouteLink(to: routes.shop.catalog()) { "Shop" }
  }
  #expect(provider.router === router)
  #expect(provider.routes.shop.handles.product == routes.shop.handles.product)
  #expect(router._accepts(routes.shop.catalog()))

  let routerView = ComposedRoutes.RouterView(routes, router: router)
  #expect(routerView.router === router)
  #expect(routerView.routes.blog.handles.post == routes.blog.handles.post)
}

@Test func manuallyMountedFeaturesUseTheHostTreeAndWrapper() throws {
  let log = WrapLog()
  let builder = RouteBuilder<EmptyHTML>()
  let mount = builder._generatedLayout("/store", parent: nil, decode: { _ in })
  let handles = TestShopRoutes<EmptyHTML>._register(into: builder, under: mount) { _, contexts in
    log.paths.append(contexts.map(\.path))
    return EmptyHTML()
  }
  let tree = try builder._build()
  let store = TestShopRoutes<EmptyHTML>.RouteSet(_mountedIn: tree, handles: handles)

  let product = try store.product(id: 3)
  #expect(product.location.href == "/store/products/3")
  #expect(
    tree._matches(product.location).map(\.route) == [mount, handles.shopShell, handles.product]
  )

  _ = try tree._render(product.location)
  #expect(log.paths == [["/store", "/store", "/store/products/:id"]])
}

@Test func routeBuilderRejectsConflictingAndForeignMounts() {
  // A host route that matches the same URLs as a mounted feature route.
  #expect(
    throws: RouteTreeError.ambiguousRoute(path: "/shop/products/:id", conflictingPath: "/shop/products/:sku")
  ) {
    let builder = RouteBuilder<EmptyHTML>()
    builder._route("/shop/products/:sku") { EmptyHTML() }
    let mount = builder._generatedLayout("/shop", parent: nil, decode: { _ in })
    _ = TestShopRoutes<EmptyHTML>._register(into: builder, under: mount) { _, _ in EmptyHTML() }
    _ = try builder._build()
  }

  // Two features mounted at one path.
  #expect(throws: RouteTreeError.duplicateRoute(path: "/shop")) {
    let builder = RouteBuilder<EmptyHTML>()
    let first = builder._generatedLayout("/shop", parent: nil, decode: { _ in })
    let second = builder._generatedLayout("/shop", parent: nil, decode: { _ in })
    _ = TestShopRoutes<EmptyHTML>._register(into: builder, under: first) { _, _ in EmptyHTML() }
    _ = TestBlogRoutes<EmptyHTML>._register(into: builder, under: second) { _, _ in EmptyHTML() }
    _ = try builder._build()
  }

  // A mount record registered by another builder.
  #expect(throws: RouteTreeError.foreignParent(path: "/")) {
    let other = RouteBuilder<EmptyHTML>()
    let foreignMount = other._generatedLayout("/shop", parent: nil, decode: { _ in })
    let builder = RouteBuilder<EmptyHTML>()
    _ = TestShopRoutes<EmptyHTML>._register(into: builder, under: foreignMount) { _, _ in EmptyHTML() }
    _ = try builder._build()
  }
}
