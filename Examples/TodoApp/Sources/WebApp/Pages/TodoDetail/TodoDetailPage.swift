import ElementaryUI

@View
struct TodoDetailPage {
  @Environment(TodoStore.self) var store

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
        button(.type(.button)) {
          todo.isCompleted ? "Mark active" : "Mark completed"
        }
        .attributes(.style(primaryButtonStyle))
        .onClick {
          store.toggle(id: todo.id)
        }
      }
    } else {
      NotFoundPanel(title: "Task not found", message: "No task exists for id \(todoID).")
    }
  }
}
