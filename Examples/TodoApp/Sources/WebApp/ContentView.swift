import ElementaryRouter
import ElementaryUI

@View
struct ContentView {
  @State var store = TodoStore()

  let routeSet: AppRoutes.RouteSet
  let router: BrowserRouter<AppRoutes.RouteView>

  var body: some View {
    RouterProvider(router) {
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
          FilterLink(title: "All", route: routeSet.handles.allTasks)
          FilterLink(title: "Active", route: routeSet.handles.activeTasks)
          FilterLink(title: "Completed", route: routeSet.handles.completedTasks)
          FilterLink(title: "Stats", route: routeSet.handles.stats)
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
      .environment(store)
      .environment(#Key(\.todoRouteSet), routeSet)
    }
  }
}
