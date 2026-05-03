import ElementaryUI

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
