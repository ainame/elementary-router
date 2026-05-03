import ElementaryUI

@View
public struct RouterProvider<RouteContent: View, History: RouterHistory, Content: View> {
  let router: Router<RouteContent, History>
  let content: Content

  public init(_ router: Router<RouteContent, History>, @HTMLBuilder content: () -> Content) {
    self.router = router
    self.content = content()
  }

  public var body: some View {
    content.environment(#Key(\.router), router)
  }
}
