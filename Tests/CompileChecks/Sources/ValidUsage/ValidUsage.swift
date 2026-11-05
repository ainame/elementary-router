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

public func useTypedDestinations(
  shop: ShopRoutes.RouteSet,
  blog: BlogRoutes.RouteSet
) throws(RouteMatchError) -> [String] {
  let shopRouter = shop.router()
  let blogRouter = blog.router()
  let product = try shop.product(id: 42, tab: "reviews", hash: "top")
  let defaultTab = try shop.product(id: 42)
  let post = try blog.post(slug: "hello")

  try shopRouter.navigate(to: product)
  try shopRouter.replace(to: shop.home())
  try blogRouter.navigate(to: post, replace: true)
  _ = ShopApp(routes: shop, router: shopRouter, product: defaultTab)

  return [
    try shop.href(to: product),
    try blog.href(to: post),
    try shopRouter.href(to: product),
    try blogRouter.href(to: post),
    shopRouter.isActive(product) ? "active" : "inactive",
    blogRouter.isActive(post, includeQuery: false, includeHash: true) ? "active" : "inactive",
  ]
}
