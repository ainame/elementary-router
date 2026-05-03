public struct HistoryUpdate: Equatable, Sendable {
  public let action: HistoryAction
  public let location: RouteLocation

  public init(action: HistoryAction, location: RouteLocation) {
    self.action = action
    self.location = location
  }
}
