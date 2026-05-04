import ElementaryRouter
import ElementaryUI

@View
struct ContentView {
  let routes: AppRoutes.RouteSet
  let router: Router<AppRoutes.RouteView>

  var body: some View {
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
        RouterView(router) { _ in
          AppRoutes.RouteView(
            storage: .notFound(
              RouteNotFoundContext(location: router.location, query: RouteValues())
            )
          )
        }
      }
    }
  }
}
