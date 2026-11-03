import ElementaryUI
import Testing

@testable import ElementaryRouter

@Routes
struct MacroRoutes {
  @Route("/")
  static func home() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/users/:id")
  static func user(id: Int, tab: Query<String> = Query("overview")) -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/files/*")
  static func file(splat: Wildcard) -> EmptyHTML {
    EmptyHTML()
  }

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> EmptyHTML {
    EmptyHTML()
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> EmptyHTML {
    EmptyHTML()
  }
}

@View
struct MacroLayout<Content: View> {
  let teamID: Int
  let outlet: Outlet<Content>

  var body: some View {
    outlet
  }
}

@Routes
struct MacroLayoutRoutes {
  @Layout("/teams/:teamID")
  static func teamLayout<Content: View>(teamID: Int, outlet: Outlet<Content>) -> MacroLayout<
    Content
  > {
    MacroLayout(teamID: teamID, outlet: outlet)
  }

  @Route("/teams/:teamID/members/:memberID")
  static func member(teamID: Int, memberID: Int) -> EmptyHTML {
    EmptyHTML()
  }
}

@View
struct NestedShell<Content: View> {
  let outlet: Outlet<Content>

  var body: some View {
    outlet
  }
}

@Routes
struct NestedLayoutRoutes {
  // Declared inner-first to check that generated registration does not depend on source order.
  @Layout("/:lang/teams/:teamID")
  static func team<Content: View>(
    lang: String,
    teamID: Int,
    outlet: Outlet<Content>
  ) -> NestedShell<Content> {
    NestedShell(outlet: outlet)
  }

  @Layout("/:lang")
  static func language<Content: View>(lang: String, outlet: Outlet<Content>) -> NestedShell<Content> {
    NestedShell(outlet: outlet)
  }

  @Layout("/")
  static func shell<Content: View>(outlet: Outlet<Content>) -> NestedShell<Content> {
    NestedShell(outlet: outlet)
  }

  @Route("/")
  static func home() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/:lang/teams/:teamID")
  static func teamIndex(lang: String, teamID: Int) -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/:lang/teams/:teamID/members/:memberID")
  static func member(lang: String, teamID: Int, memberID: Int) -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/docs/*")
  static func docs(splat: Wildcard) -> EmptyHTML {
    EmptyHTML()
  }

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> EmptyHTML {
    EmptyHTML()
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> EmptyHTML {
    EmptyHTML()
  }
}

@Routes(mode: .hash)
struct HashMacroRoutes {
  @Route("/")
  static func home() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/users/:id")
  static func user(id: Int, tab: Query<String> = Query("overview")) -> EmptyHTML {
    EmptyHTML()
  }
}

@Test func routesMacroGeneratesRouteSetAndTypedRouteView() throws {
  let routeSet = try MacroRoutes.routes()
  let router = MemoryRouter(routes: routeSet.tree, history: MemoryHistory(initialPath: "/users/42"))

  #expect(router.currentRoute == routeSet.handles.user)
  #expect(router.currentParams?.get("id") == "42")
  #expect(try routeSet.userHref(id: 42) == "/users/42")
  #expect(try routeSet.userHref(id: 42, tab: "posts") == "/users/42?tab=posts")
  #expect(
    try routeSet.fileHref(splat: "docs/readme", hash: "install") == "/files/docs/readme#install"
  )
}

@Test func routesMacroComposesLayoutRoutes() throws {
  let routeSet = try MacroLayoutRoutes.routes()
  let router = MemoryRouter(
    routes: routeSet.tree,
    history: MemoryHistory(initialPath: "/teams/7/members/42")
  )

  #expect(router.matchedRoutes == [routeSet.handles.teamLayout, routeSet.handles.member])
  #expect(router.currentParams?.get("teamID") == "7")
  #expect(router.currentParams?.get("memberID") == "42")
  #expect(try routeSet.memberHref(teamID: 7, memberID: 42) == "/teams/7/members/42")

  _ = try router.renderCurrentRoute()

  // The layout has no index route, so its own path is not a successful match.
  #expect(routeSet.tree._matches(RouteLocation(url: "/teams/7")).isEmpty)
}

@Test func nestedLayoutsFormFullParentToLeafMatchStack() throws {
  let routes = try NestedLayoutRoutes.routes()
  let handles = routes.handles
  let router = MemoryRouter(
    routes: routes.tree,
    history: MemoryHistory(initialPath: "/en/teams/7/members/42")
  )

  #expect(router.matchedRoutes == [handles.shell, handles.language, handles.team, handles.member])
  #expect(router.currentRoute == handles.member)
  #expect(router.currentParams?.get("lang") == "en")
  #expect(router.currentParams?.get("teamID") == "7")
  #expect(router.currentParams?.get("memberID") == "42")
  #expect(router.isActive(handles.member))
  #expect(!router.isActive(handles.language))
  #expect(router.isActive(handles.language, options: .descendant))
  #expect(router.isActive(handles.team, options: .init(includeDescendants: true, params: ["teamID": 7])))
  #expect(try routes.memberHref(lang: "en", teamID: 7, memberID: 42) == "/en/teams/7/members/42")

  if case .matched(let context) = routes.tree._resolve(router.location) {
    #expect(context.matchedRoutes == router.matchedRoutes)
  } else {
    Issue.record("Expected matched resolution")
  }

  let rendered = try router.renderCurrentRoute()
  if case .member(let lang, let teamID, let memberID) = rendered.storage {
    #expect(lang == "en")
    #expect(teamID == 7)
    #expect(memberID == 42)
  } else {
    Issue.record("Expected the leaf route to render, got \(rendered.storage)")
  }
}

@Test func nestedLayoutIndexRouteMatchesLayoutPath() throws {
  let routes = try NestedLayoutRoutes.routes()
  let handles = routes.handles
  let router = MemoryRouter(routes: routes.tree, history: MemoryHistory(initialPath: "/en/teams/7"))

  #expect(router.matchedRoutes == [handles.shell, handles.language, handles.team, handles.teamIndex])
  #expect(try routes.teamIndexHref(lang: "en", teamID: 7) == "/en/teams/7")

  let rendered = try router.renderCurrentRoute()
  if case .teamIndex(let lang, let teamID) = rendered.storage {
    #expect(lang == "en")
    #expect(teamID == 7)
  } else {
    Issue.record("Expected the index route to render, got \(rendered.storage)")
  }
}

@Test func nestedLayoutsWithoutMatchingDescendantFallBackToNotFound() throws {
  let routes = try NestedLayoutRoutes.routes()

  for path in ["/en", "/en/unknown", "/en/teams/7/unknown", "/en/teams/7/members"] {
    let location = RouteLocation(url: path)
    #expect(routes.tree._matches(location).isEmpty, "\(path) should not match")

    if case .notFound(let context) = routes.tree._resolve(location) {
      #expect(context.location.path == path)
    } else {
      Issue.record("Expected notFound resolution for \(path)")
    }

    let rendered = try routes.tree._render(location)
    if case .notFound(let context) = rendered.storage {
      #expect(context.location.path == path)
    } else {
      Issue.record("Expected notFound rendering for \(path), got \(rendered.storage)")
    }
  }
}

@Test func nestedLayoutSiblingsOnlyIncludeTheirOwnLayouts() throws {
  let routes = try NestedLayoutRoutes.routes()
  let handles = routes.handles

  #expect(routes.tree._matches(RouteLocation(url: "/")).map(\.route) == [handles.shell, handles.home])

  // A static first segment outranks the `:lang` layout branch.
  let docs = routes.tree._matches(RouteLocation(url: "/docs/teams/7"))
  #expect(docs.map(\.route) == [handles.shell, handles.docs])
  #expect(docs.last?.params.get("*") == "teams/7")

  let docsRoot = routes.tree._matches(RouteLocation(url: "/docs"))
  #expect(docsRoot.map(\.route) == [handles.shell, handles.docs])
  #expect(docsRoot.last?.params.get("*") == "")
}

@Test func nestedLayoutParameterErrorsUseRouteErrorPolicy() throws {
  let routes = try NestedLayoutRoutes.routes()
  let handles = routes.handles
  let location = RouteLocation(url: "/en/teams/abc/members/42")
  let expected = RouteValueError.invalid(name: "teamID", rawValue: "abc", expected: "Int")

  if case .error(let context) = routes.tree._resolve(location) {
    #expect(context.error == expected)
    #expect(context.routeContext.route == handles.team)
    #expect(
      context.routeContext.matchedRoutes == [
        handles.shell, handles.language, handles.team, handles.member,
      ]
    )
  } else {
    Issue.record("Expected layout route error")
  }

  let rendered = try routes.tree._render(location)
  if case .routeError(let context) = rendered.storage {
    #expect(context.error == expected)
  } else {
    Issue.record("Expected routeError rendering, got \(rendered.storage)")
  }
}

@Test func routeBuilderLayoutsOnlyMatchThroughDescendantRoutes() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let account = routes._layout("/accounts/:accountId", parent: nil) { EmptyHTML() }
  let settings = routes._route("settings", parent: account) { EmptyHTML() }
  // An unrelated layout may share a path with a route because layouts never match on their own.
  routes._layout("/admin", parent: nil) { EmptyHTML() }
  let admin = routes._route("/admin") { EmptyHTML() }
  let tree = try routes._build()

  #expect(tree._matches(RouteLocation(url: "/accounts/1")).isEmpty)
  #expect(
    tree._matches(RouteLocation(url: "/accounts/1/settings")).map(\.route) == [account, settings]
  )
  #expect(tree._matches(RouteLocation(url: "/admin")).map(\.route) == [admin])
}

@Test func routeParametersExtractsStringsAndTypedValues() throws {
  let values: RouteValues = ["lang": "ja", "profileId": 42]

  #expect(try values.require("lang") == "ja")
  #expect(try values.require("profileId", Int.self) == 42)
  #expect(values.get("profileId") == "42")
  #expect(values.get("profileId", Int.self) == 42)
}

@Test func routeParametersSupportsInitializerLists() throws {
  let values = RouteValues(("lang", "ja"), ("profileId", 42), ("enabled", true))

  #expect(try values.require("lang") == "ja")
  #expect(try values.require("profileId", Int.self) == 42)
  #expect(try values.require("enabled", Bool.self))
}

@Test func routeParametersReportsMissingAndInvalidValues() {
  let values: RouteValues = ["profileId": "abc"]

  #expect(throws: RouteValueError.missing(name: "lang")) {
    try values.require("lang")
  }

  #expect(throws: RouteValueError.invalid(name: "profileId", rawValue: "abc", expected: "Int")) {
    try values.require("profileId", Int.self)
  }
}

@Test func queryStringParsesMultiValueAndPlusAsSpace() {
  let values = QueryString.parse("?tag=swift&tag=wasm&q=hello+world&encoded=a%2Fb")

  #expect(values.all("tag") == ["swift", "wasm"])
  #expect(values.get("q") == "hello world")
  #expect(values.get("encoded") == "a/b")
}

@Test func queryStringStringifiesValuesInInsertionOrder() {
  let values = RouteValues()
    .append("tag", "swift")
    .append("tag", "wasm")
    .set("q", "hello world")

  #expect(QueryString.stringify(values) == "tag=swift&tag=wasm&q=hello+world")
}

@Test func matcherPrefersStaticRoutesOverDynamicRoutes() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let user = routes._route("/users/:id") { EmptyHTML() }
  let newUser = routes._route("/users/new") { EmptyHTML() }
  let tree = try routes._build()

  #expect(tree._match(RouteLocation(url: "/users/new"))?.route == newUser)

  let match = tree._match(RouteLocation(url: "/users/42"))
  #expect(match?.route == user)
  #expect(match?.params.get("id") == "42")
}

@Test func matcherSupportsWildcardRoutes() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let files = routes._route("/files/*") { EmptyHTML() }
  let tree = try routes._build()

  let match = tree._match(RouteLocation(url: "/files/docs/readme"))
  #expect(match?.route == files)
  #expect(match?.params.get("*") == "docs/readme")
}

@Test func matcherBuildsNestedMatchStack() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let users = routes._route("/users") { EmptyHTML() }
  let user = routes._route(":id", parent: users) { EmptyHTML() }
  let settings = routes._route("settings", parent: user) { EmptyHTML() }
  let tree = try routes._build()

  let matches = tree._matches(RouteLocation(url: "/users/42/settings"))

  #expect(matches.map(\.route) == [users, user, settings])
  #expect(matches.map(\.path) == ["/users", "/users/:id", "/users/:id/settings"])
  #expect(matches[1].params.get("id") == "42")
  #expect(matches[2].params.get("id") == "42")
}

@Test func routeTreeBuildsHrefFromParamsAndQuery() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let profile = routes._route("/:lang/profile/:profileId") { EmptyHTML() }
  let tree = try routes._build()

  let href = try tree._href(
    to: profile,
    params: ["lang": "ja", "profileId": 42],
    query: ["tab": "posts"]
  )

  #expect(href == "/ja/profile/42?tab=posts")
}

@Test func routeTreeReportsUnknownRouteHandles() throws {
  let routes = RouteBuilder<EmptyHTML>()
  routes._route("/") { EmptyHTML() }
  let tree = try routes._build()
  let unknown = RouteHandle(id: .init(rawValue: 999))

  #expect(throws: RouteMatchError.unknownRoute) {
    try tree._href(to: unknown)
  }
}

@Test func memoryHistoryPushReplaceAndGoNotifyListeners() {
  let history = MemoryHistory(initialPath: "/")
  var updates: [HistoryUpdate] = []
  let subscription = history.listen { updates.append($0) }

  history.push(RouteLocation(url: "/a"))
  history.push(RouteLocation(url: "/b"))
  history.replace(RouteLocation(url: "/c"))
  history.go(-1)
  subscription.cancel()

  #expect(history.location.href == "/a")
  #expect(updates.map(\.action) == [.push, .push, .replace, .pop])
  #expect(updates.map(\.location.href) == ["/a", "/b", "/c", "/a"])
}

@Test func routerNavigateUpdatesLocationAndMatches() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let home = routes._route("/") { EmptyHTML() }
  let profile = routes._route("/:lang/profile/:profileId") { EmptyHTML() }
  let tree = try routes._build()
  let history = MemoryHistory(initialPath: "/")
  let router = MemoryRouter(routes: tree, history: history)

  #expect(router.currentRoute == home)

  try router.navigate(
    to: profile,
    params: ["lang": "ja", "profileId": 42],
    query: ["tab": "posts"]
  )

  #expect(router.location.href == "/ja/profile/42?tab=posts")
  #expect(router.currentRoute == profile)
  #expect(router.matchedRoutes == [profile])
  #expect(router.currentParams?.get("lang") == "ja")
  #expect(router.location.queryString == "tab=posts")
}

@Test func routerStoresNestedMatchStack() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let users = routes._route("/users") { EmptyHTML() }
  let user = routes._route(":id", parent: users) { EmptyHTML() }
  let tree = try routes._build()
  let router = MemoryRouter(routes: tree, history: MemoryHistory(initialPath: "/users/42"))

  #expect(router.matchedRoutes == [users, user])
  #expect(router.currentParams?.get("id") == "42")
}

@Test func routerSupportsActiveMatchingOptions() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let users = routes._route("/users") { EmptyHTML() }
  let user = routes._route(":id", parent: users) { EmptyHTML() }
  let tree = try routes._build()
  let router = MemoryRouter(
    routes: tree,
    history: MemoryHistory(initialPath: "/users/42?tab=posts#details")
  )

  #expect(router.isActive(user))
  #expect(!router.isActive(users))
  #expect(router.isActive(users, options: .descendant))
  #expect(router.isActive(user, options: .init(params: ["id": 42])))
  #expect(
    router.isActive(
      user,
      options: .init(query: ["tab": "posts"])
    )
  )
  #expect(router.isActive(user, options: .init(hash: "details")))
  #expect(!router.isActive(user, options: .init(params: ["id": 7])))
}

@Test func routeTreeResolvesNotFoundThroughRoutePolicy() throws {
  let routes = RouteBuilder<EmptyHTML>()
  routes._route("/") { EmptyHTML() }
  var notFoundPath = ""
  func captureNotFound(_ context: RouteNotFoundContext) -> EmptyHTML {
    notFoundPath = context.location.path
    return EmptyHTML()
  }
  routes._notFound { context in
    captureNotFound(context)
  }
  let tree = try routes._build()

  if case .notFound(let context) = tree._resolve(RouteLocation(url: "/missing?q=swift")) {
    #expect(context.location.path == "/missing")
    #expect(context.query.get("q") == "swift")
  } else {
    Issue.record("Expected notFound resolution")
  }

  _ = try tree._render(RouteLocation(url: "/missing"))
  #expect(notFoundPath == "/missing")
}

@Test func routeTreeResolvesRouteValueErrorsThroughRoutePolicy() throws {
  let routes = RouteBuilder<EmptyHTML>()
  func requireProfileID(_ context: RouteContext) throws(RouteValueError) -> EmptyHTML {
    _ = try context.params.require("profileId", Int.self)
    return EmptyHTML()
  }
  routes._route("/profile/:profileId") { context throws(RouteValueError) in
    try requireProfileID(context)
  }
  var renderedError: RouteValueError?
  func captureError(_ context: RouteErrorContext) -> EmptyHTML {
    renderedError = context.error
    return EmptyHTML()
  }
  routes._error { context in
    captureError(context)
  }
  let tree = try routes._build()
  let expected = RouteValueError.invalid(name: "profileId", rawValue: "abc", expected: "Int")

  if case .error(let context) = tree._resolve(RouteLocation(url: "/profile/abc")) {
    #expect(context.error == expected)
    #expect(context.routeContext.params.get("profileId") == "abc")
    #expect(context.routeContext.matchedRoutes == [context.routeContext.route])
  } else {
    Issue.record("Expected error resolution")
  }

  _ = try tree._render(RouteLocation(url: "/profile/abc"))
  #expect(renderedError == expected)
}

@Test func routeTreeRenderReturnsMatchedRouteView() throws {
  let routes = RouteBuilder<EmptyHTML>()
  var renderedPath = ""
  routes._route("/docs/*") { context in
    renderedPath = context.params.get("*") ?? ""
    return EmptyHTML()
  }
  let tree = try routes._build()

  _ = try tree._render(RouteLocation(url: "/docs/guide/get-started"))

  #expect(renderedPath == "guide/get-started")
}

@Test func routeTreeEvaluatesNestedRouteBuildersFromParentToLeaf() throws {
  let routes = RouteBuilder<EmptyHTML>()
  var rendered: [String] = []
  let lang = routes._route("/:lang") { context throws(RouteValueError) in
    rendered.append("layout:\(try context.params.require("lang"))")
    return EmptyHTML()
  }
  let profile = routes._route("profile/:profileId", parent: lang) {
    context throws(RouteValueError) in
    rendered.append("profile:\(try context.params.require("profileId", Int.self))")
    return EmptyHTML()
  }
  let tree = try routes._build()

  if case .matched(let context) = tree._resolve(RouteLocation(url: "/ja/profile/42")) {
    #expect(context.route == profile)
    #expect(context.params.get("lang") == "ja")
    #expect(context.params.get("profileId") == "42")
  } else {
    Issue.record("Expected matched resolution")
  }

  #expect(rendered == ["layout:ja", "profile:42"])
}

@Test func routeTreeAllowsIndexRouteInsideRootLayout() throws {
  let routes = RouteBuilder<EmptyHTML>()
  var rendered: [String] = []
  let layout = routes._route("/") {
    rendered.append("layout")
    return EmptyHTML()
  }
  let index = routes._route("/", parent: layout) {
    rendered.append("index")
    return EmptyHTML()
  }
  let tree = try routes._build()

  if case .matched(let context) = tree._resolve(RouteLocation(url: "/")) {
    #expect(context.route == index)
    #expect(context.matchedRoutes == [layout, index])
  } else {
    Issue.record("Expected root index route")
  }

  rendered = []
  _ = try tree._render(RouteLocation(url: "/"))
  #expect(rendered == ["layout", "index"])
}

@Test func routeTreeReportsParentRouteValueErrorsBeforeRenderingChildren() throws {
  let routes = RouteBuilder<EmptyHTML>()
  var childRendered = false
  let account = routes._route("/accounts/:accountId") { context throws(RouteValueError) in
    _ = try context.params.require("accountId", Int.self)
    return EmptyHTML()
  }
  routes._route("settings", parent: account) {
    childRendered = true
    return EmptyHTML()
  }
  let tree = try routes._build()

  if case .error(let context) = tree._resolve(RouteLocation(url: "/accounts/abc/settings")) {
    #expect(context.error == .invalid(name: "accountId", rawValue: "abc", expected: "Int"))
    #expect(context.routeContext.route == account)
    #expect(context.routeContext.params.get("accountId") == "abc")
  } else {
    Issue.record("Expected parent route error")
  }

  #expect(!childRendered)
}

@Test func matcherRanksSegmentsFromLeftToRightRegardlessOfRegistrationOrder() throws {
  let declarations = [
    "/files", "/files/*", "/files/:name", "/files/new", "/:lang/profile/:id", "/docs/*", "/*",
  ]

  for ordered in [declarations, Array(declarations.reversed())] {
    let routes = RouteBuilder<EmptyHTML>()
    var handles: [String: RouteHandle] = [:]
    for path in ordered {
      handles[path] = routes._route(path) { EmptyHTML() }
    }
    let tree = try routes._build()

    func leaf(_ url: String) -> RouteHandle? {
      tree._match(RouteLocation(url: url))?.route
    }

    #expect(leaf("/files") == handles["/files"])
    #expect(leaf("/files/new") == handles["/files/new"])
    #expect(leaf("/files/readme") == handles["/files/:name"])
    #expect(leaf("/files/a/b") == handles["/files/*"])
    #expect(leaf("/docs/profile/1") == handles["/docs/*"])
    #expect(leaf("/ja/profile/1") == handles["/:lang/profile/:id"])
    #expect(leaf("/ja/other") == handles["/*"])
    #expect(leaf("/") == handles["/*"])
  }
}

private func buildError(
  _ declare: (RouteBuilder<EmptyHTML>) -> Void
) -> RouteTreeError? {
  let routes = RouteBuilder<EmptyHTML>()
  declare(routes)
  do throws(RouteTreeError) {
    _ = try routes._build()
    return nil
  } catch {
    return error
  }
}

@Test func routeBuilderRejectsStructurallyIndistinguishableRoutes() {
  #expect(
    buildError { routes in
      routes._route("/users/:id") { EmptyHTML() }
      routes._route("/users/:name") { EmptyHTML() }
    } == .ambiguousRoute(path: "/users/:name", conflictingPath: "/users/:id")
  )

  #expect(
    buildError { routes in
      routes._route("/caf%C3%A9") { EmptyHTML() }
      routes._route("/café") { EmptyHTML() }
    } == .ambiguousRoute(path: "/café", conflictingPath: "/caf%C3%A9")
  )

  #expect(
    buildError { routes in
      routes._route("/files/*") { EmptyHTML() }
      routes._route("/files/*/") { EmptyHTML() }
    } == .duplicateRoute(path: "/files/*")
  )

  #expect(
    buildError { routes in
      let teams = routes._layout("/teams", parent: nil) { EmptyHTML() }
      routes._route(":id", parent: teams) { EmptyHTML() }
      routes._route("/teams/:teamID") { EmptyHTML() }
    } == .ambiguousRoute(path: "/teams/:teamID", conflictingPath: "/teams/:id")
  )

  #expect(
    buildError { routes in
      routes._layout("/:lang", parent: nil) { EmptyHTML() }
      routes._layout("/:locale", parent: nil) { EmptyHTML() }
    } == .ambiguousRoute(path: "/:locale", conflictingPath: "/:lang")
  )
}

@Test func routeBuilderAcceptsRoutesSeparatedByPrecedence() {
  #expect(
    buildError { routes in
      routes._route("/users") { EmptyHTML() }
      routes._route("/users/new") { EmptyHTML() }
      routes._route("/users/:id") { EmptyHTML() }
      routes._route("/users/*") { EmptyHTML() }
      routes._route("/:section/new") { EmptyHTML() }
    } == nil
  )
}

@Test func routeBuilderRejectsWildcardsBeforeTheLastSegment() {
  #expect(
    buildError { routes in
      routes._route("/files/*/raw") { EmptyHTML() }
    } == .invalidWildcard(path: "/files/*/raw")
  )

  #expect(
    buildError { routes in
      let docs = routes._route("/docs/*") { EmptyHTML() }
      routes._route("edit", parent: docs) { EmptyHTML() }
    } == .invalidWildcard(path: "/docs/*/edit")
  )
}

@Test func matcherComparesPercentDecodedLiteralSegments() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let cafe = routes._route("/café/menu") { EmptyHTML() }
  let docs = routes._route("/my%20docs/:page") { EmptyHTML() }
  let tree = try routes._build()

  #expect(tree._match(RouteLocation(url: "/caf%C3%A9/menu"))?.route == cafe)
  #expect(tree._match(RouteLocation(url: "/caf%c3%a9/menu"))?.route == cafe)
  #expect(tree._match(RouteLocation(url: "/café/menu"))?.route == cafe)
  #expect(tree._match(RouteLocation(url: "/cafe/menu")) == nil)
  #expect(tree._match(RouteLocation(url: "/my%20docs/intro"))?.route == docs)
  #expect(tree._match(RouteLocation(url: "/my docs/intro"))?.params.get("page") == "intro")

  #expect(try tree._href(to: cafe) == "/caf%C3%A9/menu")
  #expect(try tree._href(to: docs, params: ["page": "intro"]) == "/my%20docs/intro")
}

@Test func hrefAndMatchRoundTripEncodedValues() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let item = routes._route("/items/:name") { EmptyHTML() }
  let files = routes._route("/files/*") { EmptyHTML() }
  let tree = try routes._build()

  for value in ["a b", "a/b", "100%", "x+y", "what?", "tag#1", "café", "%2F", "a&b=c"] {
    let href = try tree._href(
      to: item,
      params: RouteValues().set("name", value),
      query: RouteValues().set("q", value),
      hash: value
    )
    let location = RouteLocation(url: href)
    let match = tree._match(location)

    #expect(match?.route == item, "\(href)")
    #expect(match?.params.get("name") == value, "\(href)")
    #expect(QueryString.parse(location.queryString).get("q") == value, "\(href)")
    #expect(URLCoding.decode(location.hash, plusIsSpace: false) == value, "\(href)")
  }

  for splat in ["docs/readme", "a b/c%d", "café/menu"] {
    let href = try tree._href(to: files, params: RouteValues().set("*", splat))
    #expect(tree._match(RouteLocation(url: href))?.params.get("*") == splat, "\(href)")
  }

  #expect(try tree._href(to: files, params: ["*": ""]) == "/files")
  #expect(tree._match(RouteLocation(url: "/files"))?.params.get("*") == "")

  #expect(throws: RouteMatchError.missingRequiredParameter(name: "name")) {
    try tree._href(to: item, params: ["name": ""])
  }
}

@Test func activeHashMatchingComparesDecodedFragments() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let section = routes._route("/guide") { EmptyHTML() }
  let tree = try routes._build()
  let router = MemoryRouter(routes: tree, history: MemoryHistory(initialPath: "/"))

  try router.navigate(to: section, hash: "getting started")

  #expect(router.location.hash == "getting%20started")
  #expect(router.isActive(section, options: .init(hash: "getting started")))
  #expect(!router.isActive(section, options: .init(hash: "getting")))
}

@Test func hashRouterHrefsAreFragmentsThatResolveToPushedURLs() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let home = routes._route("/") { EmptyHTML() }
  let user = routes._route("/users/:id") { EmptyHTML() }
  let tree = try routes._build()
  let document = MemoryHistory(initialPath: "/app/?lang=en")
  let router = HistoryRouter(routes: tree, history: HashHistory(base: document))

  #expect(router.currentRoute == home)

  let href = try router.href(to: user, params: ["id": 42], query: ["tab": "posts"], hash: "bio")
  #expect(href == "#/users/42?tab=posts#bio")

  try router.navigate(to: user, params: ["id": 42], query: ["tab": "posts"], hash: "bio")

  // A fragment-only href resolves against the document's base path and query string, so normal
  // clicks, modified clicks, and copied links all reach the URL that client navigation pushes.
  #expect(document.location.href == "/app/?lang=en" + href)
  #expect(router.location.href == "/users/42?tab=posts#bio")
  #expect(router.currentRoute == user)
  #expect(router.currentParams?.get("id") == "42")
  #expect(router.isActive(user, options: .init(query: ["tab": "posts"], hash: "bio")))

  router.back()
  #expect(document.location.href == "/app/?lang=en")
  #expect(router.currentRoute == home)
}

@Test func hashRouterHrefsAreNotDoubleEncoded() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let user = routes._route("/users/:id") { EmptyHTML() }
  let tree = try routes._build()
  let document = MemoryHistory(initialPath: "/")
  let router = HistoryRouter(routes: tree, history: HashHistory(base: document))
  let params = RouteValues().set("id", "a b/c")

  let href = try router.href(to: user, params: params, query: ["q": "x y"], hash: "x y")
  #expect(href == "#/users/a%20b%2Fc?q=x+y#x%20y")
  #expect(!href.contains("%25"))

  try router.navigate(to: user, params: params, query: ["q": "x y"], hash: "x y")
  #expect(document.location.href == "/" + href)
  #expect(router.currentParams?.get("id") == "a b/c")
  #expect(QueryString.parse(router.location.queryString).get("q") == "x y")
}

@Test func hashRouterReadsDeepLinksFromTheDocumentFragment() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let user = routes._route("/users/:id") { EmptyHTML() }
  let tree = try routes._build()
  let router = HistoryRouter(
    routes: tree,
    history: HashHistory(base: MemoryHistory(initialPath: "/app/?lang=en#/users/7?tab=posts#bio"))
  )

  #expect(router.currentRoute == user)
  #expect(router.currentParams?.get("id") == "7")
  #expect(router.location.queryString == "tab=posts")
  #expect(router.location.hash == "bio")
}

@Test func pathRouterHrefsStayAbsolutePaths() throws {
  let routes = RouteBuilder<EmptyHTML>()
  let user = routes._route("/users/:id") { EmptyHTML() }
  let tree = try routes._build()
  let router = MemoryRouter(routes: tree, history: MemoryHistory(initialPath: "/"))

  #expect(
    try router.href(to: user, params: ["id": 42], query: ["tab": "posts"], hash: "bio")
      == "/users/42?tab=posts#bio"
  )
}

@Test func generatedHashRouteSetHrefsMatchHashRouterHrefs() throws {
  let routeSet = try HashMacroRoutes.routes()
  let router = HistoryRouter(
    routes: routeSet.tree,
    history: HashHistory(base: MemoryHistory(initialPath: "/app/"))
  )

  #expect(try routeSet.homeHref() == "#/")
  #expect(try routeSet.userHref(id: 42, tab: "posts", hash: "bio") == "#/users/42?tab=posts#bio")
  #expect(
    try routeSet.userHref(id: 42, tab: "posts", hash: "bio")
      == router.href(
        to: routeSet.handles.user,
        params: ["id": 42],
        query: ["tab": "posts"],
        hash: "bio"
      )
  )
}
