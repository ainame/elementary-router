import ElementaryRouter
import ElementaryUI

@main
struct App {
  static func main() throws(RouteTreeError) {
    let routes = try AppRoutes.routes()
    let router = try AppRoutes.router()
    let app = Application(
      AppRoutes.Provider(router) {
        AppRoutes.RouterView { routeContent in
          AppLayout(routes: routes, routeContent: routeContent)
        }
      }
    )
    app.mount(in: .body)
  }
}
