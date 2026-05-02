import ElementaryUI

public extension EnvironmentValues {
    @Entry var router: Router? = nil
}

@View
public struct RouterProvider<Content: View> {
    let router: Router
    let content: Content

    public init(_ router: Router, @HTMLBuilder content: () -> Content) {
        self.router = router
        self.content = content()
    }

    public var body: some View {
        content.environment(#Key(\.router), router)
    }
}

@View
public struct RouterView {
    @Environment(#Key(\.router)) var router

    public init() {}

    public var body: some View {
        EmptyHTML()
    }
}

@View
public struct Link<Content: View> {
    @Environment(#Key(\.router)) var router

    let route: RouteHandle
    let params: RouteValues
    let query: RouteValues
    let hash: String
    let replace: Bool
    let content: Content

    public init(
        to route: RouteHandle,
        params: RouteValues = RouteValues(),
        query: RouteValues = RouteValues(),
        hash: String = "",
        replace: Bool = false,
        @HTMLBuilder content: () -> Content
    ) {
        self.route = route
        self.params = params
        self.query = query
        self.hash = hash
        self.replace = replace
        self.content = content()
    }

    public var body: some View {
        a(.href(href)) {
            content
        }
        .onClick { event in
            guard event.button == 0,
                !event.metaKey,
                !event.ctrlKey,
                !event.shiftKey,
                !event.altKey
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
    }

    private var href: String {
        (try? router?.href(to: route, params: params, query: query, hash: hash)) ?? "#"
    }
}
