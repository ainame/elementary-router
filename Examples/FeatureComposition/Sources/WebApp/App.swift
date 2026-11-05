import Blog
import ElementaryRouter
import ElementaryUI
import Shop

@main
struct App {
  static func main() {
    let app = Application(AppRoutes.RouterView())
    app.mount(in: .body)
  }
}

/// The host chrome. It stays mounted across the home page, the shop, and the blog.
@View
struct AppShell<Content: View> {
  @Environment(AppRoutes._routeSetEnvironmentKey) var routes
  @Environment(AppRoutes._routerEnvironmentKey) var router

  let outlet: Outlet<Content>

  var body: some View {
    div(.id("app-shell")) {
      header {
        h1 { "Feature composition" }
        if let routes, let router {
          nav {
            span(.id("link-home")) {
              AppRoutes.Link(to: routes.home()) { "Home" }
            }
            // Mounted destinations are host destinations, so the host's own link accepts them.
            span(.id("link-shop"), .data("active", value: "\(router.isActive(routes.handles.shop, options: .descendant))")) {
              AppRoutes.Link(to: routes.shop.catalog()) { "Shop" }
            }
            span(.id("link-blog"), .data("active", value: "\(router.isActive(routes.handles.blog, options: .descendant))")) {
              AppRoutes.Link(to: routes.blog.posts()) { "Blog" }
            }
          }
        }
      }
      main {
        outlet
      }
    }
  }
}

@View
struct HomePage {
  var body: some View {
    article(.id("page"), .data("page", value: "home")) {
      p { "The shop and blog are separate modules mounted into this app's route tree." }
    }
  }
}

@View
struct MessagePage {
  let name: String
  let message: String

  var body: some View {
    article(.id("page"), .data("page", value: name)) {
      p { message }
    }
  }
}
