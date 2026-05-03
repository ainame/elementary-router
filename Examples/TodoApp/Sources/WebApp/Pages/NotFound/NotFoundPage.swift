import ElementaryUI

@View
struct NotFoundPage {
  let path: String

  var body: some View {
    NotFoundPanel(title: "Page not found", message: "No route matched \(path).")
  }
}
