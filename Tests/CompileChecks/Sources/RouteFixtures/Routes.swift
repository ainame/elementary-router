import ElementaryRouter
import ElementaryUI

@View
public struct ShopShell<Content: View> {
  let outlet: Outlet<Content>

  public init(outlet: Outlet<Content>) {
    self.outlet = outlet
  }

  public var body: some View {
    outlet
  }
}

/// A public path-mode route group, compiled in a module other than the one that uses it.
@Routes
public struct ShopRoutes {
  @Layout("/")
  public static func shell<Content: View>(outlet: Outlet<Content>) -> ShopShell<Content> {
    ShopShell(outlet: outlet)
  }

  @Route("/")
  public static func home() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/products/:id")
  public static func product(id: Int, tab: Query<String> = Query("details")) -> EmptyHTML {
    EmptyHTML()
  }

  @NotFound
  public static func notFound(context: RouteNotFoundContext) -> EmptyHTML {
    EmptyHTML()
  }
}

/// A second, unrelated public route group in hash mode.
@Routes(mode: .hash)
public struct BlogRoutes {
  @Route("/posts/:slug")
  public static func post(slug: String) -> EmptyHTML {
    EmptyHTML()
  }
}
