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

final class HashHistory: RouterHistory {
  private let browser: BrowserHistory

  init() {
    self.browser = BrowserHistory()
  }

  var location: RouteLocation {
    let hash = browser.location.hash
    if hash.isEmpty {
      return RouteLocation()
    }
    return RouteLocation(url: hash)
  }

  func push(_ location: RouteLocation) {
    browser.push(RouteLocation(path: browser.location.path, hash: location.href))
  }

  func replace(_ location: RouteLocation) {
    browser.replace(RouteLocation(path: browser.location.path, hash: location.href))
  }

  func go(_ delta: Int) {
    browser.go(delta)
  }

  func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
    browser.listen { update in
      listener(HistoryUpdate(action: update.action, location: self.location))
    }
  }
}

#if canImport(JavaScriptKit)
  import JavaScriptKit

  final class _JavaScriptBrowserHistory: RouterHistory {
    private var fallback = MemoryHistory()
    private var popStateClosure: JSClosure?

    var location: RouteLocation {
      guard let location = JSObject.global.location.object else {
        return fallback.location
      }
      let path = location.pathname.string ?? "/"
      let query = location.search.string ?? ""
      let hash = location["hash"].string ?? ""
      return RouteLocation(path: path, queryString: query, hash: hash)
    }

    func push(_ location: RouteLocation) {
      guard let history = JSObject.global.history.object else {
        fallback.push(location)
        return
      }
      _ = history["pushState"].function?.callAsFunction(
        this: history,
        JSValue.null,
        "",
        location.href
      )
    }

    func replace(_ location: RouteLocation) {
      guard let history = JSObject.global.history.object else {
        fallback.replace(location)
        return
      }
      _ = history["replaceState"].function?.callAsFunction(
        this: history,
        JSValue.null,
        "",
        location.href
      )
    }

    func go(_ delta: Int) {
      guard let history = JSObject.global.history.object else {
        fallback.go(delta)
        return
      }
      _ = history["go"].function?.callAsFunction(this: history, delta)
    }

    func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
      let closure = JSClosure { _ in
        listener(HistoryUpdate(action: .pop, location: self.location))
        return .undefined
      }
      popStateClosure = closure
      _ = JSObject.global["addEventListener"].function?.callAsFunction(
        this: JSObject.global,
        "popstate",
        closure
      )
      return HistorySubscription {
        if let closure = self.popStateClosure {
          _ = JSObject.global["removeEventListener"].function?.callAsFunction(
            this: JSObject.global,
            "popstate",
            closure
          )
        }
        self.popStateClosure = nil
      }
    }
  }
#endif
