// expected-error: navigate|BlogRoutes\.RouteView
import ElementaryRouter
import RouteFixtures

// A destination of one route group cannot be navigated to with another group's router.
public func navigateWithAnotherRouteGroup(
  shopRouter: Router<ShopRoutes.RouteView>,
  post: RouteDestination<BlogRoutes.RouteView>
) throws(RouteMatchError) {
  try shopRouter.navigate(to: post)
}
