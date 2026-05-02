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

  func isActive(
    _ route: RouteHandle,
    options: ActiveMatchOptions
  ) -> Bool
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
  let target: HTMLAttributeValue.Target?
  let content: Content

  public init(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = "",
    replace: Bool = false,
    target: HTMLAttributeValue.Target? = nil,
    @HTMLBuilder content: () -> Content
  ) {
    self.route = route
    self.params = params
    self.query = query
    self.hash = hash
    self.replace = replace
    self.target = target
    self.content = content()
  }

  public var body: some View {
    if let target {
      a(.href(href), .target(target), .data("router-link", value: "true")) {
        content
      }
      .onClick { event in
        handleClick(event)
      }
    } else {
      a(.href(href), .data("router-link", value: "true")) {
        content
      }
      .onClick { event in
        handleClick(event)
      }
    }
  }

  private func handleClick(_ event: MouseEvent) {
    let click = LinkClick(
      button: event.button,
      altKey: event.altKey,
      ctrlKey: event.ctrlKey,
      metaKey: event.metaKey,
      shiftKey: event.shiftKey,
      target: target?.rawValue
    )

    guard click.shouldIntercept else {
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

  private var href: String {
    (try? router?.href(to: route, params: params, query: query, hash: hash)) ?? "#"
  }
}

public struct LinkClick: Equatable, Sendable {
  public let button: Int
  public let altKey: Bool
  public let ctrlKey: Bool
  public let metaKey: Bool
  public let shiftKey: Bool
  public let target: String?

  public init(
    button: Int,
    altKey: Bool = false,
    ctrlKey: Bool = false,
    metaKey: Bool = false,
    shiftKey: Bool = false,
    target: String? = nil
  ) {
    self.button = button
    self.altKey = altKey
    self.ctrlKey = ctrlKey
    self.metaKey = metaKey
    self.shiftKey = shiftKey
    self.target = target
  }

  public var shouldIntercept: Bool {
    button == 0
      && !altKey
      && !ctrlKey
      && !metaKey
      && !shiftKey
      && (target == nil || target == "" || target == "_self")
  }
}
