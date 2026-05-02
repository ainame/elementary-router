import ElementaryRouter
import ElementaryUI

@Routes
struct AppRoutes {
  @Layout("/:lang")
  static func languageLayout<Content: View>(
    lang: String,
    outlet: Outlet<Content>
  ) -> LanguageLayout<Content> {
    LanguageLayout(lang: lang, outlet: outlet)
  }

  @Route("/")
  static func home() -> HomePage {
    HomePage()
  }

  @Route("/:lang/profile/:profileId")
  static func profile(lang: String, profileId: Int) -> ProfilePage {
    ProfilePage(lang: lang, profileID: profileId)
  }

  @Route("/docs/*")
  static func docs(splat: Wildcard) -> DocsPage {
    DocsPage(slug: splat.value)
  }

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> NotFoundPage {
    NotFoundPage(path: context.location.path)
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> InvalidRoutePage {
    InvalidRoutePage(error: context.error)
  }
}

@View
struct ContentView {
  let routeSet: AppRoutes.RouteSet
  let router: Router<AppRoutes.RouteView>

  var body: some View {
    RouterProvider(router) {
      div(.style(pageStyle)) {
        header(.style(headerStyle)) {
          h1(.style(titleStyle)) { "ElementaryUI Router" }
          nav(.style(navStyle)) {
            Link(to: routeSet.handles.home) {
              "Home"
            }
            Link(
              to: routeSet.handles.profile,
              params: ["lang": "ja", "profileId": 42]
            ) {
              "Profile"
            }
            Link(
              to: routeSet.handles.docs,
              params: ["*": "guide/get-started"],
              hash: "install"
            ) {
              "Docs"
            }
          }
        }

        main(.style(mainStyle)) {
          RouterView(router) { _ in
            AppRoutes.RouteView(
              storage: .notFound(
                RouteNotFoundContext(location: router.location, query: RouteParameters())
              )
            )
          }
        }
      }
    }
  }
}

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

let pageStyle = [
  "box-sizing": "border-box",
  "min-height": "100vh",
  "padding": "32px",
  "background": "#f7f8fa",
  "color": "#17202a",
  "font-family": "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
]

let headerStyle = [
  "display": "flex",
  "align-items": "center",
  "justify-content": "space-between",
  "gap": "24px",
  "max-width": "960px",
  "margin": "0 auto 24px",
]

let titleStyle = [
  "margin": "0",
  "font-size": "28px",
  "font-weight": "700",
]

let navStyle = [
  "display": "flex",
  "gap": "12px",
]

let mainStyle = [
  "max-width": "960px",
  "margin": "0 auto",
]

let panelStyle = [
  "box-sizing": "border-box",
  "padding": "24px",
  "border": "1px solid #d8dee8",
  "border-radius": "8px",
  "background": "#ffffff",
  "box-shadow": "0 8px 24px rgba(19, 32, 53, 0.08)",
]

let headingStyle = [
  "margin": "0 0 12px",
  "font-size": "22px",
]

let textStyle = [
  "margin": "0",
  "line-height": "1.6",
]

let detailsStyle = [
  "display": "grid",
  "grid-template-columns": "120px 1fr",
  "gap": "8px 16px",
  "margin": "0",
]

let layoutStyle = [
  "display": "grid",
  "gap": "12px",
]
