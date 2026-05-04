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
}

@Test func routeParametersExtractsStringsAndTypedValues() throws {
  let values: RouteParameters = ["lang": "ja", "profileId": 42]

  #expect(try values.require("lang") == "ja")
  #expect(try values.require("profileId", Int.self) == 42)
  #expect(values.get("profileId") == "42")
  #expect(values.get("profileId", Int.self) == 42)
}

@Test func routeParametersSupportsInitializerLists() throws {
  let values = RouteParameters(("lang", "ja"), ("profileId", 42), ("enabled", true))

  #expect(try values.require("lang") == "ja")
  #expect(try values.require("profileId", Int.self) == 42)
  #expect(try values.require("enabled", Bool.self))
}

@Test func routeParametersReportsMissingAndInvalidValues() {
  let values: RouteParameters = ["profileId": "abc"]

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
  let values = RouteParameters()
    .append("tag", "swift")
    .append("tag", "wasm")
    .set("q", "hello world")

  #expect(QueryString.stringify(values) == "tag=swift&tag=wasm&q=hello+world")
}

@Test func matcherPrefersStaticRoutesOverDynamicRoutes() throws {
  let routes = _RouteBuilder<EmptyHTML>()
  let user = routes._route("/users/:id") { EmptyHTML() }
  let newUser = routes._route("/users/new") { EmptyHTML() }
  let tree = try routes._build()

  #expect(tree._match(RouteLocation(url: "/users/new"))?.route == newUser)

  let match = tree._match(RouteLocation(url: "/users/42"))
  #expect(match?.route == user)
  #expect(match?.params.get("id") == "42")
}

@Test func matcherSupportsWildcardRoutes() throws {
  let routes = _RouteBuilder<EmptyHTML>()
  let files = routes._route("/files/*") { EmptyHTML() }
  let tree = try routes._build()

  let match = tree._match(RouteLocation(url: "/files/docs/readme"))
  #expect(match?.route == files)
  #expect(match?.params.get("*") == "docs/readme")
}

@Test func matcherBuildsNestedMatchStack() throws {
  let routes = _RouteBuilder<EmptyHTML>()
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
  let routes = _RouteBuilder<EmptyHTML>()
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
  let routes = _RouteBuilder<EmptyHTML>()
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
  let routes = _RouteBuilder<EmptyHTML>()
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
  let routes = _RouteBuilder<EmptyHTML>()
  let users = routes._route("/users") { EmptyHTML() }
  let user = routes._route(":id", parent: users) { EmptyHTML() }
  let tree = try routes._build()
  let router = MemoryRouter(routes: tree, history: MemoryHistory(initialPath: "/users/42"))

  #expect(router.matchedRoutes == [users, user])
  #expect(router.currentParams?.get("id") == "42")
}

@Test func routerSupportsActiveMatchingOptions() throws {
  let routes = _RouteBuilder<EmptyHTML>()
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
  let routes = _RouteBuilder<EmptyHTML>()
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
  let routes = _RouteBuilder<EmptyHTML>()
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
  let routes = _RouteBuilder<EmptyHTML>()
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
  let routes = _RouteBuilder<EmptyHTML>()
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

@Test func routeTreeReportsParentRouteValueErrorsBeforeRenderingChildren() throws {
  let routes = _RouteBuilder<EmptyHTML>()
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
