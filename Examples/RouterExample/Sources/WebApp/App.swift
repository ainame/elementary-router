import ElementaryRouter
import ElementaryUI

@main
struct App {
  static func main() throws(RouteTreeError) {
    let routes = try AppRoutes.routes()
    let router = try AppRoutes.router()
    let routeContent = RouterView(router) { _ in
      AppRoutes.RouteView(
        storage: .notFound(
          RouteNotFoundContext(location: router.location, query: RouteValues())
        )
      )
    }
    let app = Application(
      AppRoutes.Provider(router) {
        ContentView(routes: routes, routeContent: routeContent)
      }
    )
    app.mount(in: .body)
  }
}
