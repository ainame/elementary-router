// expected-error: navigate|HashMallRoutes\.RouteView
import ComposedHost
import ElementaryRouter

// The same feature mounted by two hosts produces destinations of two different types.
public func navigateAcrossHosts(
  mallRouter: Router<MallRoutes.RouteView>,
  hashMall: HashMallRoutes.RouteSet
) throws(RouteMatchError) {
  try mallRouter.navigate(to: hashMall.store.catalog())
}
