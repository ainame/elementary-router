// expected-error: is inside mount `store` at `/store`
import ElementaryRouter
import ElementaryUI
import StoreFeature

// A mounted feature owns every URL below its path, so a host route there could overlap it.
@Routes
public struct CornerRoutes {
  @Route("/store/products/:id")
  public static func product(id: Int) -> EmptyHTML {
    EmptyHTML()
  }

  @Mount("/store")
  typealias Store = StoreRoutes<RouteView>
}
