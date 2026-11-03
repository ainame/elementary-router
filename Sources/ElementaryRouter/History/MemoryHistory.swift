final class MemoryHistory: RouterHistory {
  private var entries: [RouteLocation]
  private var index: Int
  private let listeners = HistoryListeners()

  init(initialPath: String = "/") {
    self.entries = [RouteLocation(url: initialPath)]
    self.index = 0
  }

  var location: RouteLocation {
    entries[index]
  }

  /// The number of registered listeners.
  var listenerCount: Int {
    listeners.count
  }

  func push(_ location: RouteLocation) {
    if index + 1 < entries.count {
      entries.removeSubrange((index + 1)..<entries.count)
    }
    entries.append(location)
    index = entries.count - 1
    listeners.notify(HistoryUpdate(action: .push, location: location))
  }

  func replace(_ location: RouteLocation) {
    entries[index] = location
    listeners.notify(HistoryUpdate(action: .replace, location: location))
  }

  func go(_ delta: Int) {
    let nextIndex = index + delta
    guard nextIndex >= 0 && nextIndex < entries.count else { return }
    index = nextIndex
    listeners.notify(HistoryUpdate(action: .pop, location: location))
  }

  func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
    listeners.subscribe(listener)
  }
}
