import ElementaryUI

@View
public struct RouterProvider<Content: View> {
  let router: any RouterNavigation
  let content: Content

  public init<RouteContent: View>(
    _ router: Router<RouteContent>,
    @HTMLBuilder content: () -> Content
  ) {
    self.router = router.navigation
    self.content = content()
  }

  public init<RouteContent: View>(
    _ router: HashRouter<RouteContent>,
    @HTMLBuilder content: () -> Content
  ) {
    self.router = router.navigation
    self.content = content()
  }

  public var body: some View {
    content.environment(#Key(\.router), router)
  }
}
