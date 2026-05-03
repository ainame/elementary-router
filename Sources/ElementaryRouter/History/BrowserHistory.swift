final class BrowserHistory: RouterHistory {
  #if canImport(JavaScriptKit)
    private let history = _JavaScriptBrowserHistory()
  #else
    private let history = MemoryHistory()
  #endif

  init() {}

  var location: RouteLocation {
    history.location
  }

  func push(_ location: RouteLocation) {
    history.push(location)
  }

  func replace(_ location: RouteLocation) {
    history.replace(location)
  }

  func go(_ delta: Int) {
    history.go(delta)
  }

  func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
    history.listen(listener)
  }
}
