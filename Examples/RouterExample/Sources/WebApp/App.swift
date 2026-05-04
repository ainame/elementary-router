import ElementaryRouter
import ElementaryUI

@main
struct App {
  static func main() throws(RouteTreeError) {
    let routes = try AppRoutes.routes()
    let router = try AppRoutes.router()
    let app = Application(
      AppRoutes.Provider(router) {
        AppRoutes.RouterView(
          onError: { _, location in
            AppRoutes.RouteView(
              storage: .notFound(
                RouteNotFoundContext(location: location, query: RouteValues())
              )
            )
          }
        ) { routeContent in
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

            Elementary.main(.style(mainStyle)) {
              routeContent
            }
          }
        }
      }
    )
    app.mount(in: .body)
  }
}
