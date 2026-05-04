import ElementaryRouter
import ElementaryUI

@main
struct App {
  static func main() {
    let app = Application(AppRoutes.RouterView())
    app.mount(in: .body)
  }
}
