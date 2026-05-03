struct TodoItem: Equatable, Sendable {
  let id: Int
  var title: String
  var project: String
  var isCompleted: Bool
}
