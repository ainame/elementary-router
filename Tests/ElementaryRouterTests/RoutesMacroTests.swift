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
  func testRoutesMacroGeneratesTypedDestinationFactories() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Layout("/")
        static func shell<Content: View>(outlet: Outlet<Content>) -> Shell<Content> {
          Shell(outlet: outlet)
        }

        @Route("/")
        static func home(page: Query<Int> = Query(1)) -> HomePage {
          HomePage(page: page.value)
        }

        @Route("/search")
        static func search(q: Query<String>) -> SearchPage {
          SearchPage(q: q.value)
        }

        @Route("/users/:id")
        static func user(id: Int, tab: Query<String> = Query("overview")) -> UserPage {
          UserPage(id: id, tab: tab.value)
        }

        @Route("/articles")
        static func articles(sort: Query<SortOrder> = Query(.newest)) -> ArticlesPage {
          ArticlesPage(sort: sort.value)
        }

        @Route("/docs/*")
        static func docs(splat: Wildcard) -> DocsPage {
          DocsPage(slug: splat.value)
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])
    let source = expansion.source

    // Path, wildcard, and query values keep their declared types; defaulted queries are optional.
    XCTAssertTrue(
      source.contains(
        #"func user(id: Int, tab: String? = nil, hash: String = "") throws(RouteMatchError) -> RouteDestination<RouteView> {"#
      ),
      source
    )
    XCTAssertTrue(source.contains("to: self.handles.user,"), source)
    XCTAssertTrue(source.contains(#"params: RouteValues()._setting("id", id),"#), source)
    XCTAssertTrue(source.contains(#"query: RouteValues()._settingIfPresent("tab", tab),"#), source)
    XCTAssertTrue(
      source.contains(
        #"func docs(splat: String, hash: String = "") throws(RouteMatchError) -> RouteDestination<RouteView> {"#
      ),
      source
    )
    XCTAssertTrue(source.contains(#"params: RouteValues()._setting("*", splat),"#), source)

    // Static paths with built-in query types cannot fail, so their factories do not throw.
    XCTAssertTrue(
      source.contains(#"func home(page: Int? = nil, hash: String = "") -> RouteDestination<RouteView> {"#),
      source
    )
    XCTAssertTrue(
      source.contains(#"func search(q: String, hash: String = "") -> RouteDestination<RouteView> {"#),
      source
    )
    XCTAssertTrue(source.contains(#"query: RouteValues()._setting("q", q),"#), source)

    // A custom query type may encode a value it cannot decode, so its factory throws.
    XCTAssertTrue(
      source.contains(
        #"func articles(sort: SortOrder? = nil, hash: String = "") throws(RouteMatchError) -> RouteDestination<RouteView> {"#
      ),
      source
    )

    // Layouts never match on their own, so they get handles but no destination factory.
    XCTAssertTrue(source.contains("let shell: RouteHandle"), source)
    XCTAssertFalse(source.contains("func shell("), source)

    // Untyped per-route href helpers are replaced by `href(to:)` with a typed destination.
    XCTAssertFalse(source.contains("Href("), source)
    XCTAssertTrue(
      source.contains("func href(to destination: RouteDestination<RouteView>) throws(RouteMatchError) -> String {"),
      source
    )
    XCTAssertTrue(source.contains("try tree._validate(destination)"), source)
    XCTAssertTrue(source.contains("return destination.location.href"), source)
  }

  func testRoutesMacroGeneratesLinkForTypedDestinations() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      public struct AppRoutes {
        @Route("/users/:id")
        static func user(id: Int) -> UserPage {
          UserPage(id: id)
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])
    let source = expansion.source

    XCTAssertTrue(
      source.contains(
        #"public func user(id: Int, hash: String = "") throws(RouteMatchError) -> RouteDestination<RouteView> {"#
      ),
      source
    )
    XCTAssertTrue(source.contains("let destination: RouteDestination<RouteView>"), source)
    XCTAssertTrue(source.contains("to destination: RouteDestination<RouteView>,"), source)
    XCTAssertTrue(source.contains("try router.navigate(to: destination, replace: replace)"), source)
    XCTAssertTrue(
      source.contains(#".attributes(.data("router-link", value: "true"), when: usesClientNavigation)"#),
      source
    )

    // Links take only typed destinations, never fall back to `#`, and never discard errors.
    XCTAssertFalse(source.contains("to route: RouteHandle"), source)
    XCTAssertFalse(source.contains("params: RouteValues = RouteValues()"), source)
    XCTAssertFalse(source.contains(##"?? "#""##), source)
    XCTAssertFalse(source.contains("try?"), source)
  }

  func testRoutesMacroGeneratesFragmentHrefsForHashMode() throws {
    let expansion = try expandRoutes(
      """
      @Routes(mode: .hash)
      struct DocsRoutes {
        @Route("/docs/*")
        static func docs(splat: Wildcard) -> DocsPage {
          DocsPage(slug: splat.value)
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])
    let source = expansion.source
    XCTAssertTrue(source.contains("func router() -> HashRouter<RouteView> {"), source)
    XCTAssertTrue(source.contains(##"return "#" + destination.location.href"##), source)
    XCTAssertFalse(source.contains("return destination.location.href"), source)
  }

  func testRoutesMacroRejectsNamesThatCollideWithGeneratedRouteSetMembers() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Route("/router")
        static func router() -> RouterPage {
          RouterPage()
        }

        @Route("/tree")
        static func tree() -> TreePage {
          TreePage()
        }

        @Route("/notes/:hash")
        static func note(hash: String) -> NotePage {
          NotePage()
        }

        @Route("/search")
        static func search(hash: Query<String>) -> SearchPage {
          SearchPage()
        }
      }
      """
    )

    XCTAssertEqual(
      expansion.diagnostics,
      [
        "Route name `router` is reserved by the generated `RouteSet`.",
        "Route name `tree` is reserved by the generated `RouteSet`.",
        "Route parameter `hash` conflicts with the generated destination `hash:` argument.",
        "Route parameter `hash` conflicts with the generated destination `hash:` argument.",
      ]
    )
  }

  func testRoutesMacroRejectsStaticDotSegments() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Route("/files/../raw")
        static func raw() -> RawPage {
          RawPage()
        }

        @Route("/files/%2E")
        static func encodedDot() -> RawPage {
          RawPage()
        }

        @Layout("/./admin")
        static func admin<Content: View>(outlet: Outlet<Content>) -> AdminLayout<Content> {
          AdminLayout(outlet: outlet)
        }

        @Route("/files/.well-known/...")
        static func dotted() -> RawPage {
          RawPage()
        }
      }
      """
    )

    XCTAssertEqual(
      expansion.diagnostics,
      [
        "Route path segment `..` is a dot segment, which browsers remove from URLs.",
        "Route path segment `%2E` is a dot segment, which browsers remove from URLs.",
        "Route path segment `.` is a dot segment, which browsers remove from URLs.",
      ]
    )
  }

  func testRouteMarkerMacrosRequireStaticFunctions() {
    assertMacroExpansion(
      """
      struct AppRoutes {
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
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "`@Route` can only be attached to a static function.",
          line: 2,
          column: 3
        ),
        DiagnosticSpec(
          message: "`@Layout` can only be attached to a static function.",
          line: 7,
          column: 3
        ),
        DiagnosticSpec(
          message: "`@NotFound` can only be attached to a static function.",
          line: 12,
          column: 3
        ),
        DiagnosticSpec(
          message: "`@RouteError` can only be attached to a static function.",
          line: 17,
          column: 3
        ),
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  func testRoutesMacroIgnoresNonStaticRouteFunctions() throws {
    let expansion = try expandRoutes(
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
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])
    XCTAssertTrue(
      expansion.source.contains(#"func valid(hash: String = "") -> RouteDestination<RouteView> {"#),
      expansion.source
    )
    XCTAssertFalse(expansion.source.contains("func user("), expansion.source)
  }

  func testRoutesMacroExpansionReportsMissingPathParameter() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Route("/users/:id")
        static func user() -> UserPage {
          UserPage()
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, ["Missing function parameter for path parameter `id`."])
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
      #"let shell = collection._generatedLayout("/", parent: nil"#,
      #"let language = collection._generatedLayout(":lang", parent: shell"#,
      #"let cafe = collection._generatedLayout("caf%C3%A9", parent: shell"#,
      #"let team = collection._generatedLayout("teams/:teamID", parent: language"#,
      #"let teamIndex = collection._generatedRoute("/", parent: team"#,
      #"let member = collection._generatedRoute("members/:memberID", parent: team"#,
      #"let menu = collection._generatedRoute("menu", parent: cafe"#,
      // `:slug` is not `:lang`, so the route is not nested in the language layout.
      #"let about = collection._generatedRoute(":slug/about", parent: shell"#,
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

  func testRoutesMacroRendersEachLayoutOutsideItsChildSwitch() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Layout("/")
        static func root<Content: View>(context: RouteContext, outlet: Outlet<Content>) -> Root<Content> {
          Root(outlet: outlet)
        }

        @Layout("/:lang")
        static func language<Content: View>(lang: String, sort: Query<String> = Query("name"), outlet: Outlet<Content>) -> Language<Content> {
          Language(outlet: outlet)
        }

        @Layout("/:lang/teams/:teamID")
        static func team<Content: View>(lang: String, teamID: Int, outlet: Outlet<Content>) -> Team<Content> {
          Team(outlet: outlet)
        }

        @Layout("/unused")
        static func unused<Content: View>(outlet: Outlet<Content>) -> Unused<Content> {
          Unused(outlet: outlet)
        }

        @Route("/")
        static func home() -> HomePage {
          HomePage()
        }

        @Route("/:lang/about")
        static func about(lang: String) -> AboutPage {
          AboutPage()
        }

        @Route("/:lang/teams/:teamID")
        static func teamIndex(lang: String, teamID: Int) -> TeamPage {
          TeamPage()
        }

        @Route("/:lang/teams/:teamID/members/:memberID")
        static func member(lang: String, teamID: Int, memberID: Int, sort: Query<String> = Query("date"), context: RouteContext) -> MemberPage {
          MemberPage()
        }

        @NotFound
        static func notFound(context: RouteNotFoundContext) -> NotFoundPage {
          NotFoundPage()
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])
    let source = expansion.source

    // Each layout case stores the layout's own values and the outlet view of its children. Each
    // outlet is a plain enum with an inline conformance, rendered by the library's generic
    // `_RouteOutlet` view, so no `@View` type is nested inside the generated `RouteView`.
    for declaration in [
      "case root(context: RouteContext, outlet: _RouteOutlet<RootOutlet>)",
      "case notFound(RouteNotFoundContext)",
      "enum RootOutlet: _RouteOutletStorage {",
      "case language(lang: String, sort: String, outlet: _RouteOutlet<LanguageOutlet>)",
      "case home",
      "enum LanguageOutlet: _RouteOutletStorage {",
      "case team(lang: String, teamID: Int, outlet: _RouteOutlet<TeamOutlet>)",
      "case about(lang: String)",
      "enum TeamOutlet: _RouteOutletStorage {",
      "case teamIndex(lang: String, teamID: Int)",
      "case member(lang: String, teamID: Int, memberID: Int, sort: String, context: RouteContext)",
      "@HTMLBuilder var content: some View {",
      "switch self {",
    ] {
      XCTAssertTrue(source.contains(declaration), "Missing \(declaration)\n\(source)")
    }
    // Only the top-level generated views use `@View`: RouteView, Provider, RouterView, and Link.
    XCTAssertEqual(source.ranges(of: "@View").count, 4, source)
    XCTAssertFalse(source.contains("struct RootOutlet"), source)

    // A layout that wraps no route never renders, so it gets no case or outlet view.
    XCTAssertFalse(source.contains("UnusedOutlet"), source)
    XCTAssertFalse(source.contains("case unused"), source)
    XCTAssertTrue(source.contains("let unused = collection._generatedLayout("), source)

    // Every route and layout function is called from exactly one switch case, so a layout is
    // never repeated inside the cases of its children.
    for name in ["root", "language", "team", "home", "about", "teamIndex", "member"] {
      XCTAssertEqual(source.ranges(of: "AppRoutes.\(name)(").count, 1, "\(name)\n\(source)")
    }
    XCTAssertTrue(
      source.contains("AppRoutes.root(context: value0, outlet: Outlet(value1))"),
      source
    )
    XCTAssertTrue(
      source.contains(
        "AppRoutes.member(lang: value0, teamID: value1, memberID: value2, sort: Query(value3), context: value4)"
      ),
      source
    )

    // Layouts decode only the values that can fail, with their own context.
    XCTAssertTrue(
      source.contains(#"let root = collection._generatedLayout("/", parent: nil, decode: { _ in })"#),
      source
    )
    XCTAssertTrue(
      source.contains(
        #"let language = collection._generatedLayout(":lang", parent: root, decode: { context throws(RouteValueError) in"#
      ),
      source
    )
    XCTAssertTrue(source.contains(#"_ = try context.params.require("lang", String.self)"#), source)
    XCTAssertFalse(source.contains(#"_ = context.query"#), source)

    // The leaf builds every layout value from that layout's own match context.
    XCTAssertTrue(
      source.contains(
        #"let member = collection._generatedRoute("members/:memberID", parent: team, render: { contexts throws(RouteValueError) in"#
      ),
      source
    )
    let memberStorage = [
      "RouteView(storage: .root(context: contexts[0], outlet: _RouteOutlet<RouteView.RootOutlet>(storage: ",
      #".language(lang: try contexts[1].params.require("lang", String.self), "#,
      #"sort: contexts[1].query.get("sort", String.self) ?? "name", "#,
      "outlet: _RouteOutlet<RouteView.LanguageOutlet>(storage: ",
      #".team(lang: try contexts[2].params.require("lang", String.self), "#,
      #"teamID: try contexts[2].params.require("teamID", Int.self), "#,
      "outlet: _RouteOutlet<RouteView.TeamOutlet>(storage: ",
      #".member(lang: try contexts[3].params.require("lang", String.self), "#,
      #"teamID: try contexts[3].params.require("teamID", Int.self), "#,
      #"memberID: try contexts[3].params.require("memberID", Int.self), "#,
      #"sort: contexts[3].query.get("sort", String.self) ?? "date", "#,
      "context: contexts[3]))))))))",
    ].joined()
    XCTAssertTrue(source.contains(memberStorage), source)
    XCTAssertTrue(
      source.contains(
        #"let home = collection._generatedRoute("/", parent: root, render: { contexts throws(RouteValueError) in"#
      ),
      source
    )
    XCTAssertTrue(
      source.contains(
        "RouteView(storage: .root(context: contexts[0], outlet: _RouteOutlet<RouteView.RootOutlet>(storage: .home)))"
      ),
      source
    )

    // A query declared by the member route and its language layout is one factory argument,
    // optional because both declarations have defaults.
    XCTAssertTrue(
      source.contains(
        #"func member(lang: String, teamID: Int, memberID: Int, sort: String? = nil, hash: String = "") throws(RouteMatchError) -> RouteDestination<RouteView> {"#
      ),
      source
    )
    XCTAssertTrue(
      source.contains(
        #"func about(lang: String, sort: String? = nil, hash: String = "") throws(RouteMatchError) -> RouteDestination<RouteView> {"#
      ),
      source
    )
    XCTAssertTrue(
      source.contains(#"func home(hash: String = "") -> RouteDestination<RouteView> {"#),
      source
    )
  }

  func testRoutesMacroFactoriesTakeTheQueriesOfEnclosingLayouts() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Layout("/:lang")
        static func language<Content: View>(lang: String, view: Query<String> = Query("grid"), outlet: Outlet<Content>) -> Language<Content> {
          Language(outlet: outlet)
        }

        @Layout("/:lang/admin")
        static func admin<Content: View>(lang: String, level: Query<Int>, sort: Query<SortOrder> = Query(.newest), outlet: Outlet<Content>) -> Admin<Content> {
          Admin(outlet: outlet)
        }

        @Route("/:lang/admin/users")
        static func adminUsers(lang: String, view: Query<String>, page: Query<Int> = Query(1)) -> UsersPage {
          UsersPage()
        }

        @Route("/:lang/about")
        static func about(lang: String) -> AboutPage {
          AboutPage()
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])
    let source = expansion.source

    // The route's own queries come first, then each layout's from the outermost layout in. A
    // shared name is one argument, required when any declaration requires it.
    XCTAssertTrue(
      source.contains(
        #"func adminUsers(lang: String, view: String, page: Int? = nil, level: Int, sort: SortOrder? = nil, hash: String = "") throws(RouteMatchError) -> RouteDestination<RouteView> {"#
      ),
      source
    )
    XCTAssertTrue(
      source.contains(
        #"query: RouteValues()._setting("view", view)._settingIfPresent("page", page)._setting("level", level)._settingIfPresent("sort", sort),"#
      ),
      source
    )
    XCTAssertTrue(
      source.contains(
        #"func about(lang: String, view: String? = nil, hash: String = "") throws(RouteMatchError) -> RouteDestination<RouteView> {"#
      ),
      source
    )
  }

  func testRoutesMacroRejectsLayoutsThatCannotDecodeTheirRouteValues() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Layout("/accounts/:id")
        static func account<Content: View>(id: Int, outlet: Outlet<Content>) -> Account<Content> {
          Account(outlet: outlet)
        }

        @Layout("/posts/:slug")
        static func post<Content: View>(slug: Slug, sort: Query<String> = Query("new"), id: Query<Int> = Query(0), hash: Query<String> = Query(""), outlet: Outlet<Content>) -> Post<Content> {
          Post(outlet: outlet)
        }

        @Route("/accounts/:id/settings")
        static func accountSettings(id: String) -> SettingsPage {
          SettingsPage()
        }

        @Route("/posts/:slug/comments")
        static func comments(slug: String, sort: Query<Int> = Query(1)) -> CommentsPage {
          CommentsPage()
        }

        @Route("/posts/:slug/:id")
        static func comment(slug: Slug, id: Int) -> CommentPage {
          CommentPage()
        }

        @Layout("/docs")
        static func docsLayout<Content: View>(path: Query<String> = Query(""), outlet: Outlet<Content>) -> Docs<Content> {
          Docs(outlet: outlet)
        }

        @Route("/docs/*")
        static func docs(path: Wildcard) -> DocsPage {
          DocsPage()
        }

        // `Swift.Int` and `Int` are spellings of one type, so they do not conflict.
        @Layout("/teams/:teamID")
        static func team<Content: View>(teamID: Swift.Int, outlet: Outlet<Content>) -> Team<Content> {
          Team(outlet: outlet)
        }

        @Route("/teams/:teamID/settings")
        static func teamSettings(teamID: Int) -> SettingsPage {
          SettingsPage()
        }
      }
      """
    )

    XCTAssertEqual(
      expansion.diagnostics,
      [
        "Path parameter `id` is declared as `Int` by layout `account` and as `String` by route `accountSettings`; a route and its layouts must decode it with one type.",
        // A custom `RouteValue` type must match too: `Slug` and `String` decode differently.
        "Path parameter `slug` is declared as `Slug` by layout `post` and as `String` by route `comments`; a route and its layouts must decode it with one type.",
        "Route parameter `hash` conflicts with the generated destination `hash:` argument.",
        "Query `sort` is declared as `String` by `post` and as `Int` by `comments`; a route and its layouts share one query value, so they must declare it with one type.",
        "Query `id` of layout `post` has the same name as a path or wildcard parameter of route `comment`, so the route's destination factory cannot take both.",
        // A wildcard is a factory argument too, so a layout query cannot share its label.
        "Query `path` of layout `docsLayout` has the same name as a path or wildcard parameter of route `docs`, so the route's destination factory cannot take both.",
      ]
    )

    // Rejected routes get no generated code, so the diagnostics are the only errors reported.
    let source = expansion.source
    for name in ["accountSettings", "comments", "comment", "docs"] {
      XCTAssertFalse(source.contains("func \(name)("), "\(name)\n\(source)")
      XCTAssertFalse(source.contains("AppRoutes.\(name)("), "\(name)\n\(source)")
    }
    XCTAssertTrue(
      source.contains(
        #"func teamSettings(teamID: Int, hash: String = "") throws(RouteMatchError) -> RouteDestination<RouteView> {"#
      ),
      source
    )
    XCTAssertTrue(source.contains("AppRoutes.team(teamID: value0, outlet: Outlet(value1))"), source)
  }

  func testRoutesMacroRegistersRoutesWithoutValuesWithoutReadingContexts() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Layout("/")
        static func shell<Content: View>(outlet: Outlet<Content>) -> Shell<Content> {
          Shell(outlet: outlet)
        }

        @Route("/")
        static func home() -> HomePage {
          HomePage()
        }
      }
      """
    )

    XCTAssertEqual(expansion.diagnostics, [])
    XCTAssertTrue(
      expansion.source.contains(
        #"let home = collection._generatedRoute("/", parent: shell, render: { _ in"#
      ),
      expansion.source
    )
    XCTAssertTrue(
      expansion.source.contains(
        "RouteView(storage: .shell(outlet: _RouteOutlet<RouteView.ShellOutlet>(storage: .home)))"
      ),
      expansion.source
    )
  }

  func testRoutesMacroRejectsUnsupportedLayoutsAndParameters() throws {
    let expansion = try expandRoutes(
      """
      @Routes
      struct AppRoutes {
        @Layout("/a")
        static func twoOutlets<Content: View>(first: Outlet<Content>, second: Outlet<Content>) -> Page {
          Page()
        }

        @Layout("/b")
        static func concrete(outlet: Outlet<EmptyHTML>) -> Page {
          Page()
        }

        @Layout("/c")
        static func extraGeneric<Content: View, Other>(outlet: Outlet<Content>) -> Page {
          Page()
        }

        @Layout("/l")
        static func shell<Content: View>(outlet: Outlet<Content>) -> Page {
          Page()
        }

        @Layout("/m")
        static func Shell<Content: View>(outlet: Outlet<Content>) -> Page {
          Page()
        }

        @Route("/d")
        static func generic<T>() -> Page {
          Page()
        }

        @Route("/e")
        static func withOutlet<Content: View>(outlet: Outlet<Content>) -> Page {
          Page()
        }

        @Route("/f")
        static func unlabeled(_ q: Query<String>) -> Page {
          Page()
        }

        @Route("/g")
        static func throwing() throws -> Page {
          Page()
        }

        @Route("/h")
        static func duplicateLabel(q: Query<String>, q other: Query<Int>) -> Page {
          Page()
        }

        @Route("/i")
        static func collection() -> Page {
          Page()
        }

        @Route("/j")
        static func page() -> Page {
          Page()
        }

        @Route("/k")
        static func page(q: Query<String>) -> Page {
          Page()
        }
      }
      """
    )

    XCTAssertEqual(
      expansion.diagnostics,
      [
        "`@Layout` functions must declare exactly one outlet parameter.",
        "`@Layout` outlet parameters must have type `Outlet<Content>`, where `Content` is the layout function's only generic parameter.",
        "`@Layout` outlet parameters must have type `Outlet<Content>`, where `Content` is the layout function's only generic parameter.",
        "`@Route` functions cannot be generic.",
        "`@Route` functions cannot be generic.",
        "`@Route` functions cannot declare an outlet parameter; use `@Layout` to wrap child routes.",
        "Route parameter `q` must have an argument label.",
        "`@Route` and `@Layout` functions cannot be `async` or `throws`.",
        "Route parameter label `q` is declared more than once.",
        "Layouts `shell` and `Shell` both generate `RouteView.ShellOutlet`.",
        "Route name `collection` is reserved by generated `@Routes` code.",
        "Route name `page` is declared more than once; `@Route` and `@Layout` functions need unique names.",
      ]
    )

    // Invalid declarations generate nothing: `expandRoutes` has already checked that the
    // remaining generated members parse, and only the first, valid `page` route is generated.
    let source = expansion.source
    for name in [
      "twoOutlets", "concrete", "extraGeneric", "Shell", "generic", "withOutlet", "unlabeled",
      "throwing", "duplicateLabel", "collection",
    ] {
      XCTAssertFalse(source.contains("AppRoutes.\(name)("), "\(name)\n\(source)")
      XCTAssertFalse(source.contains("let \(name) = collection."), "\(name)\n\(source)")
    }
    XCTAssertEqual(source.ranges(of: "func page(").count, 1, source)
    XCTAssertTrue(source.contains(#"let page = collection._generatedRoute("/j", parent: nil"#), source)
    XCTAssertTrue(source.contains("let shell = collection._generatedLayout("), source)
  }

  func testRoutesMacroRouterViewOwnsItsRouterLazily() throws {
    for (mode, router) in [("", "Router<RouteView>"), ("(mode: .hash)", "HashRouter<RouteView>")] {
      let expansion = try expandRoutes(
        """
        @Routes\(mode)
        struct AppRoutes {
          @Route("/")
          static func home() -> HomePage {
            HomePage()
          }
        }
        """
      )

      XCTAssertEqual(expansion.diagnostics, [])
      let source = expansion.source

      // The `@State` initial value is evaluated for every rebuilt view value, so it only
      // describes how to build the router; the mounted session builds it once, on first read.
      XCTAssertTrue(
        source.contains("@State var session = _RouterViewSession<RouteSet, \(router)> {"),
        source
      )
      XCTAssertTrue(source.contains("return (routes: routes, router: routes.router())"), source)
      XCTAssertTrue(source.contains("self.supplied = nil"), source)
      XCTAssertFalse(source.contains("self.router = routes.router()"), source)

      // A supplied pair is stored as one value and read before the owned session.
      XCTAssertTrue(source.contains("let supplied: (routes: RouteSet, router: \(router))?"), source)
      XCTAssertTrue(source.contains("self.supplied = (routes: routes, router: router)"), source)
      XCTAssertTrue(source.contains("supplied?.routes ?? session.routes"), source)
      XCTAssertTrue(source.contains("supplied?.router ?? session.router"), source)
    }
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
  // Generated members are parsed back into syntax; a template mistake shows up as a syntax error.
  for member in members where member.hasError {
    XCTFail("Generated member has syntax errors:\n\(member.description)")
  }
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
