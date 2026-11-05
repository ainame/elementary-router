import ElementaryRouter
import ElementaryUI

@View
struct TodoDetailPage {
  @Environment(TodoStore.self) var store
  @Environment(AppRoutes._routeSetEnvironmentKey) var routes
  @Environment(AppRoutes._routerEnvironmentKey) var router
  @State var navigationError: String? = nil

  let todoID: Int

  var body: some View {
    if let todo = store.todo(id: todoID) {
      section(.style(panelStyle)) {
        p(.style(eyebrowStyle)) { "Task #\(todo.id)" }
        h2(.style(sectionTitleStyle)) { todo.title }
        dl(.style(detailsStyle)) {
          dt { "Project" }
          dd { todo.project }
          dt { "Status" }
          dd { todo.isCompleted ? "Completed" : "Active" }
        }
        div(.style(detailActionsStyle)) {
          button(.type(.button)) {
            todo.isCompleted ? "Mark active" : "Mark completed"
          }
          .attributes(.style(primaryButtonStyle))
          .onClick {
            store.toggle(id: todo.id)
          }
          button(.type(.button)) {
            "Delete task"
          }
          .attributes(.style(dangerButtonStyle))
          .onClick {
            deleteAndReturn(id: todo.id)
          }
          if let routes {
            AppRoutes.Link(to: routes.allTasks()) {
              "Back to all tasks"
            }
          }
        }
      }
    } else if let navigationError {
      NotFoundPanel(title: "Task deleted", message: navigationError)
    } else {
      NotFoundPanel(title: "Task not found", message: "No task exists for id \(todoID).")
    }
  }

  /// Deletes the task and replaces the detail entry, so going back does not reopen a deleted task.
  private func deleteAndReturn(id: Int) {
    store.remove(id: id)
    guard let routes, let router else {
      navigationError = "The task was deleted, but no router is provided to open the task list."
      return
    }
    do throws(RouteMatchError) {
      try router.replace(to: routes.allTasks())
    } catch {
      navigationError = "The task was deleted, but the task list could not be opened."
    }
  }
}
