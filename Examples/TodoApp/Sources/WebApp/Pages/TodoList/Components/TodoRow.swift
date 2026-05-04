import ElementaryRouter
import ElementaryUI

@View
struct TodoRow {
  @Environment(TodoStore.self) var store

  let todo: TodoItem
  let detailRoute: RouteHandle

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
        AppRoutes.Link(
          to: detailRoute,
          params: ["todoID": RouteParameters.ValueLiteral(todo.id)]
        ) {
          todo.title
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
}
