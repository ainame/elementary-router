protocol RouterHistory: AnyObject {
  var location: RouteLocation { get }
  func push(_ location: RouteLocation)
  func replace(_ location: RouteLocation)
  func go(_ delta: Int)
  func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription
}

extension RouterHistory where Self == MemoryHistory {
  static func memory(initialPath: String = "/") -> MemoryHistory {
    MemoryHistory(initialPath: initialPath)
  }
}
