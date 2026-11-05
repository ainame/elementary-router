// expected-error: missing argument.*'id'
import ElementaryRouter
import RouteFixtures

// `id` is a required path value, so omitting it does not compile.
public func productWithoutID(
  shop: ShopRoutes.RouteSet
) throws(RouteMatchError) -> RouteDestination<ShopRoutes.RouteView> {
  try shop.product()
}
