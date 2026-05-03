import ElementaryUI

@View
public struct RouterView<RouteContent: View> {
  let renderCurrentRoute: () throws(RouterRenderError) -> RouteContent
  let renderError: (RouterRenderError) -> RouteContent

  public init(
    _ router: Router<RouteContent>,
    onError renderError: @escaping (RouterRenderError) -> RouteContent
  ) {
    self.renderCurrentRoute = router.renderCurrentRoute
    self.renderError = renderError
  }

  public init(
    _ router: HashRouter<RouteContent>,
    onError renderError: @escaping (RouterRenderError) -> RouteContent
  ) {
    self.renderCurrentRoute = router.renderCurrentRoute
    self.renderError = renderError
  }

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
