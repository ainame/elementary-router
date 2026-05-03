import ElementaryRouter
import ElementaryUI

@View
struct InvalidRoutePage {
  let error: RouteValueError

  var body: some View {
    NotFoundPanel(title: "Invalid route", message: message)
  }

  private var message: String {
    switch error {
    case .missing(let name):
      "Missing route value: \(name)."
    case .invalid(let name, let rawValue, let expected):
      "Invalid route value \(name)=\(rawValue). Expected \(expected)."
    }
  }
}
