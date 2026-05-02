import ElementaryUI
import Testing
@testable import ElementaryUIRouter

@Test func routeValuesExtractStringsAndTypedValues() throws {
    let values = RouteValues()
        .set("lang", "ja")
        .set("profileId", 42)

    #expect(try values.require("lang") == "ja")
    #expect(try values.require("profileId", Int.self) == 42)
    #expect(values.get("profileId") == "42")
    #expect(values.get("profileId", Int.self) == 42)
}

@Test func routeValuesReportMissingAndInvalidValues() {
    let values = RouteValues().set("profileId", "abc")

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
    let routes = RouteCollection()
    let user = routes.route("/users/:id") { EmptyHTML() }
    let newUser = routes.route("/users/new") { EmptyHTML() }
    let tree = try routes.freeze()

    #expect(tree.match(RouteLocation(url: "/users/new"))?.route == newUser)

    let match = tree.match(RouteLocation(url: "/users/42"))
    #expect(match?.route == user)
    #expect(match?.params.get("id") == "42")
}

@Test func matcherSupportsWildcardRoutes() throws {
    let routes = RouteCollection()
    let files = routes.route("/files/*") { EmptyHTML() }
    let tree = try routes.freeze()

    let match = tree.match(RouteLocation(url: "/files/docs/readme"))
    #expect(match?.route == files)
    #expect(match?.params.get("*") == "docs/readme")
}

@Test func routeTreeBuildsHrefFromParamsAndQuery() throws {
    let routes = RouteCollection()
    let profile = routes.route("/:lang/profile/:profileId") { EmptyHTML() }
    let tree = try routes.freeze()

    let href = try tree.href(
        to: profile,
        params: RouteValues()
            .set("lang", "ja")
            .set("profileId", 42),
        query: RouteValues().set("tab", "posts")
    )

    #expect(href == "/ja/profile/42?tab=posts")
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
    let routes = RouteCollection()
    let home = routes.route("/") { EmptyHTML() }
    let profile = routes.route("/:lang/profile/:profileId") { EmptyHTML() }
    let tree = try routes.freeze()
    let history = MemoryHistory(initialPath: "/")
    let router = Router(routes: tree, history: history)

    #expect(router.currentMatch?.route == home)

    try router.navigate(
        to: profile,
        params: RouteValues()
            .set("lang", "ja")
            .set("profileId", 42),
        query: RouteValues().set("tab", "posts")
    )

    #expect(router.location.href == "/ja/profile/42?tab=posts")
    #expect(router.currentMatch?.route == profile)
    #expect(router.currentMatch?.params.get("lang") == "ja")
    #expect(router.location.queryString == "tab=posts")
}
