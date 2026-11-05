// expected-error: 'String'.*'Int'
import ElementaryRouter
import RouteFixtures

// `id` is declared as `Int`, so a string path value does not compile.
public func productWithStringID(
  shop: ShopRoutes.RouteSet
) throws(RouteMatchError) -> RouteDestination<ShopRoutes.RouteView> {
  try shop.product(id: "42")
}
