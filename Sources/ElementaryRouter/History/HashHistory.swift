public final class HashHistory: RouterHistory {
  private let browser: BrowserHistory

  public init() {
    self.browser = BrowserHistory()
  }

  public var location: RouteLocation {
    let hash = browser.location.hash
    if hash.isEmpty {
      return RouteLocation()
    }
    return RouteLocation(url: hash)
  }

  public func push(_ location: RouteLocation) {
    browser.push(RouteLocation(path: browser.location.path, hash: location.href))
  }

  public func replace(_ location: RouteLocation) {
    browser.replace(RouteLocation(path: browser.location.path, hash: location.href))
  }

  public func go(_ delta: Int) {
    browser.go(delta)
  }

  public func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
    browser.listen { update in
      listener(HistoryUpdate(action: update.action, location: self.location))
    }
  }
}
