import ComposedHost
import ElementaryRouter
import ElementaryUI
import NewsFeature
import StoreFeature

// Positive control for mounted features: a host module composes features from two other
// modules into one tree and one router, in path and hash mode.

/// The host's generated router view owns one router for the host and every mounted feature.
@View
struct MallApp {
  var body: some View {
    MallRoutes.RouterView()
  }
}

/// Host views link to mounted destinations with the host's own generated link.
@View
struct MallNavigation {
  let routes: MallRoutes.RouteSet

  var body: some View {
    MallRoutes.Link(to: routes.store.catalog()) { "Store" }
    MallRoutes.Link(to: routes.news.index(), replace: true) { "News" }
    RouteLink(to: routes.home()) { "Home" }
  }
}

/// A feature route set and the host outlet that stores a feature have public, nameable types.
public func mountedTypes() -> (
  StoreRoutes<MallRoutes.RouteView>.RouteSet.Type,
  MallRoutes.RouteView.ShellOutlet.Type
) {
  (StoreRoutes<MallRoutes.RouteView>.RouteSet.self, MallRoutes.RouteView.ShellOutlet.self)
}

public func useMountedFeatures(
  mall: MallRoutes.RouteSet,
  hashMall: HashMallRoutes.RouteSet
) throws(RouteMatchError) -> [String] {
  let router = mall.router()
  let navigator = router.navigator
  let product = try mall.store.product(sku: "tea", hash: "reviews")
  let generic = try storeProductDestination(mall.store, sku: "mug")
  let article = try mall.news.article(slug: "launch")
  // Feature factories take the feature's own queries; host layouts above the mount use their
  // defaults, because the host macro rejects required queries there.
  let catalog = mall.store.catalog(page: 2)

  try router.navigate(to: product)
  try navigator.navigate(to: article)
  try navigator.replace(to: catalog)

  let hashRouter = hashMall.router()
  let hashNavigator = hashRouter.navigator
  let hashProduct = try hashMall.store.product(sku: "tea")
  try hashRouter.navigate(to: hashProduct)

  return [
    try mall.href(to: product),
    try mall.href(to: generic),
    try router.href(to: article),
    try navigator.href(to: catalog),
    try hashMall.href(to: hashProduct),
    try hashNavigator.href(to: hashMall.news.index()),
    router.isActive(mall.handles.store, options: .descendant) ? "store" : "elsewhere",
    navigator.isActive(mall.store.handles.frame, options: .descendant) ? "frame" : "elsewhere",
    hashNavigator.isActive(hashProduct) ? "active" : "inactive",
    "\(navigator.matchedRoutes.count) \(hashNavigator.location.path)",
  ]
}
