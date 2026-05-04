import ElementaryRouter
import ElementaryUI

@View
struct ContentView {
  @State var store = TodoStore()

  let routes: AppRoutes.RouteSet
  let router: Router<AppRoutes.RouteView>

  var body: some View {
    div(.style(pageStyle)) {
      header(.style(headerStyle)) {
        div {
          p(.style(eyebrowStyle)) { "ElementaryRouter Example" }
          h1(.style(titleStyle)) { "Todo Planner" }
        }
        div(.style(summaryPillStyle)) {
          "\(store.activeCount) active / \(store.todos.count) total"
        }
      }

      nav(.style(navStyle)) {
        FilterLink(title: "All", route: routes.handles.allTasks)
        FilterLink(title: "Active", route: routes.handles.activeTasks)
        FilterLink(title: "Completed", route: routes.handles.completedTasks)
        FilterLink(title: "Stats", route: routes.handles.stats)
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
    .environment(store)
    .environment(#Key(\.todoRouteSet), routes)
  }
}
