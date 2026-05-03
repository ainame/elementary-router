public final class HistorySubscription {
  private var cancelBody: (() -> Void)?

  init(_ cancelBody: @escaping () -> Void) {
    self.cancelBody = cancelBody
  }

  public func cancel() {
    cancelBody?()
    cancelBody = nil
  }
}
