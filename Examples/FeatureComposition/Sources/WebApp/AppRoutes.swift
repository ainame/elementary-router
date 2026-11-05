import Blog
import ElementaryRouter
import ElementaryUI
import Shop

/// The host route set. It owns the shell layout, the fallbacks, the routing mode, and the one
/// router, and mounts the shop and blog features at static paths inside the shell.
///
/// The macro cannot read the features' declarations, which live in other modules. Each `@Mount`
/// names a feature specialized with this route set's view; the feature registers its own routes.
@Routes
struct AppRoutes {
  @Layout("/")
  static func shell<Content: View>(context: RouteContext, outlet: Outlet<Content>) -> AppShell<Content> {
    AppShell(outlet: outlet)
  }

  @Route("/")
  static func home() -> HomePage {
    HomePage()
  }

  @Mount("/shop")
  typealias Shop = ShopRoutes<RouteView>

  @Mount("/blog")
  typealias Blog = BlogRoutes<RouteView>

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> MessagePage {
    MessagePage(name: "not-found", message: "Nothing lives at \(context.location.path).")
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> MessagePage {
    MessagePage(name: "route-error", message: "\(context.routeContext.location.path) is not a valid page.")
  }
}
