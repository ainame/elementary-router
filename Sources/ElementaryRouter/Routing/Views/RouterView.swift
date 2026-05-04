import ElementaryUI

/// Renders the current route from a router and maps router render errors to fallback content.
@View
public struct RouterView<RouteContent: View> {
  let renderCurrentRoute: () throws(RouterRenderError) -> RouteContent
  let renderError: (RouterRenderError) -> RouteContent

  /// Creates a view bound to a path router.
  public init(
    _ router: Router<RouteContent>,
    onError renderError: @escaping (RouterRenderError) -> RouteContent
  ) {
    self.renderCurrentRoute = router.renderCurrentRoute
    self.renderError = renderError
  }

  /// Creates a view bound to a hash router.
  public init(
    _ router: HashRouter<RouteContent>,
    onError renderError: @escaping (RouterRenderError) -> RouteContent
  ) {
    self.renderCurrentRoute = router.renderCurrentRoute
    self.renderError = renderError
  }

  /// The rendered route content or the supplied error fallback.
  public var body: some View {
    rendered
  }

  private var rendered: RouteContent {
    do {
      return try renderCurrentRoute()
    } catch {
      return renderError(error)
    }
  }
}
