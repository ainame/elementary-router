import ElementaryUI
import Testing

@testable import ElementaryRouter

/// One route or layout function call made while a route view body was evaluated.
struct RecordedCall: Equatable, CustomStringConvertible {
  let name: String
  let values: [String]
  let route: RouteHandle?
  let path: String?
  let params: [String]?

  init(_ name: String, _ values: [String] = [], context: RouteContext? = nil) {
    self.name = name
    self.values = values
    self.route = context?.route
    self.path = context?.path
    self.params = context?.params.pairs.map { "\($0.0)=\($0.1)" }
  }

  var description: String {
    "\(name)(\(values.joined(separator: ", ")))"
  }
}

/// Collects the calls made by the route functions below while one body is evaluated.
///
/// The recorder is bound to the evaluating task, so tests that run in parallel stay separate.
final class CallRecorder: @unchecked Sendable {
  @TaskLocal static var current: CallRecorder?

  var calls: [RecordedCall] = []

  static func record(_ call: RecordedCall) {
    current?.calls.append(call)
  }

  /// Evaluates `view`'s body and every outlet below it, and returns the calls made.
  static func calls(rendering view: some View) -> [RecordedCall] {
    let recorder = CallRecorder()
    $current.withValue(recorder) {
      _ = view.body
    }
    return recorder.calls
  }
}

/// Evaluates the content a layout received, as mounting the layout's outlet would.
func renderOutlet<Content: View>(_ outlet: Outlet<Content>) {
  _ = outlet.content.body
}

@Routes
struct ThreeLayoutRoutes {
  @Layout("/")
  static func root<Content: View>(context: RouteContext, outlet: Outlet<Content>) -> EmptyHTML {
    CallRecorder.record(RecordedCall("root", context: context))
    renderOutlet(outlet)
    return EmptyHTML()
  }

  // Only this middle layout reads `sort`; its default differs from the member route's default.
  @Layout("/:lang")
  static func language<Content: View>(
    lang: String,
    sort: Query<String> = Query("name"),
    outlet: Outlet<Content>
  ) -> EmptyHTML {
    CallRecorder.record(RecordedCall("language", ["lang=\(lang)", "sort=\(sort.value)"]))
    renderOutlet(outlet)
    return EmptyHTML()
  }

  @Layout("/:lang/teams/:teamID")
  static func team<Content: View>(
    lang: String,
    teamID: Int,
    context: RouteContext,
    outlet: Outlet<Content>
  ) -> EmptyHTML {
    CallRecorder.record(
      RecordedCall("team", ["lang=\(lang)", "teamID=\(teamID)"], context: context)
    )
    renderOutlet(outlet)
    return EmptyHTML()
  }

  // A layout-only required query; its routes do not declare it.
  @Layout("/:lang/admin")
  static func admin<Content: View>(
    lang: String,
    level: Query<Int>,
    outlet: Outlet<Content>
  ) -> EmptyHTML {
    CallRecorder.record(RecordedCall("admin", ["lang=\(lang)", "level=\(level.value)"]))
    renderOutlet(outlet)
    return EmptyHTML()
  }

  @Route("/")
  static func home() -> EmptyHTML {
    CallRecorder.record(RecordedCall("home"))
    return EmptyHTML()
  }

  @Route("/:lang/about")
  static func about(lang: String) -> EmptyHTML {
    CallRecorder.record(RecordedCall("about", ["lang=\(lang)"]))
    return EmptyHTML()
  }

  @Route("/:lang/teams/:teamID")
  static func teamIndex(lang: String, teamID: Int) -> EmptyHTML {
    CallRecorder.record(RecordedCall("teamIndex", ["lang=\(lang)", "teamID=\(teamID)"]))
    return EmptyHTML()
  }

  @Route("/:lang/teams/:teamID/members/:memberID")
  static func member(
    lang: String,
    teamID: Int,
    memberID: Int,
    sort: Query<String> = Query("date"),
    context: RouteContext
  ) -> EmptyHTML {
    CallRecorder.record(
      RecordedCall(
        "member",
        ["lang=\(lang)", "teamID=\(teamID)", "memberID=\(memberID)", "sort=\(sort.value)"],
        context: context
      )
    )
    return EmptyHTML()
  }

  @Route("/:lang/admin/users")
  static func adminUsers(lang: String) -> EmptyHTML {
    CallRecorder.record(RecordedCall("adminUsers", ["lang=\(lang)"]))
    return EmptyHTML()
  }

  @NotFound
  static func notFound(context: RouteNotFoundContext) -> EmptyHTML {
    CallRecorder.record(RecordedCall("notFound", [context.location.path]))
    return EmptyHTML()
  }

  @RouteError
  static func routeError(context: RouteErrorContext) -> EmptyHTML {
    CallRecorder.record(
      RecordedCall("routeError", ["\(context.error)"], context: context.routeContext)
    )
    return EmptyHTML()
  }
}

/// The same layouts without route-set fallbacks.
@Routes
struct UnhandledLayoutRoutes {
  @Layout("/:lang")
  static func language<Content: View>(
    lang: String,
    level: Query<Int>,
    outlet: Outlet<Content>
  ) -> EmptyHTML {
    renderOutlet(outlet)
    return EmptyHTML()
  }

  @Route("/:lang/teams/:teamID")
  static func team(lang: String, teamID: Int) -> EmptyHTML {
    EmptyHTML()
  }
}

/// A layout with a custom path value and a required custom query value.
@Routes
struct CatalogRoutes {
  @Layout("/catalog/:section")
  static func catalog<Content: View>(
    section: Slug,
    order: Query<SortOrder>,
    outlet: Outlet<Content>
  ) -> EmptyHTML {
    CallRecorder.record(
      RecordedCall("catalog", ["section=\(section.rawValue)", "order=\(order.value.rawValue)"])
    )
    renderOutlet(outlet)
    return EmptyHTML()
  }

  // The route declares `order` with a default, but the layout requires it, so the destination
  // factory requires it.
  @Route("/catalog/:section/items/:item")
  static func item(
    section: Slug,
    item: Int,
    order: Query<SortOrder> = Query(.oldest)
  ) -> EmptyHTML {
    CallRecorder.record(
      RecordedCall("item", ["item=\(item)", "order=\(order.value.rawValue)"])
    )
    return EmptyHTML()
  }
}

private func render(
  _ url: String,
  in routes: ThreeLayoutRoutes.RouteSet
) throws -> (view: ThreeLayoutRoutes.RouteView, calls: [RecordedCall]) {
  let router = MemoryRouter(routes: routes.tree, history: MemoryHistory(initialPath: url))
  let view = try router.renderCurrentRoute()
  return (view, CallRecorder.calls(rendering: view))
}

@Test func nestedLayoutsReceiveTheirOwnValuesFromParentToLeaf() throws {
  let routes = try ThreeLayoutRoutes.routes()
  let handles = routes.handles

  // Paths registered under the root layout join it without a doubled separator.
  #expect(
    routes.tree._matches(RouteLocation(url: "/en/teams/7/members/42")).map(\.path) == [
      "/", "/:lang", "/:lang/teams/:teamID", "/:lang/teams/:teamID/members/:memberID",
    ]
  )

  let (_, calls) = try render("/en/teams/7/members/42", in: routes)

  // Layout bodies run outside-in, and each passes its outlet on to the next.
  #expect(calls.map(\.name) == ["root", "language", "team", "member"])

  // The root layout gets its own context, not the leaf's.
  #expect(calls[0].route == handles.root)
  #expect(calls[0].path == "/")
  #expect(calls[0].params == [])

  // The middle layout reads the query only it declares, with its own default.
  #expect(calls[1].values == ["lang=en", "sort=name"])

  // The inner layout's context holds its prefix params, not the member's.
  #expect(calls[2].values == ["lang=en", "teamID=7"])
  #expect(calls[2].route == handles.team)
  #expect(calls[2].path == "/:lang/teams/:teamID")
  #expect(calls[2].params == ["lang=en", "teamID=7"])

  // The leaf gets its own default and context.
  #expect(calls[3].values == ["lang=en", "teamID=7", "memberID=42", "sort=date"])
  #expect(calls[3].route == handles.member)
  #expect(calls[3].params == ["lang=en", "teamID=7", "memberID=42"])
}

@Test func aSharedQueryValueReachesEveryLayoutThatDeclaresIt() throws {
  let routes = try ThreeLayoutRoutes.routes()

  let (_, calls) = try render("/en/teams/7/members/42?sort=size", in: routes)

  #expect(
    calls.map(\.description) == [
      "root()",
      "language(lang=en, sort=size)",
      "team(lang=en, teamID=7)",
      "member(lang=en, teamID=7, memberID=42, sort=size)",
    ]
  )
}

@Test func siblingRoutesShareTheEnclosingLayoutBranches() throws {
  let routes = try ThreeLayoutRoutes.routes()

  let (index, _) = try render("/en/teams/7", in: routes)
  let (member, _) = try render("/en/teams/7/members/42", in: routes)
  let (about, _) = try render("/en/about", in: routes)

  // Siblings under `team` select the same case at every level above the team's outlet, so the
  // root, language, and team layout views keep their positions and stay mounted.
  for view in [index, member] {
    guard case .root(_, let root) = view.storage,
      case .language(_, _, let language) = root.storage,
      case .team(_, _, _, let team) = language.storage
    else {
      Issue.record("Expected the team layout branch, got \(view.storage)")
      continue
    }
    switch team.storage {
    case .teamIndex, .member:
      break
    }
  }

  // Leaving the team branch selects another case of the language outlet, so only the team
  // layout subtree is replaced; root and language stay on the same branch.
  guard case .root(_, let root) = about.storage,
    case .language(_, _, let language) = root.storage,
    case .about(let lang) = language.storage
  else {
    Issue.record("Expected the about route inside the language layout, got \(about.storage)")
    return
  }
  #expect(lang == "en")
}

@Test func layoutCallsAreMadeOnceOutsideTheirChildSwitch() throws {
  let routes = try ThreeLayoutRoutes.routes()

  // The home route is a direct child of the root layout; no other layout is evaluated.
  let (_, home) = try render("/", in: routes)
  #expect(home.map(\.name) == ["root", "home"])

  let (_, about) = try render("/en/about", in: routes)
  #expect(about.map(\.description) == ["root()", "language(lang=en, sort=name)", "about(lang=en)"])
}

@Test func layoutDecodeFailuresUseTheRouteErrorPolicyWithTheLayoutContext() throws {
  let routes = try ThreeLayoutRoutes.routes()
  let handles = routes.handles

  // A path value of the inner layout fails before the member route is rendered.
  let (_, invalidTeam) = try render("/en/teams/abc/members/42", in: routes)
  #expect(invalidTeam.map(\.name) == ["routeError"])
  #expect(
    invalidTeam.first?.values == [
      "\(RouteValueError.invalid(name: "teamID", rawValue: "abc", expected: "Int"))"
    ]
  )
  #expect(invalidTeam.first?.route == handles.team)

  // A required query that only the layout declares is missing.
  let (_, missingLevel) = try render("/en/admin/users", in: routes)
  #expect(missingLevel.map(\.name) == ["routeError"])
  #expect(missingLevel.first?.values == ["\(RouteValueError.missing(name: "level"))"])
  #expect(missingLevel.first?.route == handles.admin)

  let (_, admin) = try render("/en/admin/users?level=2", in: routes)
  #expect(
    admin.map(\.description) == [
      "root()", "language(lang=en, sort=name)", "admin(lang=en, level=2)", "adminUsers(lang=en)",
    ]
  )

  // The leaf's own failure is reported with the leaf context.
  let (_, invalidMember) = try render("/en/teams/7/members/x", in: routes)
  #expect(invalidMember.first?.route == handles.member)

  let (_, missing) = try render("/en", in: routes)
  #expect(missing.map(\.description) == ["notFound(/en)"])
}

@Test func layoutDecodeFailuresWithoutFallbacksAreRenderErrors() throws {
  let routes = try UnhandledLayoutRoutes.routes()

  #expect(throws: RouterRenderError.routeRenderFailed(.missing(name: "level"))) {
    try routes.tree._render(RouteLocation(url: "/en/teams/7"))
  }
  #expect(
    throws: RouterRenderError.routeRenderFailed(
      .invalid(name: "teamID", rawValue: "x", expected: "Int")
    )
  ) {
    try routes.tree._render(RouteLocation(url: "/en/teams/x?level=1"))
  }
  #expect(throws: RouterRenderError.routeNotFound) {
    try routes.tree._render(RouteLocation(url: "/en"))
  }
  _ = try routes.tree._render(RouteLocation(url: "/en/teams/7?level=1"))
}

@Test func routerViewSessionsCreateOneRouterOnlyWhenRead() throws {
  let routes = try MacroRoutes.routes()
  let history = MemoryHistory(initialPath: "/users/1")
  var created = 0
  typealias Session = _RouterViewSession<
    MacroRoutes.RouteSet, MemoryRouter<MacroRoutes.RouteView>
  >

  func makeSession() -> Session {
    Session {
      created += 1
      return (routes: routes, router: MemoryRouter(routes: routes.tree, history: history))
    }
  }

  var mounted: Session? = makeSession()
  weak let firstRouter = mounted?.router
  #expect(created == 1)
  #expect(history.listenerCount == 1)

  // Each parent rebuild evaluates a new `@State` initial value; none of them is read.
  for _ in 0..<10 {
    let rebuilt = makeSession()
    #expect(!rebuilt.isStarted)
    #expect(mounted?.router === firstRouter)
  }
  #expect(created == 1)
  #expect(history.listenerCount == 1)

  // Unmounting releases the session, its router, and the history listener.
  mounted = nil
  #expect(firstRouter == nil)
  #expect(history.listenerCount == 0)

  // A remount owns a new router.
  let remounted = makeSession()
  #expect(remounted.router.matchedRoutes == [routes.handles.user])
  #expect(created == 2)
  #expect(history.listenerCount == 1)
}

@Test func generatedRouterViewKeepsItsRouterAcrossParentRebuilds() throws {
  weak var ownedRouter: Router<MacroRoutes.RouteView>?

  do {
    // Mounting keeps the first view value's state; later values only restore it.
    let first = MacroRoutes.RouterView()
    let state = MacroRoutes.RouterView.__initializeState(from: first)
    var mounted = first
    MacroRoutes.RouterView.__restoreState(state, in: &mounted)

    let router = mounted.router
    let user = mounted.routes.handles.user
    ownedRouter = router
    #expect(router._uses(mounted.routes.tree))

    for _ in 0..<5 {
      var rebuilt = MacroRoutes.RouterView()
      // The rebuilt value's own initial session is never started.
      #expect(!rebuilt.session.isStarted)
      MacroRoutes.RouterView.__restoreState(state, in: &rebuilt)
      _ = rebuilt.body
      #expect(rebuilt.router === router)
      #expect(rebuilt.routes.handles.user == user)
      #expect(rebuilt.router._uses(rebuilt.routes.tree))
    }
    #expect(ownedRouter != nil)
  }

  // Dropping the mounted state releases the owned router and its history subscription.
  #expect(ownedRouter == nil)

  // A new mount builds a new route set and router.
  let remount = MacroRoutes.RouterView()
  let state = MacroRoutes.RouterView.__initializeState(from: remount)
  var mounted = remount
  MacroRoutes.RouterView.__restoreState(state, in: &mounted)
  #expect(mounted.router._uses(mounted.routes.tree))
}

@Test func generatedRouterViewAdoptsEachSuppliedRouteSetAndRouter() throws {
  let firstRoutes = try MacroRoutes.routes()
  let firstRouter = firstRoutes.router()
  let secondRoutes = try MacroRoutes.routes()
  let secondRouter = secondRoutes.router()

  let first = MacroRoutes.RouterView(firstRoutes, router: firstRouter)
  let state = MacroRoutes.RouterView.__initializeState(from: first)
  var mounted = first
  MacroRoutes.RouterView.__restoreState(state, in: &mounted)
  #expect(mounted.router === firstRouter)
  #expect(mounted.routes.handles.user == firstRoutes.handles.user)

  // A parent body that supplies another pair is rendered with that pair, kept together.
  var rebuilt = MacroRoutes.RouterView(secondRoutes, router: secondRouter)
  MacroRoutes.RouterView.__restoreState(state, in: &rebuilt)
  _ = rebuilt.body
  #expect(rebuilt.router === secondRouter)
  #expect(rebuilt.routes.handles.user == secondRoutes.handles.user)

  // Supplied pairs never start the view's own session.
  #expect(!rebuilt.session.isStarted)
}

@Test func destinationFactoriesTakeLayoutQueriesAndRenderThem() throws {
  let routes = try ThreeLayoutRoutes.routes()
  let router = MemoryRouter(routes: routes.tree, history: MemoryHistory(initialPath: "/"))

  // A query only the admin layout declares is a required factory argument.
  let admin = try routes.adminUsers(lang: "en", level: 3)
  #expect(admin.location.href == "/en/admin/users?level=3")
  try router.navigate(to: admin)
  #expect(
    CallRecorder.calls(rendering: try router.renderCurrentRoute()).map(\.description) == [
      "root()", "language(lang=en, sort=name)", "admin(lang=en, level=3)", "adminUsers(lang=en)",
    ]
  )

  // A defaulted layout query can be overridden from a route below it, and an omitted one lets
  // each declaration use its own default.
  try router.navigate(to: routes.about(lang: "en", sort: "size"))
  #expect(
    CallRecorder.calls(rendering: try router.renderCurrentRoute()).map(\.description) == [
      "root()", "language(lang=en, sort=size)", "about(lang=en)",
    ]
  )

  let shared = try routes.member(lang: "en", teamID: 7, memberID: 42, sort: "size")
  #expect(shared.location.href == "/en/teams/7/members/42?sort=size")
  try router.navigate(to: shared)
  #expect(
    CallRecorder.calls(rendering: try router.renderCurrentRoute()).map(\.description) == [
      "root()",
      "language(lang=en, sort=size)",
      "team(lang=en, teamID=7)",
      "member(lang=en, teamID=7, memberID=42, sort=size)",
    ]
  )

  try router.navigate(to: routes.member(lang: "en", teamID: 7, memberID: 42))
  #expect(
    CallRecorder.calls(rendering: try router.renderCurrentRoute()).map(\.description) == [
      "root()",
      "language(lang=en, sort=name)",
      "team(lang=en, teamID=7)",
      "member(lang=en, teamID=7, memberID=42, sort=date)",
    ]
  )
}

@Test func customLayoutValuesAreValidatedByDestinationsAndRendered() throws {
  let routes = try CatalogRoutes.routes()
  let router = MemoryRouter(routes: routes.tree, history: MemoryHistory(initialPath: "/"))

  let item = try routes.item(section: Slug("books"), item: 3, order: .newest)
  #expect(item.location.href == "/catalog/books/items/3?order=newest")
  try router.navigate(to: item)
  #expect(
    CallRecorder.calls(rendering: try router.renderCurrentRoute()).map(\.description) == [
      "catalog(section=books, order=newest)", "item(item=3, order=newest)",
    ]
  )

  // Values the layout cannot read back are rejected while the destination is built.
  #expect(
    throws: RouteMatchError.invalidValue(name: "order", rawValue: "draft", expected: "SortOrder")
  ) {
    try routes.item(section: Slug("books"), item: 3, order: .draft)
  }
  #expect(
    throws: RouteMatchError.invalidValue(name: "section", rawValue: "Books", expected: "Slug")
  ) {
    try routes.item(section: Slug("Books"), item: 3, order: .newest)
  }

  // Untyped navigation is validated against the layout's own requirements too.
  #expect(throws: RouteMatchError.missingRequiredParameter(name: "order")) {
    try router.navigate(to: routes.handles.item, params: ["section": "books", "item": 3])
  }
  #expect(
    throws: RouteMatchError.invalidValue(name: "order", rawValue: "sideways", expected: "SortOrder")
  ) {
    try router.navigate(
      to: routes.handles.item,
      params: ["section": "books", "item": 3],
      query: ["order": "sideways"]
    )
  }
  #expect(router.location == item.location)
}

@Test func destinationsRequireEveryGeneratedLayoutToDecodeItsValues() throws {
  let builder = RouteBuilder<EmptyHTML>()
  let account = builder._generatedLayout("/accounts/:id", parent: nil) {
    context throws(RouteValueError) in
    _ = try context.params.require("id", Int.self)
  }
  let settings = builder._generatedRoute("settings", parent: account) { _ in EmptyHTML() }
  let tree = try builder._build()

  // The route alone would accept any `id`, but its layout decodes it as `Int`.
  #expect(throws: RouteMatchError.invalidValue(name: "id", rawValue: "abc", expected: "Int")) {
    try tree._destination(to: settings, params: ["id": "abc"])
  }
  #expect(
    try tree._destination(to: settings, params: ["id": 7]).location.href == "/accounts/7/settings"
  )
}

@Test func generatedRouterViewMovesBetweenOwnedAndSuppliedPairs() throws {
  weak var ownedRouter: Router<MacroRoutes.RouteView>?
  weak var firstSuppliedRouter: Router<MacroRoutes.RouteView>?

  do {
    let first = MacroRoutes.RouterView()
    let state = MacroRoutes.RouterView.__initializeState(from: first)
    var owned = first
    MacroRoutes.RouterView.__restoreState(state, in: &owned)
    _ = owned.body
    let router = owned.router
    let ownedRoutes = owned.routes
    ownedRouter = router

    // A supplied pair replaces the rendered pair, while the owned session stays in the mounted
    // state with its router and history subscription.
    do {
      let suppliedRoutes = try MacroRoutes.routes()
      let suppliedRouter = suppliedRoutes.router()
      firstSuppliedRouter = suppliedRouter
      var supplied = MacroRoutes.RouterView(suppliedRoutes, router: suppliedRouter)
      MacroRoutes.RouterView.__restoreState(state, in: &supplied)
      _ = supplied.body
      #expect(supplied.router === suppliedRouter)
      #expect(supplied.routes.handles.user == suppliedRoutes.handles.user)
      #expect(supplied.session.router === router)

      // The owned router still applies history updates while it is not rendered.
      try router.navigate(to: ownedRoutes.user(id: 5))
      #expect(router.currentRoute == ownedRoutes.handles.user)
    }

    // Another supplied pair is adopted, and the view keeps no reference to the previous one.
    let replacementRoutes = try MacroRoutes.routes()
    let replacementRouter = replacementRoutes.router()
    var replaced = MacroRoutes.RouterView(replacementRoutes, router: replacementRouter)
    MacroRoutes.RouterView.__restoreState(state, in: &replaced)
    _ = replaced.body
    #expect(replaced.router === replacementRouter)
    #expect(replaced.routes.handles.user == replacementRoutes.handles.user)
    #expect(firstSuppliedRouter == nil)

    // Returning to `RouterView()` renders the same owned pair, at the location it followed.
    var ownedAgain = MacroRoutes.RouterView()
    MacroRoutes.RouterView.__restoreState(state, in: &ownedAgain)
    _ = ownedAgain.body
    #expect(ownedAgain.router === router)
    #expect(ownedAgain.routes.handles.user == ownedRoutes.handles.user)
    #expect(ownedAgain.router.location.path == "/users/5")
  }

  // Unmounting releases the owned router and its subscription.
  #expect(ownedRouter == nil)
}
