import ElementaryUI
import ElementaryUIRouter

final class ExampleRoutes {
    private let collection = RouteCollection()

    let home: RouteHandle
    let profile: RouteHandle
    let docs: RouteHandle

    init() {
        home = collection.route("/") {
            HomePage()
        }

        profile = collection.route("/:lang/profile/:profileId") { context throws(RouteValueError) in
            ProfilePage(
                lang: try context.params.require("lang"),
                profileID: try context.params.require("profileId", Int.self),
                tab: context.query.get("tab") ?? "overview"
            )
        }

        docs = collection.route("/docs/*") { context in
            DocsPage(slug: context.params.get("*") ?? "")
        }

        collection.notFound { context in
            NotFoundPage(path: context.location.path)
        }

        collection.error { context in
            InvalidRoutePage(error: context.error)
        }
    }

    func freeze() throws(RouteTreeError) -> RouteTree {
        try collection.freeze()
    }
}

@View
struct ContentView {
    let routes: ExampleRoutes
    let router: Router

    var body: some View {
        RouterProvider(router) {
            div(.style(pageStyle)) {
                header(.style(headerStyle)) {
                    h1(.style(titleStyle)) { "ElementaryUI Router" }
                    nav(.style(navStyle)) {
                        Link(to: routes.home) {
                            "Home"
                        }
                        Link(
                            to: routes.profile,
                            params: ["lang": "ja", "profileId": 42],
                            query: ["tab": "posts"]
                        ) {
                            "Profile"
                        }
                        Link(
                            to: routes.docs,
                            params: ["*": "guide/get-started"],
                            hash: "install"
                        ) {
                            "Docs"
                        }
                    }
                }

                main(.style(mainStyle)) {
                    RouterView()
                }
            }
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
    let tab: String

    var body: some View {
        section(.style(panelStyle)) {
            h2(.style(headingStyle)) { "Profile" }
            dl(.style(detailsStyle)) {
                dt { "lang" }
                dd { lang }
                dt { "profileId" }
                dd { "\(profileID)" }
                dt { "tab" }
                dd { tab }
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
        case let .missing(name):
            "Missing route value: \(name)."
        case let .invalid(name, rawValue, expected):
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
