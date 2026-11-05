// expected-error: navigate|MallRoutes\.RouteView
import ComposedHost
import ElementaryRouter
import RouteFixtures

// A mounted feature's destination belongs to its host tree; another route set's router cannot
// take it.
public func navigateWithStandaloneRouter(
  shopRouter: Router<ShopRoutes.RouteView>,
  mall: MallRoutes.RouteSet
) throws(RouteMatchError) {
  try shopRouter.navigate(to: mall.store.catalog())
}
