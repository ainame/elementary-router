import ElementaryRouter
import ElementaryUI

@View
struct ContentView {
  let routeSet: AppRoutes.RouteSet
  let router: BrowserRouter<AppRoutes.RouteView>

  var body: some View {
    RouterProvider(router) {
      div(.style(pageStyle)) {
        header(.style(headerStyle)) {
          h1(.style(titleStyle)) { "ElementaryUI Router" }
          nav(.style(navStyle)) {
            Link(to: routeSet.handles.home) {
              "Home"
            }
            Link(
              to: routeSet.handles.profile,
              params: ["lang": "ja", "profileId": 42]
            ) {
              "Profile"
            }
            Link(
              to: routeSet.handles.docs,
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
                RouteNotFoundContext(location: router.location, query: RouteParameters())
              )
            )
          }
        }
      }
    }
  }
}
