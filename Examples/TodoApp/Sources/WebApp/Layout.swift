import ElementaryRouter
import ElementaryUI

@View
struct FilterLink {
  let title: String
  let route: RouteHandle

  var body: some View {
    Link(to: route) {
      title
    }
  }
}
