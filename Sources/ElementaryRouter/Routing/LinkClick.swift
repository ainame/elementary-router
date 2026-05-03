public struct LinkClick: Equatable, Sendable {
  public let button: Int
  public let altKey: Bool
  public let ctrlKey: Bool
  public let metaKey: Bool
  public let shiftKey: Bool
  public let target: String?

  public init(
    button: Int,
    altKey: Bool = false,
    ctrlKey: Bool = false,
    metaKey: Bool = false,
    shiftKey: Bool = false,
    target: String? = nil
  ) {
    self.button = button
    self.altKey = altKey
    self.ctrlKey = ctrlKey
    self.metaKey = metaKey
    self.shiftKey = shiftKey
    self.target = target
  }

  public var shouldIntercept: Bool {
    button == 0
      && !altKey
      && !ctrlKey
      && !metaKey
      && !shiftKey
      && (target == nil || target == "" || target == "_self")
  }
}
