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

/// Stores the route location in the fragment of a base history.
///
/// The base history's path and query string belong to the hosting document, such as
/// `/app/?lang=en`, and are preserved when the route location changes. The route location is
/// written after `#` as-is: it is already a percent-encoded href, so it is not encoded again.
final class HashHistory<Base: RouterHistory>: RouterHistory {
  private let base: Base

  init(base: Base) {
    self.base = base
  }

  var location: RouteLocation {
    let hash = base.location.hash
    if hash.isEmpty {
      return RouteLocation()
    }
    return RouteLocation(url: hash)
  }

  func push(_ location: RouteLocation) {
    base.push(documentLocation(for: location))
  }

  func replace(_ location: RouteLocation) {
    base.replace(documentLocation(for: location))
  }

  func go(_ delta: Int) {
    base.go(delta)
  }

  func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
    base.listen { update in
      listener(HistoryUpdate(action: update.action, location: self.location))
    }
  }

  /// A fragment-only href resolves against the current document URL, which keeps the base path
  /// and outer query string for normal clicks, modified clicks, and copied links alike.
  func href(for location: RouteLocation) -> String {
    "#" + location.href
  }

  private func documentLocation(for location: RouteLocation) -> RouteLocation {
    let document = base.location
    return RouteLocation(
      path: document.path,
      queryString: document.queryString,
      hash: location.href
    )
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
