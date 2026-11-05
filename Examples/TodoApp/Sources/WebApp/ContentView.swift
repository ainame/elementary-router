import ElementaryRouter
import ElementaryUI

@View
struct ContentView<Content: View> {
  @Environment(AppRoutes._routeSetEnvironmentKey) var routes
  @Environment(TodoStore.self) var store

  let outlet: Outlet<Content>

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

      // This layout renders below `AppRoutes.RouterView`, which provides the route set. Without a
      // provider there is no route set to build destinations from, so no navigation is shown.
      if let routes {
        nav(.style(navStyle)) {
          // Static routes have non-throwing destination factories.
          FilterLink(title: "All", destination: routes.allTasks())
          FilterLink(title: "Active", destination: routes.activeTasks())
          FilterLink(title: "Completed", destination: routes.completedTasks())
          FilterLink(title: "Stats", destination: routes.stats())
        }
      }

      main(.style(mainStyle)) {
        outlet
      }
    }
    .environment(#Key(\.todoRouteSet), routes)
  }
}
