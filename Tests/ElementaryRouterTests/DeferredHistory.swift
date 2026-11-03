@testable import ElementaryRouter

/// A test history that holds its notifications until `deliver()` is called.
///
/// Holding notifications shows whether a router changes its state outside history
/// notifications, and `deliveryCount` counts how often each update reached the listeners.
final class DeferredHistory: RouterHistory {
  private(set) var location: RouteLocation
  private(set) var pendingUpdates: [HistoryUpdate] = []
  /// The number of listener calls made by `deliver()`.
  private(set) var deliveryCount = 0
  private let listeners = HistoryListeners()

  init(initialPath: String = "/") {
    self.location = RouteLocation(url: initialPath)
  }

  var listenerCount: Int {
    listeners.count
  }

  func push(_ location: RouteLocation) {
    self.location = location
    pendingUpdates.append(HistoryUpdate(action: .push, location: location))
  }

  func replace(_ location: RouteLocation) {
    self.location = location
    pendingUpdates.append(HistoryUpdate(action: .replace, location: location))
  }

  /// Traversal is not modeled; tests that need it use `MemoryHistory`.
  func go(_ delta: Int) {}

  func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
    listeners.subscribe(listener)
  }

  func deliver() {
    let updates = pendingUpdates
    pendingUpdates = []
    for update in updates {
      deliveryCount += listeners.count
      listeners.notify(update)
    }
  }
}
