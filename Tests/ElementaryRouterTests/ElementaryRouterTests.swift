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
  static func user(id: Int) -> EmptyHTML {
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

@Test func routesMacroGeneratesRouteSetAndTypedRouteView() throws {
  let routeSet = try MacroRoutes.routes()
  let router = Router(routes: routeSet.tree, history: MemoryHistory(initialPath: "/users/42"))

  #expect(router.currentMatch?.route == routeSet.handles.user)
  #expect(router.currentMatch?.params.get("id") == "42")
  #expect(
    try router.href(to: routeSet.handles.file, params: ["*": "docs/readme"]) == "/files/docs/readme"
  )
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
  let routes = RouteCollection<EmptyHTML>()
  let user = routes.route("/users/:id") { EmptyHTML() }
  let newUser = routes.route("/users/new") { EmptyHTML() }
  let tree = try routes.freeze()

  #expect(tree.match(RouteLocation(url: "/users/new"))?.route == newUser)

  let match = tree.match(RouteLocation(url: "/users/42"))
  #expect(match?.route == user)
  #expect(match?.params.get("id") == "42")
}

@Test func matcherSupportsWildcardRoutes() throws {
  let routes = RouteCollection<EmptyHTML>()
  let files = routes.route("/files/*") { EmptyHTML() }
  let tree = try routes.freeze()

  let match = tree.match(RouteLocation(url: "/files/docs/readme"))
  #expect(match?.route == files)
  #expect(match?.params.get("*") == "docs/readme")
}

@Test func matcherBuildsNestedMatchStack() throws {
  let routes = RouteCollection<EmptyHTML>()
  let users = routes.route("/users") { EmptyHTML() }
  let user = routes.children(of: users).route(":id") { EmptyHTML() }
  let settings = routes.children(of: user).route("settings") { EmptyHTML() }
  let tree = try routes.freeze()

  let matches = tree.matches(RouteLocation(url: "/users/42/settings"))

  #expect(matches.map(\.route) == [users, user, settings])
  #expect(matches.map(\.path) == ["/users", "/users/:id", "/users/:id/settings"])
  #expect(matches[1].params.get("id") == "42")
  #expect(matches[2].params.get("id") == "42")
}

@Test func routeTreeBuildsHrefFromParamsAndQuery() throws {
  let routes = RouteCollection<EmptyHTML>()
  let profile = routes.route("/:lang/profile/:profileId") { EmptyHTML() }
  let tree = try routes.freeze()

  let href = try tree.href(
    to: profile,
    params: ["lang": "ja", "profileId": 42],
    query: ["tab": "posts"]
  )

  #expect(href == "/ja/profile/42?tab=posts")
}

@Test func routeTreeReportsUnknownRouteHandles() throws {
  let routes = RouteCollection<EmptyHTML>()
  routes.route("/") { EmptyHTML() }
  let tree = try routes.freeze()
  let unknown = RouteHandle(id: RouteID(rawValue: 999))

  #expect(throws: RouteMatchError.unknownRoute) {
    try tree.href(to: unknown)
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
  let routes = RouteCollection<EmptyHTML>()
  let home = routes.route("/") { EmptyHTML() }
  let profile = routes.route("/:lang/profile/:profileId") { EmptyHTML() }
  let tree = try routes.freeze()
  let history = MemoryHistory(initialPath: "/")
  let router = Router(routes: tree, history: history)

  #expect(router.currentMatch?.route == home)

  try router.navigate(
    to: profile,
    params: ["lang": "ja", "profileId": 42],
    query: ["tab": "posts"]
  )

  #expect(router.location.href == "/ja/profile/42?tab=posts")
  #expect(router.currentMatch?.route == profile)
  #expect(router.matches.map(\.route) == [profile])
  #expect(router.currentMatch?.params.get("lang") == "ja")
  #expect(router.location.queryString == "tab=posts")
}

@Test func routerStoresNestedMatchStack() throws {
  let routes = RouteCollection<EmptyHTML>()
  let users = routes.route("/users") { EmptyHTML() }
  let user = routes.children(of: users).route(":id") { EmptyHTML() }
  let tree = try routes.freeze()
  let router = Router(routes: tree, history: MemoryHistory(initialPath: "/users/42"))

  #expect(router.matches.map(\.route) == [users, user])
  #expect(router.currentMatch?.params.get("id") == "42")
}

@Test func routeTreeResolvesNotFoundThroughRoutePolicy() throws {
  let routes = RouteCollection<EmptyHTML>()
  routes.route("/") { EmptyHTML() }
  var notFoundPath = ""
  func captureNotFound(_ context: RouteNotFoundContext) -> EmptyHTML {
    notFoundPath = context.location.path
    return EmptyHTML()
  }
  routes.notFound { context in
    captureNotFound(context)
  }
  let tree = try routes.freeze()

  if case .notFound(let context) = tree.resolve(RouteLocation(url: "/missing?q=swift")) {
    #expect(context.location.path == "/missing")
    #expect(context.query.get("q") == "swift")
  } else {
    Issue.record("Expected notFound resolution")
  }

  _ = try tree.render(RouteLocation(url: "/missing"))
  #expect(notFoundPath == "/missing")
}

@Test func routeTreeResolvesRouteValueErrorsThroughRoutePolicy() throws {
  let routes = RouteCollection<EmptyHTML>()
  func requireProfileID(_ context: RouteContext) throws(RouteValueError) -> EmptyHTML {
    _ = try context.params.require("profileId", Int.self)
    return EmptyHTML()
  }
  routes.route("/profile/:profileId") { context throws(RouteValueError) in
    try requireProfileID(context)
  }
  var renderedError: RouteValueError?
  func captureError(_ context: RouteErrorContext) -> EmptyHTML {
    renderedError = context.error
    return EmptyHTML()
  }
  routes.error { context in
    captureError(context)
  }
  let tree = try routes.freeze()
  let expected = RouteValueError.invalid(name: "profileId", rawValue: "abc", expected: "Int")

  if case .error(let context) = tree.resolve(RouteLocation(url: "/profile/abc")) {
    #expect(context.error == expected)
    #expect(context.routeContext.match.params.get("profileId") == "abc")
    #expect(context.routeContext.matches.map(\.route) == [context.routeContext.match.route])
  } else {
    Issue.record("Expected error resolution")
  }

  _ = try tree.render(RouteLocation(url: "/profile/abc"))
  #expect(renderedError == expected)
}

@Test func routeTreeRenderReturnsMatchedRouteView() throws {
  let routes = RouteCollection<EmptyHTML>()
  var renderedPath = ""
  routes.route("/docs/*") { context in
    renderedPath = context.params.get("*") ?? ""
    return EmptyHTML()
  }
  let tree = try routes.freeze()

  _ = try tree.render(RouteLocation(url: "/docs/guide/get-started"))

  #expect(renderedPath == "guide/get-started")
}

@Test func routeTreeEvaluatesNestedRouteBuildersFromParentToLeaf() throws {
  let routes = RouteCollection<EmptyHTML>()
  var rendered: [String] = []
  let lang = routes.route("/:lang") { context throws(RouteValueError) in
    rendered.append("layout:\(try context.params.require("lang"))")
    return EmptyHTML()
  }
  let profile = routes.children(of: lang).route("profile/:profileId") {
    context throws(RouteValueError) in
    rendered.append("profile:\(try context.params.require("profileId", Int.self))")
    return EmptyHTML()
  }
  let tree = try routes.freeze()

  if case .matched(let context) = tree.resolve(RouteLocation(url: "/ja/profile/42")) {
    #expect(context.match.route == profile)
    #expect(context.params.get("lang") == "ja")
    #expect(context.params.get("profileId") == "42")
  } else {
    Issue.record("Expected matched resolution")
  }

  #expect(rendered == ["layout:ja", "profile:42"])
}

@Test func routeTreeReportsParentRouteValueErrorsBeforeRenderingChildren() throws {
  let routes = RouteCollection<EmptyHTML>()
  var childRendered = false
  let account = routes.route("/accounts/:accountId") { context throws(RouteValueError) in
    _ = try context.params.require("accountId", Int.self)
    return EmptyHTML()
  }
  routes.children(of: account).route("settings") {
    childRendered = true
    return EmptyHTML()
  }
  let tree = try routes.freeze()

  if case .error(let context) = tree.resolve(RouteLocation(url: "/accounts/abc/settings")) {
    #expect(context.error == .invalid(name: "accountId", rawValue: "abc", expected: "Int"))
    #expect(context.routeContext.match.route == account)
    #expect(context.routeContext.params.get("accountId") == "abc")
  } else {
    Issue.record("Expected parent route error")
  }

  #expect(!childRendered)
}
