import ElementaryRouter
import ElementaryUI

@View
struct TodoRow {
  @Environment(TodoStore.self) var store

  let todo: TodoItem
  let routes: AppRoutes.RouteSet

  var body: some View {
    div(.style(rowStyle(isCompleted: todo.isCompleted))) {
      input(.type(.checkbox))
        .bindChecked(
          Binding(
            get: { todo.isCompleted },
            set: { store.setCompleted(id: todo.id, isCompleted: $0) }
          )
        )
      div(.style(rowContentStyle)) {
        // A path value can fail to build a destination, so the failure is rendered explicitly.
        switch detailDestination {
        case .success(let detail):
          AppRoutes.Link(to: detail) {
            todo.title
          }
        case .failure:
          span(.style(errorTextStyle)) {
            todo.title
          }
        }
        span(.style(projectBadgeStyle)) {
          todo.project
        }
      }
      button(.type(.button)) {
        "Delete"
      }
      .attributes(.style(dangerButtonStyle))
      .onClick {
        store.remove(id: todo.id)
      }
    }
  }

  private var detailDestination: Result<RouteDestination<AppRoutes.RouteView>, RouteMatchError> {
    Result { () throws(RouteMatchError) in
      try routes.todoDetail(todoID: todo.id)
    }
  }
}
