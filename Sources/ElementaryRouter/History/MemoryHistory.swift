public final class MemoryHistory: RouterHistory {
  private var entries: [RouteLocation]
  private var index: Int
  private var nextListenerID = 0
  private var listeners: [(Int, (HistoryUpdate) -> Void)] = []

  public init(initialPath: String = "/") {
    self.entries = [RouteLocation(url: initialPath)]
    self.index = 0
  }

  public var location: RouteLocation {
    entries[index]
  }

  public func push(_ location: RouteLocation) {
    if index + 1 < entries.count {
      entries.removeSubrange((index + 1)..<entries.count)
    }
    entries.append(location)
    index = entries.count - 1
    notify(HistoryUpdate(action: .push, location: location))
  }

  public func replace(_ location: RouteLocation) {
    entries[index] = location
    notify(HistoryUpdate(action: .replace, location: location))
  }

  public func go(_ delta: Int) {
    let nextIndex = index + delta
    guard nextIndex >= 0 && nextIndex < entries.count else { return }
    index = nextIndex
    notify(HistoryUpdate(action: .pop, location: location))
  }

  public func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
    let id = nextListenerID
    nextListenerID += 1
    listeners.append((id, listener))
    return HistorySubscription {
      self.listeners.removeAll { $0.0 == id }
    }
  }

  private func notify(_ update: HistoryUpdate) {
    for (_, listener) in listeners {
      listener(update)
    }
  }
}
