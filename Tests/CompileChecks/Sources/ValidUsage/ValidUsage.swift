import ElementaryRouter
import ElementaryUI
import RouteFixtures

// Positive control: the same calls the `Rejects*` targets get wrong, written correctly. If this
// target fails, the negative checks prove nothing.

@View
struct ShopApp {
  let routes: ShopRoutes.RouteSet
  let router: Router<ShopRoutes.RouteView>
  let product: RouteDestination<ShopRoutes.RouteView>

  var body: some View {
    ShopRoutes.Provider(routes, router: router) {
      nav {
        ShopRoutes.Link(to: routes.home()) { "Home" }
        ShopRoutes.Link(to: product, replace: true, target: .blank) { "Product" }
      }
      ShopRoutes.RouterView(routes, router: router)
    }
  }
}

/// Generated outlet views of public route sets are public, so other modules can name them.
public func catalogOutletType() -> ShopRoutes.RouteView.CatalogOutlet.Type {
  ShopRoutes.RouteView.CatalogOutlet.self
}

/// A view that owns its router: it is created once for the mounted view.
@View
struct OwnedShopApp {
  var body: some View {
    ShopRoutes.RouterView()
  }
}

public func useTypedDestinations(
  shop: ShopRoutes.RouteSet,
  blog: BlogRoutes.RouteSet
) throws(RouteMatchError) -> [String] {
  let shopRouter = shop.router()
  let blogRouter = blog.router()
  let product = try shop.product(id: 42, tab: "reviews", hash: "top")
  let defaultTab = try shop.product(id: 42)
  let post = try blog.post(slug: "hello")
  // `region` is required by the enclosing `orders` layout; `view` is a defaulted layout query.
  let order = try shop.order(id: 7, region: "eu")
  let gridProduct = try shop.product(id: 42, view: "list")

  try shopRouter.navigate(to: product)
  try shopRouter.replace(to: shop.home())
  try blogRouter.navigate(to: post, replace: true)
  _ = ShopApp(routes: shop, router: shopRouter, product: defaultTab)

  return [
    try shop.href(to: product),
    try shop.href(to: order),
    try shop.href(to: gridProduct),
    try blog.href(to: post),
    try shopRouter.href(to: product),
    try blogRouter.href(to: post),
    shopRouter.isActive(product) ? "active" : "inactive",
    blogRouter.isActive(post, includeQuery: false, includeHash: true) ? "active" : "inactive",
  ]
}

/// A public path-mode route set served under a sub-path, such as GitHub Pages' `/<repository>/`.
@Routes(basePath: "/my-app")
public struct SubPathRoutes {
  @Route("/")
  public static func home() -> EmptyHTML {
    EmptyHTML()
  }
}

@View
struct SubPathApp {
  var body: some View {
    SubPathRoutes.RouterView()
  }
}

public func subPathRouter(_ routes: SubPathRoutes.RouteSet) -> Router<SubPathRoutes.RouteView> {
  routes.router()
}
