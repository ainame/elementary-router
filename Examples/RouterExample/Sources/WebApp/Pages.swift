import ElementaryRouter
import ElementaryUI

@View
struct LanguageLayout<Content: View> {
  let lang: String
  let outlet: Outlet<Content>

  var body: some View {
    div(.style(layoutStyle)) {
      p(.style(textStyle)) {
        "Language: \(lang)"
      }
      outlet
    }
  }
}

@View
struct HomePage {
  var body: some View {
    section(.style(panelStyle)) {
      h2(.style(headingStyle)) { "Home" }
      p(.style(textStyle)) {
        "This page is matched by the index route."
      }
    }
  }
}

@View
struct ProfilePage {
  let lang: String
  let profileID: Int

  var body: some View {
    section(.style(panelStyle)) {
      h2(.style(headingStyle)) { "Profile" }
      dl(.style(detailsStyle)) {
        dt { "lang" }
        dd { lang }
        dt { "profileId" }
        dd { "\(profileID)" }
      }
    }
  }
}

@View
struct DocsPage {
  let slug: String

  var body: some View {
    section(.style(panelStyle)) {
      h2(.style(headingStyle)) { "Docs" }
      p(.style(textStyle)) {
        slug.isEmpty ? "Wildcard route matched." : "Wildcard route matched: \(slug)"
      }
    }
  }
}

@View
struct InvalidRoutePage {
  let error: RouteValueError

  var body: some View {
    section(.style(panelStyle)) {
      h2(.style(headingStyle)) { "Invalid Route" }
      p(.style(textStyle)) {
        message
      }
    }
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

@View
struct NotFoundPage {
  let path: String

  var body: some View {
    section(.style(panelStyle)) {
      h2(.style(headingStyle)) { "Not Found" }
      p(.style(textStyle)) {
        "No route matched \(path)."
      }
    }
  }
}
