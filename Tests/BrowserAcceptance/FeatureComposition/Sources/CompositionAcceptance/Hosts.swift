import Blog
import ElementaryRouter
import ElementaryUI
import GuideAlpha
import GuideBeta
import Shop

// This module declares a host named `Routes` and imports two features named `Routes`, so the
// macro attributes are module-qualified.

/// The path-mode host. It is named `Routes`, like the features it mounts from `GuideAlpha` and
/// `GuideBeta`: its own environment key and theirs must not share a value.
@ElementaryRouter.Routes
struct Routes {
  @Layout("/")
  static func shell<Content: View>(outlet: Outlet<Content>) -> AcceptanceShell<RouteView, Content> {
    AcceptanceShell(outlet: outlet)
  }

  @Route("/")
  static func home() -> HostHomePage {
    HostHomePage()
  }

  @Mount("/shop")
  typealias Shop = ShopRoutes<RouteView>

  @Mount("/blog")
  typealias Blog = BlogRoutes<RouteView>

  @Mount("/alpha")
  typealias Alpha = GuideAlpha.Routes<RouteView>

  @Mount("/beta")
  typealias Beta = GuideBeta.Routes<RouteView>

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> AcceptancePage {
    AcceptancePage(name: "not-found", detail: context.location.path)
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> AcceptancePage {
    AcceptancePage(name: "route-error", detail: context.routeContext.path)
  }
}

/// The same host in hash mode: the features and the shell are unchanged.
@ElementaryRouter.Routes(mode: .hash)
struct HashHost {
  @Layout("/")
  static func shell<Content: View>(outlet: Outlet<Content>) -> AcceptanceShell<RouteView, Content> {
    AcceptanceShell(outlet: outlet)
  }

  @Route("/")
  static func home() -> AcceptancePage {
    AcceptancePage(name: "home")
  }

  @Mount("/shop")
  typealias Shop = ShopRoutes<RouteView>

  @Mount("/blog")
  typealias Blog = BlogRoutes<RouteView>

  @Mount("/alpha")
  typealias Alpha = GuideAlpha.Routes<RouteView>

  @Mount("/beta")
  typealias Beta = GuideBeta.Routes<RouteView>

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> AcceptancePage {
    AcceptancePage(name: "not-found", detail: context.location.path)
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> AcceptancePage {
    AcceptancePage(name: "route-error", detail: context.routeContext.path)
  }
}

/// The path host's home page. It reads the host's route set by the host's string key and the
/// alpha feature's route set by its type, in one environment where all three are named `Routes`.
@View
struct HostHomePage {
  @Environment(Routes._routeSetEnvironmentKey) var routes
  @Environment(GuideAlpha.Routes<Routes.RouteView>.RouteSet.self)
  var alpha: GuideAlpha.Routes<Routes.RouteView>.RouteSet?

  var body: some View {
    article(.id("page"), .data("page", value: "home")) {
      h1 { "home" }
      if let routes {
        span(.id("host-link-alpha")) {
          Routes.Link(to: routes.alpha.items()) { "Alpha items" }
        }
        span(.id("host-link-beta")) {
          Routes.Link(to: routes.beta.items()) { "Beta items" }
        }
      }
      if let alpha {
        span(.id("feature-link-alpha")) {
          RouteLink(to: alpha.index()) { "Alpha" }
        }
      }
    }
  }
}
