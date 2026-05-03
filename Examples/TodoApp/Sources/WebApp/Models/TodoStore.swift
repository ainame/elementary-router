import Reactivity

@Reactive
final class TodoStore {
  var draftTitle: String = ""
  var draftProject: String = "Launch"
  var nextID: Int = 5
  var todos: [TodoItem] = [
    TodoItem(id: 1, title: "Map the onboarding routes", project: "Launch", isCompleted: false),
    TodoItem(id: 2, title: "Write 0.0.1 release notes", project: "Release", isCompleted: false),
    TodoItem(
      id: 3,
      title: "Check hash history on static hosting",
      project: "QA",
      isCompleted: true
    ),
    TodoItem(id: 4, title: "Review Link interception fallback", project: "QA", isCompleted: false),
  ]

  var activeCount: Int {
    todos.filter { !$0.isCompleted }.count
  }

  var completedCount: Int {
    todos.filter { $0.isCompleted }.count
  }

  var completionPercent: Int {
    guard !todos.isEmpty else {
      return 0
    }
    return completedCount * 100 / todos.count
  }

  func tasks(for filter: TodoFilter) -> [TodoItem] {
    switch filter {
    case .all:
      todos
    case .active:
      todos.filter { !$0.isCompleted }
    case .completed:
      todos.filter { $0.isCompleted }
    }
  }

  func todo(id: Int) -> TodoItem? {
    todos.first { $0.id == id }
  }

  func addDraft() {
    let title = draftTitle.emptyFallback("")
    guard !title.isEmpty else {
      return
    }

    todos.insert(
      TodoItem(
        id: nextID,
        title: title,
        project: draftProject.emptyFallback("General"),
        isCompleted: false
      ),
      at: 0
    )
    nextID += 1
    draftTitle = ""
  }

  func toggle(id: Int) {
    guard let index = todos.firstIndex(where: { $0.id == id }) else {
      return
    }
    todos[index].isCompleted.toggle()
  }

  func setCompleted(id: Int, isCompleted: Bool) {
    guard let index = todos.firstIndex(where: { $0.id == id }) else {
      return
    }
    todos[index].isCompleted = isCompleted
  }

  func remove(id: Int) {
    todos.removeAll { $0.id == id }
  }

  func clearCompleted() {
    todos.removeAll { $0.isCompleted }
  }
}

extension String {
  fileprivate func emptyFallback(_ fallback: String) -> String {
    isEmpty ? fallback : self
  }
}
