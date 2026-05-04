import ElementaryRouter
import ElementaryUI

@View
struct ContentView<Content: View> {
  @Environment(AppRoutes._routeSetEnvironmentKey) var routes

  let outlet: Outlet<Content>

  var body: some View {
    let routes = routeSet

    div(.style(pageStyle)) {
      header(.style(headerStyle)) {
        h1(.style(titleStyle)) { "ElementaryUI Router" }
        nav(.style(navStyle)) {
          AppRoutes.Link(to: routes.handles.home) {
            "Home"
          }
          AppRoutes.Link(
            to: routes.handles.profile,
            params: ["lang": "ja", "profileId": 42]
          ) {
            "Profile"
          }
          AppRoutes.Link(
            to: routes.handles.docs,
            params: ["*": "guide/get-started"],
            hash: "install"
          ) {
            "Docs"
          }
        }
      }

      main(.style(mainStyle)) {
        outlet
      }
    }
  }

  private var routeSet: AppRoutes.RouteSet {
    guard let routes else {
      preconditionFailure("ContentView requires AppRoutes.RouterView or AppRoutes.Provider.")
    }
    return routes
  }
}
