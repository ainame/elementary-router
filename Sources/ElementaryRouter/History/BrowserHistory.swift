/// The document history used by `Router` and, through `HashHistory`, by `HashRouter`.
///
/// Browser builds drive `window.history` and observe `popstate`. Native builds cannot reach a
/// JavaScript host, so they keep the same contract with an in-memory history.
final class BrowserHistory: RouterHistory {
  #if canImport(JavaScriptKit) && arch(wasm32)
    private let history = _JavaScriptBrowserHistory()

    init() {}
  #else
    private let history: MemoryHistory

    init(history: MemoryHistory = MemoryHistory()) {
      self.history = history
    }
  #endif

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
    HashHistory.routeLocation(in: base.location)
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
    // Derive the route location from the update instead of reading `self`, so the base history's
    // listener storage never retains this adapter.
    base.listen { update in
      listener(
        HistoryUpdate(action: update.action, location: HashHistory.routeLocation(in: update.location))
      )
    }
  }

  /// A fragment-only href resolves against the current document URL, which keeps the base path
  /// and outer query string for normal clicks, modified clicks, and copied links alike.
  func href(for location: RouteLocation) -> String {
    "#" + location.href
  }

  private static func routeLocation(in document: RouteLocation) -> RouteLocation {
    if document.hash.isEmpty {
      return RouteLocation()
    }
    return RouteLocation(url: document.hash)
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

#if canImport(JavaScriptKit) && arch(wasm32)
  import JavaScriptKit

  final class _JavaScriptBrowserHistory: RouterHistory {
    private let listeners: HistoryListeners
    /// Used when the JavaScript host has no `window.history`; its updates are forwarded.
    private let fallback: MemoryHistory
    private let fallbackSubscription: HistorySubscription
    /// The `popstate` callback, registered on `window` only while there are listeners.
    private var popStateClosure: JSClosure?

    init() {
      let listeners = HistoryListeners()
      let fallback = MemoryHistory()
      self.listeners = listeners
      self.fallback = fallback
      self.fallbackSubscription = fallback.listen { update in
        listeners.notify(update)
      }
    }

    var location: RouteLocation {
      _JavaScriptBrowserHistory.windowLocation() ?? fallback.location
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
      // `pushState` does not emit `popstate`, so report the change here.
      listeners.notify(HistoryUpdate(action: .push, location: self.location))
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
      // `replaceState` does not emit `popstate`, so report the change here.
      listeners.notify(HistoryUpdate(action: .replace, location: self.location))
    }

    /// Browsers report the resulting location through `popstate` once traversal finishes.
    func go(_ delta: Int) {
      guard let history = JSObject.global.history.object else {
        fallback.go(delta)
        return
      }
      _ = history["go"].function?.callAsFunction(this: history, delta)
    }

    func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
      let subscription = listeners.subscribe(listener) { [self] remaining in
        if remaining == 0 {
          removePopStateListener()
        }
      }
      addPopStateListenerIfNeeded()
      return subscription
    }

    private func addPopStateListenerIfNeeded() {
      guard popStateClosure == nil else { return }
      // JavaScriptKit keeps the closure body alive until the browser collects the function, so
      // the body captures only the listener storage, never this history.
      let listeners = self.listeners
      let closure = JSClosure { _ in
        if let location = _JavaScriptBrowserHistory.windowLocation() {
          listeners.notify(HistoryUpdate(action: .pop, location: location))
        }
        return .undefined
      }
      _ = JSObject.global["addEventListener"].function?.callAsFunction(
        this: JSObject.global,
        "popstate",
        closure
      )
      popStateClosure = closure
    }

    private func removePopStateListener() {
      guard let closure = popStateClosure else { return }
      popStateClosure = nil
      _ = JSObject.global["removeEventListener"].function?.callAsFunction(
        this: JSObject.global,
        "popstate",
        closure
      )
    }

    private static func windowLocation() -> RouteLocation? {
      guard let location = JSObject.global.location.object else {
        return nil
      }
      let path = location.pathname.string ?? "/"
      let query = location.search.string ?? ""
      let hash = location["hash"].string ?? ""
      return RouteLocation(path: path, queryString: query, hash: hash)
    }
  }
#endif
