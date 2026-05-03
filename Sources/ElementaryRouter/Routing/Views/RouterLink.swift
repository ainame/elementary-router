import ElementaryUI

@View
public struct RouterLink<Content: View> {
  let hrefForRoute: () throws -> String
  let navigateToRoute: (_ replace: Bool) throws -> Void
  let route: RouteHandle
  let params: RouteParameters
  let query: RouteParameters
  let hash: String
  let replace: Bool
  let target: HTMLAttributeValue.Target?
  let content: Content

  public init<RouteContent: View>(
    router: Router<RouteContent>,
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = "",
    replace: Bool = false,
    target: HTMLAttributeValue.Target? = nil,
    @HTMLBuilder content: () -> Content
  ) {
    self.hrefForRoute = { try router.href(to: route, params: params, query: query, hash: hash) }
    self.navigateToRoute = { shouldReplace in
      try router.navigate(
        to: route,
        params: params,
        query: query,
        hash: hash,
        replace: shouldReplace
      )
    }
    self.route = route
    self.params = params
    self.query = query
    self.hash = hash
    self.replace = replace
    self.target = target
    self.content = content()
  }

  public init<RouteContent: View>(
    router: HashRouter<RouteContent>,
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = "",
    replace: Bool = false,
    target: HTMLAttributeValue.Target? = nil,
    @HTMLBuilder content: () -> Content
  ) {
    self.hrefForRoute = { try router.href(to: route, params: params, query: query, hash: hash) }
    self.navigateToRoute = { shouldReplace in
      try router.navigate(
        to: route,
        params: params,
        query: query,
        hash: hash,
        replace: shouldReplace
      )
    }
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

    try? navigateToRoute(replace)
  }

  private var href: String {
    (try? hrefForRoute()) ?? "#"
  }
}
