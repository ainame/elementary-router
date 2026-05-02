import ElementaryUI
import ElementaryUIRouter

@main
struct App {
  static func main() throws(RouteTreeError) {
    let routes = ExampleRoutes()
    let router = Router(routes: try routes.freeze(), history: .browser())
    let app = Application(ContentView(routes: routes, router: router))
    app.mount(in: .body)
  }
}
