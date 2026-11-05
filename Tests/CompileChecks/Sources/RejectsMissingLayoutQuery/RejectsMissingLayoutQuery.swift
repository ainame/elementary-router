// expected-error: missing argument.*'region'
import ElementaryRouter
import RouteFixtures

// The `orders` layout requires `region`, so the `order` destination cannot omit it.
public func orderWithoutRegion(
  shop: ShopRoutes.RouteSet
) throws(RouteMatchError) -> RouteDestination<ShopRoutes.RouteView> {
  try shop.order(id: 7)
}
