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
