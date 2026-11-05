// expected-error: RouteDestination<Root>|MallRoutes\.RouteView
import ComposedHost
import ElementaryRouter
import ElementaryUI
import StoreFeature

// Code generic over a feature's root cannot use a concrete host's destinations.
public func featureDestination<Root: View>(
  in store: StoreRoutes<Root>.RouteSet,
  mall: MallRoutes.RouteSet
) -> RouteDestination<Root> {
  mall.store.catalog()
}
