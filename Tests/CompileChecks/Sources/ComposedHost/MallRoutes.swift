import ElementaryRouter
import ElementaryUI
import NewsFeature
import StoreFeature

@View
public struct MallShell<Content: View> {
  let outlet: Outlet<Content>

  public init(outlet: Outlet<Content>) {
    self.outlet = outlet
  }

  public var body: some View {
    outlet
  }
}

/// A public path-mode host that mounts features from two other modules.
@Routes
public struct MallRoutes {
  @Layout("/")
  public static func shell<Content: View>(
    tab: Query<String> = Query("home"),
    outlet: Outlet<Content>
  ) -> MallShell<Content> {
    MallShell(outlet: outlet)
  }

  @Route("/")
  public static func home() -> EmptyHTML {
    EmptyHTML()
  }

  @Mount("/store")
  typealias Store = StoreRoutes<RouteView>

  @Mount("/news")
  typealias News = NewsRoutes<RouteView>

  @NotFound
  public static func notFound(context: RouteNotFoundContext) -> EmptyHTML {
    EmptyHTML()
  }

  @RouteError
  public static func routeError(context: RouteErrorContext) -> EmptyHTML {
    EmptyHTML()
  }
}

/// A public hash-mode host that mounts the same features at the top level.
@Routes(mode: .hash)
public struct HashMallRoutes {
  @Mount("/store")
  typealias Store = StoreRoutes<RouteView>

  @Mount("/news")
  typealias News = NewsRoutes<HashMallRoutes.RouteView>

  @NotFound
  public static func notFound(context: RouteNotFoundContext) -> EmptyHTML {
    EmptyHTML()
  }
}
