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

              func router() -> Router<RouteView> {
                Router(routes: tree)
              }

              func userHref(id: Int, tab: String? = nil, hash: String = "") throws(RouteMatchError) -> String {
              let params: RouteValues = ["id": RouteValues.ValueLiteral(id)]
                var query = RouteValues()
                if let tab {
                query = query.set("tab", tab)
              }
              return try tree._href(to: handles.user, params: params, query: query, hash: hash)
            }
            }

          static let _routerEnvironmentKey = EnvironmentValues._Key<Router<RouteView>?>(
              "ElementaryRouter.AppRoutes.router",
              defaultValue: nil
            )

          @View
            struct Provider<Content: View> {
              let router: Router<RouteView>
              let content: Content

              init(_ router: Router<RouteView>, @HTMLBuilder content: () -> Content) {
                self.router = router
                self.content = content()
              }

              var body: some View {
                content.environment(AppRoutes._routerEnvironmentKey, router)
              }
            }

          @View
            struct Link<Content: View> {
              @Environment(AppRoutes._routerEnvironmentKey) var router

              let route: RouteHandle
              let params: RouteValues
              let query: RouteValues
              let hash: String
              let replace: Bool
              let target: HTMLAttributeValue.Target?
              let content: Content

              init(
                to route: RouteHandle,
                params: RouteValues = RouteValues(),
                query: RouteValues = RouteValues(),
                hash: String = "",
                replace: Bool = false,
                target: HTMLAttributeValue.Target? = nil,
                @HTMLBuilder content: () -> Content
              ) {
                self.route = route
                self.params = params
                self.query = query
                self.hash = hash
                self.replace = replace
                self.target = target
                self.content = content()
              }

              var body: some View {
                if let target {
                  a(.href(href), .target(target), .data("router-link", value: "true")) {
                    content
                  }
                  .onClick { event in
                    handleClick(event)
                  }
                } else {
                  a(.href(href), .data("router-link", value: "true")) {
                    content
                  }
                  .onClick { event in
                    handleClick(event)
                  }
                }
              }

              private func handleClick(_ event: MouseEvent) {
                guard
                  event.button == 0,
                  !event.altKey,
                  !event.ctrlKey,
                  !event.metaKey,
                  !event.shiftKey,
                  target == nil || target?.rawValue == "" || target?.rawValue == "_self"
                else {
                  return
                }

                try? router?.navigate(
                  to: route,
                  params: params,
                  query: query,
                  hash: hash,
                  replace: replace
                )
              }

              private var href: String {
                (try? router?.href(to: route, params: params, query: query, hash: hash)) ?? "#"
              }
            }

          static func routes() throws(RouteTreeError) -> RouteSet {
              let collection = RouteBuilder<RouteView>()

                  let user = collection._route("/users/:id", parent: nil) { context throws(RouteValueError) in
                RouteView(storage: .user(id: try context.params.require("id", Int.self), tab: context.query.get("tab", String.self) ?? "overview"))
              }

              return RouteSet(
                tree: try collection._build(),
                handles: Handles(user: user)
              )
            }

            static func router() throws(RouteTreeError) -> Router<RouteView> {
              try routes().router()
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

              func router() -> Router<RouteView> {
                Router(routes: tree)
              }

              func validHref(hash: String = "") throws(RouteMatchError) -> String {
              let params = RouteValues()
              let query = RouteValues()
              return try tree._href(to: handles.valid, params: params, query: query, hash: hash)
            }
            }

          static let _routerEnvironmentKey = EnvironmentValues._Key<Router<RouteView>?>(
              "ElementaryRouter.AppRoutes.router",
              defaultValue: nil
            )

          @View
            struct Provider<Content: View> {
              let router: Router<RouteView>
              let content: Content

              init(_ router: Router<RouteView>, @HTMLBuilder content: () -> Content) {
                self.router = router
                self.content = content()
              }

              var body: some View {
                content.environment(AppRoutes._routerEnvironmentKey, router)
              }
            }

          @View
            struct Link<Content: View> {
              @Environment(AppRoutes._routerEnvironmentKey) var router

              let route: RouteHandle
              let params: RouteValues
              let query: RouteValues
              let hash: String
              let replace: Bool
              let target: HTMLAttributeValue.Target?
              let content: Content

              init(
                to route: RouteHandle,
                params: RouteValues = RouteValues(),
                query: RouteValues = RouteValues(),
                hash: String = "",
                replace: Bool = false,
                target: HTMLAttributeValue.Target? = nil,
                @HTMLBuilder content: () -> Content
              ) {
                self.route = route
                self.params = params
                self.query = query
                self.hash = hash
                self.replace = replace
                self.target = target
                self.content = content()
              }

              var body: some View {
                if let target {
                  a(.href(href), .target(target), .data("router-link", value: "true")) {
                    content
                  }
                  .onClick { event in
                    handleClick(event)
                  }
                } else {
                  a(.href(href), .data("router-link", value: "true")) {
                    content
                  }
                  .onClick { event in
                    handleClick(event)
                  }
                }
              }

              private func handleClick(_ event: MouseEvent) {
                guard
                  event.button == 0,
                  !event.altKey,
                  !event.ctrlKey,
                  !event.metaKey,
                  !event.shiftKey,
                  target == nil || target?.rawValue == "" || target?.rawValue == "_self"
                else {
                  return
                }

                try? router?.navigate(
                  to: route,
                  params: params,
                  query: query,
                  hash: hash,
                  replace: replace
                )
              }

              private var href: String {
                (try? router?.href(to: route, params: params, query: query, hash: hash)) ?? "#"
              }
            }

          static func routes() throws(RouteTreeError) -> RouteSet {
              let collection = RouteBuilder<RouteView>()

                  let valid = collection._route("/valid", parent: nil) {
                RouteView(storage: .valid)
              }

              return RouteSet(
                tree: try collection._build(),
                handles: Handles(valid: valid)
              )
            }

            static func router() throws(RouteTreeError) -> Router<RouteView> {
              try routes().router()
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

              func router() -> Router<RouteView> {
                Router(routes: tree)
              }

              func userHref(hash: String = "") throws(RouteMatchError) -> String {
              let params = RouteValues()
              let query = RouteValues()
              return try tree._href(to: handles.user, params: params, query: query, hash: hash)
            }
            }

          static let _routerEnvironmentKey = EnvironmentValues._Key<Router<RouteView>?>(
              "ElementaryRouter.AppRoutes.router",
              defaultValue: nil
            )

          @View
            struct Provider<Content: View> {
              let router: Router<RouteView>
              let content: Content

              init(_ router: Router<RouteView>, @HTMLBuilder content: () -> Content) {
                self.router = router
                self.content = content()
              }

              var body: some View {
                content.environment(AppRoutes._routerEnvironmentKey, router)
              }
            }

          @View
            struct Link<Content: View> {
              @Environment(AppRoutes._routerEnvironmentKey) var router

              let route: RouteHandle
              let params: RouteValues
              let query: RouteValues
              let hash: String
              let replace: Bool
              let target: HTMLAttributeValue.Target?
              let content: Content

              init(
                to route: RouteHandle,
                params: RouteValues = RouteValues(),
                query: RouteValues = RouteValues(),
                hash: String = "",
                replace: Bool = false,
                target: HTMLAttributeValue.Target? = nil,
                @HTMLBuilder content: () -> Content
              ) {
                self.route = route
                self.params = params
                self.query = query
                self.hash = hash
                self.replace = replace
                self.target = target
                self.content = content()
              }

              var body: some View {
                if let target {
                  a(.href(href), .target(target), .data("router-link", value: "true")) {
                    content
                  }
                  .onClick { event in
                    handleClick(event)
                  }
                } else {
                  a(.href(href), .data("router-link", value: "true")) {
                    content
                  }
                  .onClick { event in
                    handleClick(event)
                  }
                }
              }

              private func handleClick(_ event: MouseEvent) {
                guard
                  event.button == 0,
                  !event.altKey,
                  !event.ctrlKey,
                  !event.metaKey,
                  !event.shiftKey,
                  target == nil || target?.rawValue == "" || target?.rawValue == "_self"
                else {
                  return
                }

                try? router?.navigate(
                  to: route,
                  params: params,
                  query: query,
                  hash: hash,
                  replace: replace
                )
              }

              private var href: String {
                (try? router?.href(to: route, params: params, query: query, hash: hash)) ?? "#"
              }
            }

          static func routes() throws(RouteTreeError) -> RouteSet {
              let collection = RouteBuilder<RouteView>()

                  let user = collection._route("/users/:id", parent: nil) {
                RouteView(storage: .user)
              }

              return RouteSet(
                tree: try collection._build(),
                handles: Handles(user: user)
              )
            }

            static func router() throws(RouteTreeError) -> Router<RouteView> {
              try routes().router()
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

              func router() -> HashRouter<RouteView> {
                HashRouter(routes: tree)
              }

              func docsHref(splat: String, hash: String = "") throws(RouteMatchError) -> String {
              let params: RouteValues = ["*": RouteValues.ValueLiteral(splat)]
              let query = RouteValues()
              return try tree._href(to: handles.docs, params: params, query: query, hash: hash)
            }
            }

          static let _routerEnvironmentKey = EnvironmentValues._Key<HashRouter<RouteView>?>(
              "ElementaryRouter.DocsRoutes.router",
              defaultValue: nil
            )

          @View
            struct Provider<Content: View> {
              let router: HashRouter<RouteView>
              let content: Content

              init(_ router: HashRouter<RouteView>, @HTMLBuilder content: () -> Content) {
                self.router = router
                self.content = content()
              }

              var body: some View {
                content.environment(DocsRoutes._routerEnvironmentKey, router)
              }
            }

          @View
            struct Link<Content: View> {
              @Environment(DocsRoutes._routerEnvironmentKey) var router

              let route: RouteHandle
              let params: RouteValues
              let query: RouteValues
              let hash: String
              let replace: Bool
              let target: HTMLAttributeValue.Target?
              let content: Content

              init(
                to route: RouteHandle,
                params: RouteValues = RouteValues(),
                query: RouteValues = RouteValues(),
                hash: String = "",
                replace: Bool = false,
                target: HTMLAttributeValue.Target? = nil,
                @HTMLBuilder content: () -> Content
              ) {
                self.route = route
                self.params = params
                self.query = query
                self.hash = hash
                self.replace = replace
                self.target = target
                self.content = content()
              }

              var body: some View {
                if let target {
                  a(.href(href), .target(target), .data("router-link", value: "true")) {
                    content
                  }
                  .onClick { event in
                    handleClick(event)
                  }
                } else {
                  a(.href(href), .data("router-link", value: "true")) {
                    content
                  }
                  .onClick { event in
                    handleClick(event)
                  }
                }
              }

              private func handleClick(_ event: MouseEvent) {
                guard
                  event.button == 0,
                  !event.altKey,
                  !event.ctrlKey,
                  !event.metaKey,
                  !event.shiftKey,
                  target == nil || target?.rawValue == "" || target?.rawValue == "_self"
                else {
                  return
                }

                try? router?.navigate(
                  to: route,
                  params: params,
                  query: query,
                  hash: hash,
                  replace: replace
                )
              }

              private var href: String {
                (try? router?.href(to: route, params: params, query: query, hash: hash)) ?? "#"
              }
            }

          static func routes() throws(RouteTreeError) -> RouteSet {
              let collection = RouteBuilder<RouteView>()

                  let docs = collection._route("/docs/*", parent: nil) { context throws(RouteValueError) in
                RouteView(storage: .docs(splat: try context.params.require("*", String.self)))
              }

              return RouteSet(
                tree: try collection._build(),
                handles: Handles(docs: docs)
              )
            }

            static func router() throws(RouteTreeError) -> HashRouter<RouteView> {
              try routes().router()
            }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }
}
