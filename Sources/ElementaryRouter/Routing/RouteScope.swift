import ElementaryUI

public struct RouteScope<RouteContent: View> {
  private let collection: RouteCollection<RouteContent>
  private let prefix: String
  private let parent: RouteHandle?

  init(
    collection: RouteCollection<RouteContent>,
    prefix: String,
    parent: RouteHandle?
  ) {
    self.collection = collection
    self.prefix = RouteLocation.normalizedPath(prefix)
    self.parent = parent
  }

  @discardableResult
  public func route(
    _ path: String,
    @HTMLBuilder render: @escaping () -> RouteContent
  ) -> RouteHandle {
    let typed: (RouteContext) throws(RouteValueError) -> RouteContent = {
      _ throws(RouteValueError) in
      render()
    }
    return collection.add(path: joined(path), parent: parent, render: typed)
  }

  @discardableResult
  public func route(
    _ path: String,
    @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    return collection.add(path: joined(path), parent: parent, render: render)
  }

  public func scope(_ path: String) -> RouteScope<RouteContent> {
    RouteScope(collection: collection, prefix: joined(path), parent: parent)
  }

  private func joined(_ path: String) -> String {
    if path == "/" || path.isEmpty { return prefix }
    let child = path.first == "/" ? String(path.dropFirst()) : path
    if prefix == "/" { return "/" + child }
    return prefix + "/" + child
  }
}
