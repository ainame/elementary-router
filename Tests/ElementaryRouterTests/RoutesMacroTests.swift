import ElementaryRouterMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

private let testMacros: [String: Macro.Type] = [
  "Routes": RoutesMacro.self,
  "Route": RouteMacro.self,
  "Layout": LayoutMacro.self,
  "NotFound": NotFoundMacro.self,
  "RouteError": RouteErrorMacro.self,
]

final class RoutesMacroTests: XCTestCase {
  func testRoutesMacroExpansionGeneratesTypedRouteSet() {
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
              let params: RouteParameters = ["id": RouteValueLiteral(id)]
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

            static func router() throws(RouteTreeError) -> Router<RouteView> {
              let routeSet = try routes()
              let tree = routeSet.tree
              return Router(routes: tree)
            }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  func testRouteMarkerMacrosRequireStaticFunctions() {
    assertMacroExpansion(
      """
      @Routes
      struct AppRoutes {
        @Route("/valid")
        static func valid() -> ValidPage {
          ValidPage()
        }

        @Route("/users/:id")
        func user(id: Int) -> UserPage {
          UserPage()
        }

        @Layout("/admin")
        func adminLayout<Content: View>(outlet: Outlet<Content>) -> AdminLayout<Content> {
          AdminLayout(outlet: outlet)
        }

        @NotFound
        func notFound(context: RouteNotFoundContext) -> NotFoundPage {
          NotFoundPage()
        }

        @RouteError
        func routeError(context: RouteErrorContext) -> ErrorPage {
          ErrorPage()
        }
      }
      """,
      expandedSource:
        """
        struct AppRoutes {
          static func valid() -> ValidPage {
            ValidPage()
          }
          func user(id: Int) -> UserPage {
            UserPage()
          }
          func adminLayout<Content: View>(outlet: Outlet<Content>) -> AdminLayout<Content> {
            AdminLayout(outlet: outlet)
          }
          func notFound(context: RouteNotFoundContext) -> NotFoundPage {
            NotFoundPage()
          }
          func routeError(context: RouteErrorContext) -> ErrorPage {
            ErrorPage()
          }

          @View
            struct RouteView {
              enum Storage {
                case valid
              }

              let storage: Storage

              init(storage: Storage) {
                self.storage = storage
              }

              var body: some View {
                switch storage {
                      case .valid:
                  AppRoutes.valid()
                }
              }
            }

          struct Handles {
              let valid: RouteHandle

              init(valid: RouteHandle) {
                self.valid = valid
              }
            }

          struct RouteSet {
              let tree: RouteTree<RouteView>
              let handles: Handles

              init(tree: RouteTree<RouteView>, handles: Handles) {
                self.tree = tree
                self.handles = handles
              }

              func validHref(hash: String = "") throws(RouteMatchError) -> String {
              let params = RouteParameters()
              let query = RouteParameters()
              return try tree.href(to: handles.valid, params: params, query: query, hash: hash)
            }
            }

          static func routes() throws(RouteTreeError) -> RouteSet {
              let collection = RouteCollection<RouteView>()

                  let valid = collection.route("/valid") {
                RouteView(storage: .valid)
              }

              return RouteSet(
                tree: try collection.freeze(),
                handles: Handles(valid: valid)
              )
            }

            static func router() throws(RouteTreeError) -> Router<RouteView> {
              let routeSet = try routes()
              let tree = routeSet.tree
              return Router(routes: tree)
            }
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "`@Route` can only be attached to a static function.",
          line: 8,
          column: 3
        ),
        DiagnosticSpec(
          message: "`@Layout` can only be attached to a static function.",
          line: 13,
          column: 3
        ),
        DiagnosticSpec(
          message: "`@NotFound` can only be attached to a static function.",
          line: 18,
          column: 3
        ),
        DiagnosticSpec(
          message: "`@RouteError` can only be attached to a static function.",
          line: 23,
          column: 3
        ),
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  func testRoutesMacroExpansionReportsMissingPathParameter() {
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

            static func router() throws(RouteTreeError) -> Router<RouteView> {
              let routeSet = try routes()
              let tree = routeSet.tree
              return Router(routes: tree)
            }
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Missing function parameter for path parameter `id`.",
          line: 3,
          column: 3
        )
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  func testRoutesMacroExpansionSupportsHashMode() {
    assertMacroExpansion(
      """
      @Routes(mode: .hash)
      struct DocsRoutes {
        @Route("/docs/*")
        static func docs(splat: Wildcard) -> DocsPage {
          DocsPage(slug: splat.value)
        }
      }
      """,
      expandedSource:
        """
        struct DocsRoutes {
          static func docs(splat: Wildcard) -> DocsPage {
            DocsPage(slug: splat.value)
          }

          @View
            struct RouteView {
              enum Storage {
                case docs(splat: String)
              }

              let storage: Storage

              init(storage: Storage) {
                self.storage = storage
              }

              var body: some View {
                switch storage {
                      case .docs(let splat):
                  DocsRoutes.docs(splat: Wildcard(splat))
                }
              }
            }

          struct Handles {
              let docs: RouteHandle

              init(docs: RouteHandle) {
                self.docs = docs
              }
            }

          struct RouteSet {
              let tree: RouteTree<RouteView>
              let handles: Handles

              init(tree: RouteTree<RouteView>, handles: Handles) {
                self.tree = tree
                self.handles = handles
              }

              func docsHref(splat: String, hash: String = "") throws(RouteMatchError) -> String {
              let params: RouteParameters = ["*": RouteValueLiteral(splat)]
              let query = RouteParameters()
              return try tree.href(to: handles.docs, params: params, query: query, hash: hash)
            }
            }

          static func routes() throws(RouteTreeError) -> RouteSet {
              let collection = RouteCollection<RouteView>()

                  let docs = collection.route("/docs/*") { context throws(RouteValueError) in
                RouteView(storage: .docs(splat: try context.params.require("*", String.self)))
              }

              return RouteSet(
                tree: try collection.freeze(),
                handles: Handles(docs: docs)
              )
            }

            static func router() throws(RouteTreeError) -> HashRouter<RouteView> {
              let routeSet = try routes()
              let tree = routeSet.tree
              return HashRouter(routes: tree)
            }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }
}
