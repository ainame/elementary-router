import ElementaryRouter
import ElementaryUI

@View
struct ContentView<Content: View> {
  @Environment(AppRoutes._routeSetEnvironmentKey) var routes
  @Environment(AppRoutes._routerEnvironmentKey) var router

  let outlet: Outlet<Content>

  var body: some View {
    div(.style(pageStyle)) {
      header(.style(headerStyle)) {
        h1(.style(titleStyle)) { "ElementaryUI Router" }
        // This layout renders below `AppRoutes.RouterView`, which provides both values. Without a
        // provider there is no route set to build destinations from, so no navigation is shown.
        if let routes, let router {
          AppNavigation(routes: routes, router: router)
        }
      }

      main(.style(mainStyle)) {
        outlet
      }
    }
  }
}

@View
struct AppNavigation {
  @State var navigationError: String? = nil

  let routes: AppRoutes.RouteSet
  let router: Router<AppRoutes.RouteView>

  var body: some View {
    let home = routes.home()

    nav(.style(navStyle)) {
      span(.style(linkStyle(isActive: router.isActive(home)))) {
        AppRoutes.Link(to: home) {
          "Home"
        }
      }

      // Destinations with path values can fail to build, so the failure is rendered explicitly.
      switch profileDestination {
      case .success(let profile):
        span(.style(linkStyle(isActive: router.isActive(profile, includeQuery: false)))) {
          AppRoutes.Link(to: profile) {
            "Profile"
          }
        }
      case .failure:
        span(.style(errorTextStyle)) { "Profile link unavailable" }
      }

      switch docsDestination {
      case .success(let docs):
        span(.style(linkStyle(isActive: router.isActive(docs)))) {
          AppRoutes.Link(to: docs) {
            "Docs"
          }
        }
      case .failure:
        span(.style(errorTextStyle)) { "Docs link unavailable" }
      }

      button(.type(.button)) {
        "Open profile 7"
      }
      .onClick {
        openProfile(id: 7)
      }

      if let navigationError {
        span(.style(errorTextStyle)) { navigationError }
      }
    }
  }

  private var profileDestination: Result<RouteDestination<AppRoutes.RouteView>, RouteMatchError> {
    Result { () throws(RouteMatchError) in
      try routes.profile(lang: "ja", profileId: 42, tab: "posts")
    }
  }

  private var docsDestination: Result<RouteDestination<AppRoutes.RouteView>, RouteMatchError> {
    Result { () throws(RouteMatchError) in
      try routes.docs(splat: "guide/get-started", hash: "install")
    }
  }

  /// Programmatic navigation uses the same typed destination as links.
  private func openProfile(id: Int) {
    do throws(RouteMatchError) {
      try router.navigate(to: routes.profile(lang: "en", profileId: id))
      navigationError = nil
    } catch {
      navigationError = "Could not open profile \(id)."
    }
  }
}
