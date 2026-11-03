protocol RouterHistory: AnyObject {
  var location: RouteLocation { get }
  func push(_ location: RouteLocation)
  func replace(_ location: RouteLocation)
  func go(_ delta: Int)
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

final class HistorySubscription {
  private var cancelBody: (() -> Void)?

  init(_ cancelBody: @escaping () -> Void) {
    self.cancelBody = cancelBody
  }

  func cancel() {
    cancelBody?()
    cancelBody = nil
  }
}
