import ElementaryUI

@View
public struct RouterView<RouteContent: View, History: RouterHistory> {
  let router: Router<RouteContent, History>
  let renderError: (RouterRenderError) -> RouteContent

  public init(
    _ router: Router<RouteContent, History>,
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
