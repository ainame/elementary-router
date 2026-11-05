// expected-error: type aliases must name a feature specialized with this route set's view
import ComposedHost
import ElementaryRouter
import ElementaryUI
import StoreFeature

// A host can only mount a feature specialized with its own route view.
@Routes
public struct OutletRoutes {
  @Mount("/store")
  typealias Store = StoreRoutes<MallRoutes.RouteView>
}
