import ElementaryRouter
import ElementaryUI

@main
struct App {
  static func main() throws(RouteTreeError) {
    let routeSet = try AppRoutes.routes()
    let router = routeSet.router()
    let app = Application(ContentView(routeSet: routeSet, router: router))
    app.mount(in: .body)
  }
}
