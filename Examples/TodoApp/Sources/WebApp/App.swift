import ElementaryRouter
import ElementaryUI

@main
struct App {
  static func main() throws(RouteTreeError) {
    let routes = try AppRoutes.routes()
    let router = try AppRoutes.router()
    let app = Application(
      AppRoutes.Provider(router) {
        ContentView(routes: routes, router: router)
      }
    )
    app.mount(in: .body)
  }
}
