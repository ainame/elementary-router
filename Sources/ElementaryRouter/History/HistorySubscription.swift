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
