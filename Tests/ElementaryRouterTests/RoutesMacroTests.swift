import ElementaryRouterMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

private let testMacros: [String: Macro.Type] = [
  "Routes": RoutesMacro.self,
  "Route": RouteMacro.self,
  "NotFound": NotFoundMacro.self,
  "RouteError": RouteErrorMacro.self,
]

@Test func routesMacroExpansionGeneratesTypedRouteSet() {
  assertMacroExpansion(
    """
    @Routes
    struct AppRoutes {
      @Route("/users/:id")
      static func user(id: Int, tab: Query<String> = Query("overview")) -> UserPage {
        UserPage(id: id, tab: tab.value)
      }
    }
    """,
    expandedSource:
      """
      struct AppRoutes {
        @Route("/users/:id")
        static func user(id: Int, tab: Query<String> = Query("overview")) -> UserPage {
          UserPage(id: id, tab: tab.value)
        }

        @View
        struct RouteView {
          enum Storage {
            case user(id: Int, tab: String)
          }

          let storage: Storage

          init(storage: Storage) {
            self.storage = storage
          }

          var body: some View {
            switch storage {
            case .user(let id, let tab):
              AppRoutes.user(id: id, tab: Query(tab))
            }
          }
        }

        struct Handles {
          let user: RouteHandle

          init(user: RouteHandle) {
            self.user = user
          }
        }

        struct RouteSet {
          let tree: RouteTree<RouteView>
          let handles: Handles

          init(tree: RouteTree<RouteView>, handles: Handles) {
            self.tree = tree
            self.handles = handles
          }

          func userHref(id: Int, tab: String? = nil, hash: String = "") throws(RouteMatchError) -> String {
            let params = RouteParameters(("id", RouteValueLiteral(id)))
            var query = RouteParameters()
            if let tab {
              query = query.set("tab", tab)
            }
            return try tree.href(to: handles.user, params: params, query: query, hash: hash)
          }
        }

        static func routes() throws(RouteTreeError) -> RouteSet {
          let collection = RouteCollection<RouteView>()
          let user = collection.route("/users/:id") { context throws(RouteValueError) in
            RouteView(storage: .user(id: try context.params.require("id", Int.self), tab: context.query.get("tab", String.self) ?? "overview"))
          }

          return RouteSet(
            tree: try collection.freeze(),
            handles: Handles(user: user)
          )
        }
      }
      """,
    macros: testMacros,
    indentationWidth: .spaces(2)
  )
}

@Test func routesMacroExpansionReportsMissingPathParameter() {
  assertMacroExpansion(
    """
    @Routes
    struct AppRoutes {
      @Route("/users/:id")
      static func user() -> UserPage {
        UserPage()
      }
    }
    """,
    expandedSource:
      """
      struct AppRoutes {
        @Route("/users/:id")
        static func user() -> UserPage {
          UserPage()
        }

        @View
        struct RouteView {
          enum Storage {
            case user
          }

          let storage: Storage

          init(storage: Storage) {
            self.storage = storage
          }

          var body: some View {
            switch storage {
            case .user:
              AppRoutes.user()
            }
          }
        }

        struct Handles {
          let user: RouteHandle

          init(user: RouteHandle) {
            self.user = user
          }
        }

        struct RouteSet {
          let tree: RouteTree<RouteView>
          let handles: Handles

          init(tree: RouteTree<RouteView>, handles: Handles) {
            self.tree = tree
            self.handles = handles
          }

          func userHref(hash: String = "") throws(RouteMatchError) -> String {
            let params = RouteParameters()
            let query = RouteParameters()
            return try tree.href(to: handles.user, params: params, query: query, hash: hash)
          }
        }

        static func routes() throws(RouteTreeError) -> RouteSet {
          let collection = RouteCollection<RouteView>()
          let user = collection.route("/users/:id") {
            RouteView(storage: .user)
          }

          return RouteSet(
            tree: try collection.freeze(),
            handles: Handles(user: user)
          )
        }
      }
      """,
    diagnostics: [
      DiagnosticSpec(
        message: "Missing function parameter for path parameter `id`.",
        line: 4,
        column: 3
      )
    ],
    macros: testMacros,
    indentationWidth: .spaces(2)
  )
}
