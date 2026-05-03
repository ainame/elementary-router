import ElementaryRouter
import ElementaryUI

@main
struct App {
  static func main() throws(RouteTreeError) {
    let routeSet = try AppRoutes.routes()
    let router = try AppRoutes.router()
    let app = Application(ContentView(routeSet: routeSet, router: router))
    app.mount(in: .body)
  }
}
