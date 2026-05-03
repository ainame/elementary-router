public protocol RouterHistory: AnyObject {
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

extension RouterHistory where Self == BrowserHistory {
  public static func browser() -> BrowserHistory {
    BrowserHistory()
  }
}

extension RouterHistory where Self == HashHistory {
  public static func hash() -> HashHistory {
    HashHistory()
  }
}
