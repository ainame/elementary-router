import ElementaryUI

public protocol RouterNavigation: AnyObject {
  func href(
    to route: RouteHandle,
    params: RouteParameters,
    query: RouteParameters,
    hash: String
  ) throws(RouteMatchError) -> String

  func navigate(
    to route: RouteHandle,
    params: RouteParameters,
    query: RouteParameters,
    hash: String,
    replace: Bool
  ) throws(RouteMatchError)
}

extension EnvironmentValues {
  @Entry public var router: (any RouterNavigation)? = nil
}

@View
public struct RouterProvider<RouteContent: View, Content: View> {
  let router: Router<RouteContent>
  let content: Content

  public init(_ router: Router<RouteContent>, @HTMLBuilder content: () -> Content) {
    self.router = router
    self.content = content()
  }

  public var body: some View {
    content.environment(#Key(\.router), router)
  }
}

@View
public struct RouterView<RouteContent: View> {
  let router: Router<RouteContent>
  let renderError: (RouterRenderError) -> RouteContent

  public init(
    _ router: Router<RouteContent>,
    onError renderError: @escaping (RouterRenderError) -> RouteContent
  ) {
    self.router = router
    self.renderError = renderError
  }

  public var body: some View {
    rendered
  }

  private var rendered: RouteContent {
    do {
      return try router.renderCurrentRoute()
    } catch {
      return renderError(error)
    }
  }
}

@View
public struct Link<Content: View> {
  @Environment(#Key(\.router)) var router

  let route: RouteHandle
  let params: RouteParameters
  let query: RouteParameters
  let hash: String
  let replace: Bool
  let content: Content

  public init(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
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
