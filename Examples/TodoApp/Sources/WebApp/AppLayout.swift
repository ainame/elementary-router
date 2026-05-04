import ElementaryRouter
import ElementaryUI

@View
struct AppLayout {
  @State var store = TodoStore()

  let routes: AppRoutes.RouteSet
  let routeContent: AppRoutes.RouteView

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
        routeContent
      }
    }
    .environment(store)
    .environment(#Key(\.todoRouteSet), routes)
  }
}
