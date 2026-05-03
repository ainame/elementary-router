import ElementaryUI

public struct Wildcard: Equatable, Sendable {
  public let value: String

  public init(_ value: String) {
    self.value = value
  }
}

@View
public struct Outlet<Content: View> {
  let content: Content

  public init(_ content: Content) {
    self.content = content
  }

  public var body: some View {
    content
  }
}

public struct Query<Value: RouteValue>: Equatable, Sendable where Value: Equatable & Sendable {
  public let value: Value

  public init(_ value: Value) {
    self.value = value
  }
}

extension Query where Value == String {
  public init(stringLiteral value: String) {
    self.value = value
  }
}
