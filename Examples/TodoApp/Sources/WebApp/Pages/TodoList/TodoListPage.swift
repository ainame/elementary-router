import ElementaryRouter
import ElementaryUI

@View
struct TodoListPage {
  @Environment(#Key(\.todoRouteSet)) var routeSet
  @Environment(TodoStore.self) var store

  let filter: TodoFilter

  var body: some View {
    section(.style(panelStyle)) {
      div(.style(sectionHeaderStyle)) {
        div {
          p(.style(eyebrowStyle)) { "\(filter.rawValue) tasks" }
          h2(.style(sectionTitleStyle)) { "\(store.tasks(for: filter).count) visible" }
        }
        button(.type(.button)) {
          "Clear completed"
        }
        .attributes(.disabled, when: store.completedCount == 0)
        .attributes(.style(secondaryButtonStyle))
        .onClick {
          store.clearCompleted()
        }
      }

      div(.style(composerStyle)) {
        input(.type(.text), .placeholder("Add a task"))
          .attributes(.style(inputStyle))
          .bindValue(Binding(get: { store.draftTitle }, set: { store.draftTitle = $0 }))
        input(.type(.text), .placeholder("Project"))
          .attributes(.style(projectInputStyle))
          .bindValue(Binding(get: { store.draftProject }, set: { store.draftProject = $0 }))
        button(.type(.button)) {
          "Add"
        }
        .attributes(.style(primaryButtonStyle))
        .onClick {
          store.addDraft()
        }
      }

      let visibleTasks = store.tasks(for: filter)
      if visibleTasks.isEmpty {
        EmptyState(filter: filter)
      } else if let routeSet {
        let detailRoute = routeSet.handles.todoDetail
        div(.style(listStyle)) {
          ForEach(visibleTasks, key: { $0.id }) { todo in
            TodoRow(todo: todo, detailRoute: detailRoute)
          }
        }
      }
    }
  }
}
