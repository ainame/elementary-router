public final class BrowserHistory: RouterHistory {
  #if canImport(JavaScriptKit)
    private let history = _JavaScriptBrowserHistory()
  #else
    private let history = MemoryHistory()
  #endif

  public init() {}

  public var location: RouteLocation {
    history.location
  }

  public func push(_ location: RouteLocation) {
    history.push(location)
  }

  public func replace(_ location: RouteLocation) {
    history.replace(location)
  }

  public func go(_ delta: Int) {
    history.go(delta)
  }

  public func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
    history.listen(listener)
  }
}
