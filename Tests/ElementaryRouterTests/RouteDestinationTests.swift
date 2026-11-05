import ElementaryUI
import Testing

@testable import ElementaryRouter

// A public route group compiled in this downstream module, so the generated public destination
// factories, `Link`, `Provider`, and `RouterView` must all type-check with public access.

/// A custom path value that only accepts lowercase words separated by `-`.
public struct Slug: RouteValue, Equatable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public static var routeValueTypeName: String { "Slug" }

  public static func parseRouteValue(_ rawValue: String) -> Slug? {
    guard !rawValue.isEmpty,
      rawValue.allSatisfy({ $0.isLowercase || $0.isNumber || $0 == "-" })
    else {
      return nil
    }
    return Slug(rawValue)
  }

  public var routeValueString: String { rawValue }
}

/// A custom query value. `draft` encodes to a string the route does not accept.
public enum SortOrder: String, RouteValue, Equatable {
  case newest
  case oldest
  case draft

  public static var routeValueTypeName: String { "SortOrder" }

  public static func parseRouteValue(_ rawValue: String) -> SortOrder? {
    switch rawValue {
    case "newest": .newest
    case "oldest": .oldest
    default: nil
    }
  }

  public var routeValueString: String { rawValue }
}

@View
public struct ArticleShell<Content: View> {
  let outlet: Outlet<Content>

  public init(outlet: Outlet<Content>) {
    self.outlet = outlet
  }

  public var body: some View {
    outlet
  }
}

@Routes
public struct ArticleRoutes {
  @Layout("/")
  public static func shell<Content: View>(outlet: Outlet<Content>) -> ArticleShell<Content> {
    ArticleShell(outlet: outlet)
  }

  @Route("/")
  public static func home(page: Query<Int> = Query(1)) -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/search")
  public static func search(q: Query<String>) -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/articles/new")
  public static func newArticle() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/articles/:slug")
  public static func article(slug: Slug, sort: Query<SortOrder> = Query(.newest)) -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/users/:name")
  public static func user(name: String) -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/docs")
  public static func docsIndex() -> EmptyHTML {
    EmptyHTML()
  }

  @Route("/docs/*")
  public static func docs(path: Wildcard) -> EmptyHTML {
    EmptyHTML()
  }

  @NotFound
  public static func notFound(context: RouteNotFoundContext) -> EmptyHTML {
    EmptyHTML()
  }

  @RouteError
  public static func routeError(context: RouteErrorContext) -> EmptyHTML {
    EmptyHTML()
  }
}

private func pathRouter(
  _ routes: ArticleRoutes.RouteSet,
  history: MemoryHistory = MemoryHistory()
) -> Router<ArticleRoutes.RouteView> {
  Router(routes: routes.tree, history: BrowserHistory(history: history))
}

private func hashRouter(
  _ routes: ArticleRoutes.RouteSet,
  document: MemoryHistory = MemoryHistory(initialPath: "/app/")
) -> HashRouter<ArticleRoutes.RouteView> {
  HashRouter(routes: routes.tree, history: BrowserHistory(history: document))
}

@Test func destinationFactoriesEncodeDeclaredValues() throws {
  let routes = try ArticleRoutes.routes()

  // Static routes with built-in query types have non-throwing factories, so no `try` is needed.
  let home: RouteDestination<ArticleRoutes.RouteView> = routes.home()
  #expect(home.route == routes.handles.home)
  #expect(home.location.href == "/")
  #expect(routes.home(page: 2).location.href == "/?page=2")
  #expect(routes.search(q: "swift wasm").location.href == "/search?q=swift+wasm")

  let article = try routes.article(slug: Slug("hello-world"), sort: .oldest, hash: "comments")
  #expect(article.route == routes.handles.article)
  #expect(article.location.href == "/articles/hello-world?sort=oldest#comments")
  #expect(article.params.get("slug", Slug.self) == Slug("hello-world"))
  #expect(article.query.get("sort", SortOrder.self) == .oldest)
  #expect(article.hash == "comments")
  #expect(try routes.href(to: article) == "/articles/hello-world?sort=oldest#comments")

  let docs = try routes.docs(path: "guide/get-started")
  #expect(docs.location.href == "/docs/guide/get-started")
  #expect(docs.params.get("*") == "guide/get-started")
}

@Test func omittedQueryDefaultsStayOutOfTheURLAndRenderTheirDefault() throws {
  let routes = try ArticleRoutes.routes()
  let router = pathRouter(routes)
  let implicit = try routes.article(slug: Slug("intro"))
  let explicit = try routes.article(slug: Slug("intro"), sort: .newest)

  #expect(implicit.location.href == "/articles/intro")
  #expect(implicit.query.pairs.isEmpty)
  #expect(explicit.location.href == "/articles/intro?sort=newest")
  #expect(implicit != explicit)

  try router.navigate(to: implicit)
  let rendered = try router.renderCurrentRoute()
  if case .shell(outlet: let shell) = rendered.storage,
    case .article(let slug, let sort) = shell.storage
  {
    #expect(slug == Slug("intro"))
    #expect(sort == .newest)
  } else {
    Issue.record("Expected the article route to render, got \(rendered.storage)")
  }

  // Active checks compare the query values a destination writes, not omitted defaults.
  #expect(router.isActive(implicit))
  #expect(!router.isActive(explicit))
  #expect(router.isActive(explicit, includeQuery: false))

  try router.navigate(to: explicit)
  #expect(router.isActive(implicit))
  #expect(router.isActive(explicit))
  #expect(try !router.isActive(routes.article(slug: Slug("intro"), sort: .oldest)))
  #expect(try router.isActive(routes.article(slug: Slug("intro"), sort: .oldest), includeQuery: false))
  #expect(try !router.isActive(routes.article(slug: Slug("other")), includeQuery: false))
}

@Test func destinationFactoriesRejectValuesWithoutARoutableURL() throws {
  let routes = try ArticleRoutes.routes()

  // A custom path value that its own type cannot decode again.
  #expect(throws: RouteMatchError.invalidValue(name: "slug", rawValue: "Hello World", expected: "Slug")) {
    try routes.article(slug: Slug("Hello World"))
  }
  // A custom query value that its own type cannot decode again.
  #expect(throws: RouteMatchError.invalidValue(name: "sort", rawValue: "draft", expected: "SortOrder")) {
    try routes.article(slug: Slug("intro"), sort: .draft)
  }
  // An empty segment would collapse and the URL would no longer reach the route.
  #expect(throws: RouteMatchError.missingRequiredParameter(name: "name")) {
    try routes.user(name: "")
  }
  // Static siblings take precedence over the dynamic segment and the wildcard.
  #expect(throws: RouteMatchError.unroutableLocation(href: "/articles/new")) {
    try routes.article(slug: Slug("new"))
  }
  #expect(throws: RouteMatchError.unroutableLocation(href: "/docs")) {
    try routes.docs(path: "")
  }
  // A lone `/` is an empty component on each side, which would collapse instead of reaching `/docs/*`.
  #expect(throws: RouteMatchError.invalidPathSegment(name: "*", value: "/")) {
    try routes.docs(path: "/")
  }
}

@Test func dotSegmentPathValuesAreRejectedInBothModes() throws {
  let routes = try ArticleRoutes.routes()
  let path = pathRouter(routes)
  let hash = hashRouter(routes)

  // Browsers resolve `.` and `..`, so `/users/..` would load `/` while validation saw `user`.
  for value in [".", ".."] {
    #expect(throws: RouteMatchError.invalidPathSegment(name: "name", value: value)) {
      try routes.user(name: value)
    }
    #expect(throws: RouteMatchError.invalidPathSegment(name: "name", value: value)) {
      try path.navigate(to: routes.handles.user, params: RouteValues().set("name", value))
    }
    #expect(throws: RouteMatchError.invalidPathSegment(name: "name", value: value)) {
      try hash.href(to: routes.handles.user, params: RouteValues().set("name", value))
    }
  }

  // Dots inside a segment, encoded `%2E` text, encoded slashes, and unicode are kept as values.
  for value in ["...", ".hidden", "a.b", "..x", "%2E", "%2E%2E", "../etc", "a/b", "café"] {
    let destination = try routes.user(name: value)
    try path.navigate(to: destination)
    try hash.navigate(to: destination)
    #expect(path.currentParams?.get("name") == value, "\(destination.location.href)")
    #expect(hash.currentParams?.get("name") == value, "\(destination.location.href)")
    #expect(path.isActive(destination))
    #expect(hash.isActive(destination))
  }
  #expect(try routes.user(name: "%2E%2E").location.href == "/users/%252E%252E")
  #expect(try routes.user(name: "../etc").location.href == "/users/..%2Fetc")
}

@Test func wildcardValuesWithDotOrEmptyComponentsAreRejected() throws {
  let routes = try ArticleRoutes.routes()

  for value in [
    ".", "..", "a/../b", "a/./b", "a/..", "../a", "a/.",
    "a//b", "/a", "a/", "//", "a/b//",
  ] {
    #expect(throws: RouteMatchError.invalidPathSegment(name: "*", value: value)) {
      try routes.docs(path: value)
    }
  }

  // The low-level handle API shares the same boundary.
  let router = hashRouter(routes)
  #expect(throws: RouteMatchError.invalidPathSegment(name: "*", value: "a/../b")) {
    try router.navigate(to: routes.handles.docs, params: RouteValues().set("*", "a/../b"))
  }

  let path = pathRouter(routes)
  for value in ["a/.../b", "a/.b/c", "guide/%2E%2E/x", "a%2Fb/c", "café/menu"] {
    let destination = try routes.docs(path: value)
    try path.navigate(to: destination)
    #expect(path.currentParams?.get("*") == value, "\(destination.location.href)")
    #expect(path.isActive(destination))
  }
  #expect(try routes.docs(path: "a%2Fb/c").location.href == "/docs/a%252Fb/c")
}

@Test func rawDotSegmentLocationsMatchNoRouteInMemoryHistory() throws {
  let routes = try ArticleRoutes.routes()
  let path = pathRouter(routes)
  let document = MemoryHistory(initialPath: "/app/")
  let hash = hashRouter(routes, document: document)

  // Both routers here sit on `MemoryHistory`, which stores raw locations unchanged, so the dot
  // segments reach the matcher and it rejects them. A real browser in path mode normalizes dot
  // segments before the router sees them (`/users/..` becomes `/`) and may land on a matching
  // route; that browser behavior is not exercised here.
  for raw in ["/users/..", "/users/.", "/users/%2E%2E", "/users/.%2e", "/docs/a/../b", "/docs/./b"] {
    path.navigate(to: RouteLocation(url: raw))
    hash.navigate(to: RouteLocation(url: raw))
    #expect(path.matchedRoutes.isEmpty, "\(raw)")
    #expect(hash.matchedRoutes.isEmpty, "\(raw)")
    #expect(document.location.href == "/app/#" + raw)

    let rendered = try path.renderCurrentRoute()
    if case .notFound(let context) = rendered.storage {
      #expect(context.location.path == raw)
    } else {
      Issue.record("Expected not-found for \(raw), got \(rendered.storage)")
    }
  }
}

@Test func staticDotSegmentPatternsAreRejected() {
  for declared in ["/a/./b", "/..", "/files/%2E%2E", "/files/.%2e/raw"] {
    let routes = RouteBuilder<EmptyHTML>()
    routes._route(declared) { EmptyHTML() }
    do throws(RouteTreeError) {
      _ = try routes._build()
      Issue.record("Expected \(declared) to be rejected")
    } catch {
      #expect(error == .dotSegment(path: declared))
    }
  }

  let nested = RouteBuilder<EmptyHTML>()
  let parent = nested._layout("/files", parent: nil) { EmptyHTML() }
  nested._route("..", parent: parent) { EmptyHTML() }
  do throws(RouteTreeError) {
    _ = try nested._build()
    Issue.record("Expected a nested dot segment to be rejected")
  } catch {
    #expect(error == .dotSegment(path: "/files/.."))
  }
}

@Test func shadowedLayoutRoutesAreRejected() throws {
  let routes = try NestedLayoutRoutes.routes()

  // `/docs/*` outranks `/:lang/...`, so `lang: "docs"` cannot reach the member route.
  #expect(throws: RouteMatchError.unroutableLocation(href: "/docs/teams/7/members/42")) {
    try routes.member(lang: "docs", teamID: 7, memberID: 42)
  }
  #expect(try routes.member(lang: "en", teamID: 7, memberID: 42).location.href == "/en/teams/7/members/42")
}

@Test func destinationsDriveNavigationReplaceAndActiveChecksInPathMode() throws {
  let routes = try ArticleRoutes.routes()
  let history = MemoryHistory()
  let router = pathRouter(routes, history: history)
  var updates: [HistoryUpdate] = []
  let subscription = history.listen { updates.append($0) }
  let user = try routes.user(name: "ada", hash: "bio")
  let search = routes.search(q: "router")

  #expect(try router.href(to: user) == "/users/ada#bio")
  try router.navigate(to: user)
  #expect(router.location.href == "/users/ada#bio")
  #expect(router.matchedRoutes == [routes.handles.shell, routes.handles.user])
  #expect(router.currentRoute == user.route)
  #expect(router.isActive(user))
  #expect(router.isActive(user, includeHash: true))
  #expect(try router.isActive(routes.user(name: "ada")))
  #expect(try !router.isActive(routes.user(name: "ada"), includeHash: true))
  #expect(try !router.isActive(routes.user(name: "grace")))
  #expect(router.isActive(routes.handles.shell, options: .descendant))

  try router.replace(to: search)
  #expect(router.location.href == "/search?q=router")
  #expect(router.isActive(search))
  #expect(!router.isActive(user))

  try router.navigate(to: routes.home(), replace: true)
  #expect(router.currentRoute == routes.handles.home)
  #expect(updates.map(\.action) == [.push, .replace, .replace])

  router.back()
  #expect(router.location.href == "/")
  subscription.cancel()
}

@Test func destinationsDriveNavigationAndActiveChecksInHashMode() throws {
  let routes = try ArticleRoutes.routes()
  let document = MemoryHistory(initialPath: "/app/?lang=en")
  let router = hashRouter(routes, document: document)
  let article = try routes.article(slug: Slug("intro"), sort: .oldest, hash: "comments")

  #expect(try router.href(to: article) == "#/articles/intro?sort=oldest#comments")
  try router.navigate(to: article)
  #expect(document.location.href == "/app/?lang=en#/articles/intro?sort=oldest#comments")
  #expect(router.location == article.location)
  #expect(router.matchedRoutes == [routes.handles.shell, routes.handles.article])
  #expect(router.isActive(article, includeHash: true))

  try router.replace(to: routes.docs(path: "guide/intro"))
  #expect(document.location.href == "/app/?lang=en#/docs/guide/intro")
  #expect(router.currentParams?.get("*") == "guide/intro")

  router.back()
  #expect(document.location.href == "/app/?lang=en")
  #expect(router.currentRoute == routes.handles.home)
}

@Test func destinationsRoundTripEncodedValuesInBothModes() throws {
  let routes = try ArticleRoutes.routes()

  for value in ["a b", "a/b", "100%", "x+y", "what?", "tag#1", "café", "%2F", "a&b=c"] {
    let destination = try routes.user(name: value, hash: value)
    let search = routes.search(q: value)
    let path = pathRouter(routes)
    let document = MemoryHistory(initialPath: "/app/")
    let hash = hashRouter(routes, document: document)

    try path.navigate(to: destination)
    try hash.navigate(to: destination)
    #expect(try hash.href(to: destination) == "#" + destination.location.href)
    #expect(document.location.href == "/app/#" + destination.location.href)

    for (params, isActive) in [
      (path.currentParams, path.isActive(destination, includeHash: true)),
      (hash.currentParams, hash.isActive(destination, includeHash: true)),
    ] {
      #expect(params?.get("name") == value, "\(destination.location.href)")
      #expect(isActive, "\(destination.location.href)")
    }

    let rendered = try hash.renderCurrentRoute()
    if case .shell(outlet: let shell) = rendered.storage, case .user(let name) = shell.storage {
      #expect(name == value)
    } else {
      Issue.record("Expected the user route for \(value), got \(rendered.storage)")
    }

    try path.navigate(to: search)
    let renderedSearch = try path.renderCurrentRoute()
    if case .shell(outlet: let shell) = renderedSearch.storage, case .search(let q) = shell.storage {
      #expect(q == value)
    } else {
      Issue.record("Expected the search route for \(value), got \(renderedSearch.storage)")
    }
  }

  for splat in ["docs/readme", "a b/c%d", "café/menu"] {
    let destination = try routes.docs(path: splat)
    let router = pathRouter(routes)
    try router.navigate(to: destination)
    #expect(router.currentParams?.get("*") == splat)
    #expect(router.isActive(destination))
  }
}

@Test func destinationsFromAnotherRegistrationAreRejected() throws {
  let foreign = try ArticleRoutes.routes()
  let routes = try ArticleRoutes.routes()
  let history = MemoryHistory(initialPath: "/users/ada")
  let router = pathRouter(routes, history: history)
  let hash = hashRouter(routes)
  var updates: [HistoryUpdate] = []
  let subscription = history.listen { updates.append($0) }

  let foreignUser = try foreign.user(name: "ada")
  let user = try routes.user(name: "ada")
  #expect(foreignUser.location == user.location)
  #expect(foreignUser != user)

  #expect(router._accepts(user))
  #expect(!router._accepts(foreignUser))
  #expect(!hash._accepts(foreignUser))
  #expect(router.isActive(user))
  #expect(!router.isActive(foreignUser))

  #expect(throws: RouteMatchError.foreignRoute) { try routes.href(to: foreignUser) }
  #expect(throws: RouteMatchError.foreignRoute) { try router.href(to: foreignUser) }
  #expect(throws: RouteMatchError.foreignRoute) { try router.navigate(to: foreignUser) }
  #expect(throws: RouteMatchError.foreignRoute) { try router.replace(to: foreignUser) }
  #expect(throws: RouteMatchError.foreignRoute) { try hash.href(to: foreignUser) }
  #expect(throws: RouteMatchError.foreignRoute) { try hash.navigate(to: foreignUser) }

  #expect(updates.isEmpty)
  #expect(router.location.href == "/users/ada")
  subscription.cancel()

  // Destinations of another `@Routes` type do not compile with this router, for example
  // `router.navigate(to: MacroRoutes.routes().home())`, because `RouteDestination` is generic
  // over the generated `RouteView`.
}

@Test func destinationsAreRevalidatedAgainstEachTreeSnapshot() throws {
  let builder = RouteBuilder<EmptyHTML>()
  let user = builder._route("/users/:name") { EmptyHTML() }
  let early = try builder._build()
  let newUser = builder._route("/users/new") { EmptyHTML() }
  let late = builder._route("/late") { EmptyHTML() }
  let complete = try builder._build()

  let ada = try early._destination(to: user, params: ["name": "ada"])
  let shadowed = try early._destination(to: user, params: ["name": "new"])
  let lateDestination = try complete._destination(to: late)
  #expect(shadowed.location.href == "/users/new")

  // A later snapshot of the same builder accepts the route unless one of its routes claims the URL.
  let completeRouter = Router(routes: complete, history: BrowserHistory(history: MemoryHistory()))
  #expect(completeRouter._accepts(ada))
  #expect(!completeRouter._accepts(shadowed))
  #expect(throws: RouteMatchError.unroutableLocation(href: "/users/new")) {
    try completeRouter.navigate(to: shadowed)
  }
  #expect(throws: RouteMatchError.unroutableLocation(href: "/users/new")) {
    try complete._destination(to: user, params: ["name": "new"])
  }
  try completeRouter.navigate(to: ada)
  #expect(completeRouter.currentRoute == user)

  // An earlier snapshot does not know routes registered after it was built.
  let earlyRouter = HashRouter(routes: early, history: BrowserHistory(history: MemoryHistory()))
  #expect(!earlyRouter._accepts(lateDestination))
  #expect(throws: RouteMatchError.unknownRoute) { try earlyRouter.navigate(to: lateDestination) }
  #expect(throws: RouteMatchError.unknownRoute) { try early._destination(to: newUser) }
}

@Test func layoutHandlesHaveNoDestinationOrHref() throws {
  let builder = RouteBuilder<EmptyHTML>()
  let teams = builder._layout("/teams", parent: nil) { EmptyHTML() }
  let team = builder._route(":id", parent: teams) { EmptyHTML() }
  let tree = try builder._build()

  // A layout never matches on its own, so its URL would render not-found.
  #expect(throws: RouteMatchError.unroutableLocation(href: "/teams")) {
    try tree._destination(to: teams)
  }
  #expect(throws: RouteMatchError.unroutableLocation(href: "/teams")) {
    try tree._href(to: teams)
  }
  let router = Router(routes: tree, history: BrowserHistory(history: MemoryHistory()))
  #expect(throws: RouteMatchError.unroutableLocation(href: "/teams")) {
    try router.navigate(to: teams)
  }
  #expect(try tree._href(to: team, params: ["id": 7]) == "/teams/7")
}

@Test func generatedProviderRouterViewAndLinkShareOneTypedDestination() throws {
  let routes = try ArticleRoutes.routes()
  let router = routes.router()
  let destination = try routes.article(slug: Slug("intro"), hash: "top")

  let link = ArticleRoutes.Link(to: destination, replace: true) { "Intro" }
  #expect(link.destination == destination)
  #expect(link.replace)
  #expect(link.href == "/articles/intro#top")
  #expect(try link.href == router.href(to: destination))
  #expect(try link.href == routes.href(to: destination))

  let provider = ArticleRoutes.Provider(routes, router: router) {
    ArticleRoutes.Link(to: destination) { "Intro" }
  }
  #expect(provider.router === router)
  let routerView = ArticleRoutes.RouterView(routes, router: router)
  #expect(routerView.router._accepts(destination))

  let hashRoutes = try HashMacroRoutes.routes()
  let hashDestination = try hashRoutes.user(id: 42, tab: "posts")
  let hashLink = HashMacroRoutes.Link(to: hashDestination, target: .blank) { "User" }
  #expect(hashLink.href == "#/users/42?tab=posts")
  #expect(try hashLink.href == hashRoutes.router().href(to: hashDestination))
  #expect(try hashLink.href == hashRoutes.href(to: hashDestination))
}
