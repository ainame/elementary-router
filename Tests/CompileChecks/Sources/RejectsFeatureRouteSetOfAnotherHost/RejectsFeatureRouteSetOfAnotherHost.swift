// expected-error: HashMallRoutes\.RouteView
import ComposedHost
import ElementaryRouter
import StoreFeature

// A feature's route set is specialized for one host's route view.
public func storeOfAnotherHost(
  hashMall: HashMallRoutes.RouteSet
) -> StoreRoutes<MallRoutes.RouteView>.RouteSet {
  hashMall.store
}
