/// A location store that routers read, mutate, and observe.
///
/// Every adapter notifies listeners exactly once per location change: once for each `push` and
/// `replace`, and once for each `go` that moves to another entry. Routers rely on these
/// notifications as their only update path, so a programmatic navigation is applied once.
/// A change made by a listener while it handles an update is reported after that update.
protocol RouterHistory: AnyObject {
  var location: RouteLocation { get }
  func push(_ location: RouteLocation)
  func replace(_ location: RouteLocation)
  func go(_ delta: Int)
  /// Registers `listener` until the returned subscription is cancelled or released.
  ///
  /// The listener must not capture the subscription's owner, because the history keeps the
  /// listener alive while it is registered.
  func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription
  /// Returns the href an anchor should use to reach `location` through this history.
  func href(for location: RouteLocation) -> String
}

extension RouterHistory {
  func href(for location: RouteLocation) -> String {
    location.href
  }
}

enum HistoryAction: Equatable, Sendable {
  case push
  case replace
  case pop
}

struct HistoryUpdate: Equatable, Sendable {
  let action: HistoryAction
  let location: RouteLocation
}

/// Owns one listener registration on a history.
///
/// Cancelling is idempotent, and releasing the last reference cancels the registration, so the
/// owner of the subscription decides how long its listener stays registered.
final class HistorySubscription {
  private var cancelBody: (() -> Void)?

  init(_ cancelBody: @escaping () -> Void) {
    self.cancelBody = cancelBody
  }

  deinit {
    cancel()
  }

  var isCancelled: Bool {
    cancelBody == nil
  }

  func cancel() {
    guard let cancelBody else { return }
    self.cancelBody = nil
    cancelBody()
  }
}

/// The listener storage behind a history adapter.
///
/// Subscriptions capture this storage rather than the history that owns it, so neither a
/// subscription nor a platform event callback keeps its history alive.
///
/// Delivery is serialized. A listener may change the history while it handles an update, for
/// example to redirect; that change is queued and delivered after every listener has seen the
/// current update. Every listener therefore sees updates in the order they happened, and the
/// last update it sees is the history's latest location.
final class HistoryListeners {
  private struct Entry {
    let id: Int
    /// The sequence number of the first update this listener receives.
    let firstSequence: Int
    let listener: (HistoryUpdate) -> Void
  }

  private struct Pending {
    let sequence: Int
    let update: HistoryUpdate
  }

  private var entries: [Entry] = []
  private var nextID = 0
  private var pending: [Pending] = []
  private var nextSequence = 0
  private var isDelivering = false

  var count: Int {
    entries.count
  }

  /// Registers `listener` for the updates that happen after this call and returns a
  /// subscription that removes it.
  ///
  /// A listener registered while an update is being delivered does not receive that update, or
  /// any other update queued before it registered, because the history had already moved past
  /// them. `onRemove` runs after the listener is removed, with the number of listeners that remain.
  func subscribe(
    _ listener: @escaping (HistoryUpdate) -> Void,
    onRemove: @escaping (Int) -> Void = { _ in }
  ) -> HistorySubscription {
    let id = nextID
    nextID += 1
    entries.append(Entry(id: id, firstSequence: nextSequence, listener: listener))
    return HistorySubscription { [self] in
      entries.removeAll { $0.id == id }
      onRemove(entries.count)
    }
  }

  /// Delivers `update` to every listener, after any update that is already being delivered.
  ///
  /// A listener cancelled before its turn is not called. A listener that changes the history on
  /// every update it receives never lets delivery finish, as with any redirect loop.
  func notify(_ update: HistoryUpdate) {
    pending.append(Pending(sequence: nextSequence, update: update))
    nextSequence += 1
    guard !isDelivering else { return }

    isDelivering = true
    while !pending.isEmpty {
      let next = pending.removeFirst()
      let snapshot = entries
      for entry in snapshot where entry.firstSequence <= next.sequence && isRegistered(entry.id) {
        entry.listener(next.update)
      }
    }
    isDelivering = false
  }

  private func isRegistered(_ id: Int) -> Bool {
    entries.contains { $0.id == id }
  }
}
