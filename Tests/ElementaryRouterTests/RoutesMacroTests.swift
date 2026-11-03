import ElementaryRouterMacros
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
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

          static let _routeSetEnvironmentKey = EnvironmentValues._Key<RouteSet?>(
              "ElementaryRouter.AppRoutes.routes",
              defaultValue: nil
            )

          @View
            struct Provider<Content: View> {
              let routes: RouteSet
              let router: Router<RouteView>
              let content: Content

              init(_ routes: RouteSet, router: Router<RouteView>, @HTMLBuilder content: () -> Content) {
                precondition(
                  router._uses(routes.tree),
                  "AppRoutes.Provider requires a router created by the same RouteSet."
                )
                self.routes = routes
                self.router = router
                self.content = content()
              }

              var body: some View {
                content.environment(AppRoutes._routerEnvironmentKey, router)
                  .environment(AppRoutes._routeSetEnvironmentKey, routes)
              }
            }

          @View
            struct RouterView {
              let routes: RouteSet
              let router: Router<RouteView>

              init() {
                do throws(RouteTreeError) {
                  let routes = try AppRoutes.routes()
                  self.routes = routes
                  self.router = routes.router()
                } catch {
                  preconditionFailure("AppRoutes.RouterView could not build routes.")
                }
              }

              init(_ routes: RouteSet, router: Router<RouteView>) {
                precondition(
                  router._uses(routes.tree),
                  "AppRoutes.RouterView requires a router created by the same RouteSet."
                )
                self.routes = routes
                self.router = router
              }

              var body: some View {
                Provider(routes, router: router) {
                  rendered
                }
              }

              private var rendered: RouteView {
                do {
                  return try router.renderCurrentRoute()
                } catch {
                  preconditionFailure("AppRoutes.RouterView could not render the current route.")
                }
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

          static let _routeSetEnvironmentKey = EnvironmentValues._Key<RouteSet?>(
              "ElementaryRouter.AppRoutes.routes",
              defaultValue: nil
            )

          @View
            struct Provider<Content: View> {
              let routes: RouteSet
              let router: Router<RouteView>
              let content: Content

              init(_ routes: RouteSet, router: Router<RouteView>, @HTMLBuilder content: () -> Content) {
                precondition(
                  router._uses(routes.tree),
                  "AppRoutes.Provider requires a router created by the same RouteSet."
                )
                self.routes = routes
                self.router = router
                self.content = content()
              }

              var body: some View {
                content.environment(AppRoutes._routerEnvironmentKey, router)
                  .environment(AppRoutes._routeSetEnvironmentKey, routes)
              }
            }

          @View
            struct RouterView {
              let routes: RouteSet
              let router: Router<RouteView>

              init() {
                do throws(RouteTreeError) {
                  let routes = try AppRoutes.routes()
                  self.routes = routes
                  self.router = routes.router()
                } catch {
                  preconditionFailure("AppRoutes.RouterView could not build routes.")
                }
              }

              init(_ routes: RouteSet, router: Router<RouteView>) {
                precondition(
                  router._uses(routes.tree),
                  "AppRoutes.RouterView requires a router created by the same RouteSet."
                )
                self.routes = routes
                self.router = router
              }

              var body: some View {
                Provider(routes, router: router) {
                  rendered
                }
              }

              private var rendered: RouteView {
                do {
                  return try router.renderCurrentRoute()
                } catch {
                  preconditionFailure("AppRoutes.RouterView could not render the current route.")
                }
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

          static let _routeSetEnvironmentKey = EnvironmentValues._Key<RouteSet?>(
              "ElementaryRouter.AppRoutes.routes",
              defaultValue: nil
            )

          @View
            struct Provider<Content: View> {
              let routes: RouteSet
              let router: Router<RouteView>
              let content: Content

              init(_ routes: RouteSet, router: Router<RouteView>, @HTMLBuilder content: () -> Content) {
                precondition(
                  router._uses(routes.tree),
                  "AppRoutes.Provider requires a router created by the same RouteSet."
                )
                self.routes = routes
                self.router = router
                self.content = content()
              }

              var body: some View {
                content.environment(AppRoutes._routerEnvironmentKey, router)
                  .environment(AppRoutes._routeSetEnvironmentKey, routes)
              }
            }

          @View
            struct RouterView {
              let routes: RouteSet
              let router: Router<RouteView>

              init() {
                do throws(RouteTreeError) {
                  let routes = try AppRoutes.routes()
                  self.routes = routes
                  self.router = routes.router()
                } catch {
                  preconditionFailure("AppRoutes.RouterView could not build routes.")
                }
              }

              init(_ routes: RouteSet, router: Router<RouteView>) {
                precondition(
                  router._uses(routes.tree),
                  "AppRoutes.RouterView requires a router created by the same RouteSet."
                )
                self.routes = routes
                self.router = router
              }

              var body: some View {
                Provider(routes, router: router) {
                  rendered
                }
              }

              private var rendered: RouteView {
                do {
                  return try router.renderCurrentRoute()
                } catch {
                  preconditionFailure("AppRoutes.RouterView could not render the current route.")
                }
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
              return try tree._hashHref(to: handles.docs, params: params, query: query, hash: hash)
            }
            }

          static let _routerEnvironmentKey = EnvironmentValues._Key<HashRouter<RouteView>?>(
              "ElementaryRouter.DocsRoutes.router",
              defaultValue: nil
            )

          static let _routeSetEnvironmentKey = EnvironmentValues._Key<RouteSet?>(
              "ElementaryRouter.DocsRoutes.routes",
              defaultValue: nil
            )

          @View
            struct Provider<Content: View> {
              let routes: RouteSet
              let router: HashRouter<RouteView>
              let content: Content

              init(_ routes: RouteSet, router: HashRouter<RouteView>, @HTMLBuilder content: () -> Content) {
                precondition(
                  router._uses(routes.tree),
                  "DocsRoutes.Provider requires a router created by the same RouteSet."
                )
                self.routes = routes
                self.router = router
                self.content = content()
              }

              var body: some View {
                content.environment(DocsRoutes._routerEnvironmentKey, router)
                  .environment(DocsRoutes._routeSetEnvironmentKey, routes)
              }
            }

          @View
            struct RouterView {
              let routes: RouteSet
              let router: HashRouter<RouteView>

              init() {
                do throws(RouteTreeError) {
                  let routes = try DocsRoutes.routes()
                  self.routes = routes
                  self.router = routes.router()
                } catch {
                  preconditionFailure("DocsRoutes.RouterView could not build routes.")
                }
              }

              init(_ routes: RouteSet, router: HashRouter<RouteView>) {
                precondition(
                  router._uses(routes.tree),
                  "DocsRoutes.RouterView requires a router created by the same RouteSet."
                )
                self.routes = routes
                self.router = router
              }

              var body: some View {
                Provider(routes, router: router) {
                  rendered
                }
              }

              private var rendered: RouteView {
                do {
                  return try router.renderCurrentRoute()
                } catch {
                  preconditionFailure("DocsRoutes.RouterView could not render the current route.")
                }
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
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  func testRoutesMacroRegistersNestedLayoutsAsParentChain() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Layout("/:lang/teams/:teamID")
        static func team<Content: View>(lang: String, teamID: Int, outlet: Outlet<Content>) -> TeamLayout<Content> {
          TeamLayout(outlet: outlet)
        }

        @Layout("/")
        static func shell<Content: View>(outlet: Outlet<Content>) -> Shell<Content> {
          Shell(outlet: outlet)
        }

        @Layout("/:lang")
        static func language<Content: View>(lang: String, outlet: Outlet<Content>) -> LanguageLayout<Content> {
          LanguageLayout(outlet: outlet)
        }

        @Layout("/caf%C3%A9")
        static func cafe<Content: View>(outlet: Outlet<Content>) -> CafeLayout<Content> {
          CafeLayout(outlet: outlet)
        }

        @Route("/:lang/teams/:teamID")
        static func teamIndex(lang: String, teamID: Int) -> TeamPage {
          TeamPage()
        }

        @Route("/:lang/teams/:teamID/members/:memberID")
        static func member(lang: String, teamID: Int, memberID: Int) -> MemberPage {
          MemberPage()
        }

        @Route("/café/menu")
        static func menu() -> MenuPage {
          MenuPage()
        }

        @Route("/:slug/about")
        static func about(slug: String) -> AboutPage {
          AboutPage()
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])

    let registrations = [
      #"let shell = collection._layout("/", parent: nil)"#,
      #"let language = collection._layout(":lang", parent: shell)"#,
      #"let cafe = collection._layout("caf%C3%A9", parent: shell)"#,
      #"let team = collection._layout("teams/:teamID", parent: language)"#,
      #"let teamIndex = collection._route("/", parent: team)"#,
      #"let member = collection._route("members/:memberID", parent: team)"#,
      #"let menu = collection._route("menu", parent: cafe)"#,
      // `:slug` is not `:lang`, so the route is not nested in the language layout.
      #"let about = collection._route(":slug/about", parent: shell)"#,
    ]
    var previousOffset = expansion.source.startIndex
    for registration in registrations {
      guard let range = expansion.source.firstRange(of: registration) else {
        XCTFail("Missing registration: \(registration)\n\(expansion.source)")
        continue
      }
      // Parents are registered before children so generated code can reference parent handles.
      XCTAssertGreaterThanOrEqual(range.lowerBound, previousOffset, registration)
      previousOffset = range.lowerBound
    }
  }

  func testRoutesMacroGeneratesHashHrefHelpersForHashMode() throws {
    let expansion = try expandRoutes(
      """
      @Routes(mode: .hash)
      struct AppRoutes {
        @Route("/users/:id")
        static func user(id: Int) -> UserPage {
          UserPage()
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])
    XCTAssertTrue(expansion.source.contains("tree._hashHref(to: handles.user"))
    XCTAssertFalse(expansion.source.contains("tree._href("))
  }

  func testRoutesMacroReportsStructurallyIndistinguishableRoutes() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Route("/users/:id")
        static func user(id: Int) -> UserPage {
          UserPage()
        }

        @Route("/users/:name")
        static func userByName(name: String) -> UserPage {
          UserPage()
        }

        @Route("/caf%C3%A9")
        static func cafe() -> CafePage {
          CafePage()
        }

        @Route("/café/")
        static func cafeAlias() -> CafePage {
          CafePage()
        }

        @Route("/users/:id/")
        static func userAgain(id: Int) -> UserPage {
          UserPage()
        }

        @Layout("/:lang")
        static func language<Content: View>(lang: String, outlet: Outlet<Content>) -> LanguageLayout<Content> {
          LanguageLayout(outlet: outlet)
        }

        @Layout("/:locale")
        static func locale<Content: View>(locale: String, outlet: Outlet<Content>) -> LanguageLayout<Content> {
          LanguageLayout(outlet: outlet)
        }
      }
      """
    )

    XCTAssertEqual(
      expansion.diagnostics,
      [
        "Route path `/users/:name` matches the same URLs as `/users/:id`.",
        "Route path `/café` matches the same URLs as `/caf%C3%A9`.",
        "Duplicate route path `/users/:id`.",
        "Route path `/:locale` matches the same URLs as `/:lang`.",
      ]
    )
  }

  func testRoutesMacroAcceptsRoutesSeparatedByPrecedence() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Route("/users")
        static func users() -> UsersPage {
          UsersPage()
        }

        @Route("/users/new")
        static func newUser() -> NewUserPage {
          NewUserPage()
        }

        @Route("/users/:id")
        static func user(id: Int) -> UserPage {
          UserPage()
        }

        @Route("/users/*")
        static func userFiles(path: Wildcard) -> UserFilesPage {
          UserFilesPage()
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])
  }

  func testRoutesMacroRequiresWildcardAsLastSegment() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Route("/files/*/raw")
        static func raw(path: Wildcard) -> RawPage {
          RawPage()
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, ["Wildcard `*` must be the last path segment."])
  }
}

private struct RoutesExpansion {
  let source: String
  let diagnostics: [String]
}

/// Expands `@Routes` directly so tests can inspect diagnostics and generated registrations
/// without restating the full generated source.
private func expandRoutes(_ source: String) throws -> RoutesExpansion {
  let declaration = DeclSyntax(stringLiteral: source)
  guard let structDeclaration = declaration.as(StructDeclSyntax.self),
    case .attribute(let attribute)? = structDeclaration.attributes.first
  else {
    XCTFail("Expected a struct with a leading @Routes attribute")
    return RoutesExpansion(source: "", diagnostics: [])
  }

  let context = DiagnosticCollectingContext()
  let members = try RoutesMacro.expansion(
    of: attribute,
    providingMembersOf: structDeclaration,
    conformingTo: [],
    in: context
  )
  return RoutesExpansion(
    source: members.map(\.description).joined(separator: "\n"),
    diagnostics: context.diagnostics.map(\.message)
  )
}

private final class DiagnosticCollectingContext: MacroExpansionContext {
  private(set) var diagnostics: [Diagnostic] = []
  private var uniqueNameCount = 0

  var lexicalContext: [Syntax] {
    []
  }

  func makeUniqueName(_ name: String) -> TokenSyntax {
    uniqueNameCount += 1
    return .identifier("__routes_\(name)_\(uniqueNameCount)")
  }

  func diagnose(_ diagnostic: Diagnostic) {
    diagnostics.append(diagnostic)
  }

  func location(
    of node: some SyntaxProtocol,
    at position: PositionInSyntaxNode,
    filePathMode: SourceLocationFilePathMode
  ) -> AbstractSourceLocation? {
    nil
  }
}
