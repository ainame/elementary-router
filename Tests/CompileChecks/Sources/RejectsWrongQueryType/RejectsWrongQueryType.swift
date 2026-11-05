// expected-error: 'Int'.*'String'
import ElementaryRouter
import RouteFixtures

// `tab` is declared as `Query<String>`, so an integer query value does not compile.
public func productWithIntegerTab(
  shop: ShopRoutes.RouteSet
) throws(RouteMatchError) -> RouteDestination<ShopRoutes.RouteView> {
  try shop.product(id: 42, tab: 3)
}
