public struct ActiveMatchOptions: Equatable, Sendable {
  public var includeDescendants: Bool
  public var params: RouteParameters?
  public var query: RouteParameters?
  public var hash: String?

  public init(
    includeDescendants: Bool = false,
    params: RouteParameters? = nil,
    query: RouteParameters? = nil,
    hash: String? = nil
  ) {
    self.includeDescendants = includeDescendants
    self.params = params
    self.query = query
    self.hash = hash
  }

  public static var exact: Self {
    Self()
  }

  public static var descendant: Self {
    Self(includeDescendants: true)
  }
}
