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
        Link(to: detailRoute, params: RouteParameters(("todoID", RouteValueLiteral(todo.id)))) {
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

@View
struct EmptyState {
  let filter: TodoFilter

  var body: some View {
    div(.style(emptyStateStyle)) {
      h3(.style(emptyTitleStyle)) { "No \(filter.rawValue.lowercased()) tasks" }
      p(.style(mutedTextStyle)) {
        "Add a task or switch filters to keep planning."
      }
    }
  }
}

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

@View
struct StatsPage {
  @Environment(TodoStore.self) var store

  var body: some View {
    section(.style(panelStyle)) {
      p(.style(eyebrowStyle)) { "Progress" }
      h2(.style(sectionTitleStyle)) { "\(store.completionPercent)% complete" }

      div(.style(metricsGridStyle)) {
        MetricCard(label: "Total", value: "\(store.todos.count)")
        MetricCard(label: "Active", value: "\(store.activeCount)")
        MetricCard(label: "Completed", value: "\(store.completedCount)")
      }
    }
  }
}

@View
struct MetricCard {
  let label: String
  let value: String

  var body: some View {
    div(.style(metricCardStyle)) {
      p(.style(metricValueStyle)) { value }
      p(.style(mutedTextStyle)) { label }
    }
  }
}

@View
struct NotFoundPage {
  let path: String

  var body: some View {
    NotFoundPanel(title: "Page not found", message: "No route matched \(path).")
  }
}

@View
struct InvalidRoutePage {
  let error: RouteValueError

  var body: some View {
    NotFoundPanel(title: "Invalid route", message: message)
  }

  private var message: String {
    switch error {
    case .missing(let name):
      "Missing route value: \(name)."
    case .invalid(let name, let rawValue, let expected):
      "Invalid route value \(name)=\(rawValue). Expected \(expected)."
    }
  }
}

@View
struct NotFoundPanel {
  let title: String
  let message: String

  var body: some View {
    section(.style(panelStyle)) {
      h2(.style(sectionTitleStyle)) { title }
      p(.style(mutedTextStyle)) { message }
    }
  }
}
