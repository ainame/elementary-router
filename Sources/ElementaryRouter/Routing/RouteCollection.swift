import ElementaryUI

public final class RouteCollection<RouteContent: View> {
  private var records: [RouteRecordBuilder<RouteContent>] = []
  private var notFoundRenderer: ((RouteNotFoundContext) -> RouteContent)?
  private var errorRenderer: ((RouteErrorContext) -> RouteContent)?
  private var nextID = 0

  public init() {}

  @discardableResult
  public func route(
    _ path: String,
    @HTMLBuilder render: @escaping () -> RouteContent
  ) -> RouteHandle {
    let typed: (RouteContext) throws(RouteValueError) -> RouteContent = {
      _ throws(RouteValueError) in
      render()
    }
    return add(path: path, parent: nil, render: typed)
  }

  @discardableResult
  public func route(
    _ path: String,
    @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    return add(path: path, parent: nil, render: render)
  }

  public func scope(_ path: String) -> RouteScope<RouteContent> {
    RouteScope(collection: self, prefix: path, parent: nil)
  }

  public func children(of parent: RouteHandle) -> RouteScope<RouteContent> {
    guard let record = records.first(where: { $0.handle == parent }) else {
      preconditionFailure("Cannot create child routes for a handle that is not in this collection.")
    }
    return RouteScope(collection: self, prefix: record.path, parent: parent)
  }

  public func notFound(
    @HTMLBuilder render: @escaping (RouteNotFoundContext) -> RouteContent
  ) {
    notFoundRenderer = render
  }

  public func error(
    @HTMLBuilder render: @escaping (RouteErrorContext) -> RouteContent
  ) {
    errorRenderer = render
  }

  public func freeze() throws(RouteTreeError) -> RouteTree<RouteContent> {
    var compiled: [CompiledRouteRecord<RouteContent>] = []
    var seenPaths: [String] = []

    for record in records {
      let pattern = try RoutePattern(record.path)
      if seenPaths.contains(pattern.path) {
        throw RouteTreeError.duplicateRoute(path: pattern.path)
      }
      seenPaths.append(pattern.path)
      compiled.append(
        CompiledRouteRecord(
          handle: record.handle,
          parent: record.parent,
          pattern: pattern,
          render: record.render
        )
      )
    }

    compiled.sort {
      if $0.pattern.specificity == $1.pattern.specificity {
        $0.handle.id.rawValue < $1.handle.id.rawValue
      } else {
        $0.pattern.specificity > $1.pattern.specificity
      }
    }

    return RouteTree(
      records: compiled,
      notFoundRenderer: notFoundRenderer,
      errorRenderer: errorRenderer
    )
  }

  @discardableResult
  fileprivate func add(
    path: String,
    parent: RouteHandle?,
    render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    let handle = RouteHandle(id: RouteID(rawValue: nextID))
    nextID += 1
    records.append(RouteRecordBuilder(handle: handle, parent: parent, path: path, render: render))
    return handle
  }
}

public final class RouteScope<RouteContent: View> {
  private let collection: RouteCollection<RouteContent>
  private let prefix: String
  private let parent: RouteHandle?

  fileprivate init(
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

private struct RouteRecordBuilder<RouteContent: View> {
  let handle: RouteHandle
  let parent: RouteHandle?
  let path: String
  let render: (RouteContext) throws(RouteValueError) -> RouteContent
}

struct CompiledRouteRecord<RouteContent: View> {
  let handle: RouteHandle
  let parent: RouteHandle?
  let pattern: RoutePattern
  let render: (RouteContext) throws(RouteValueError) -> RouteContent
}
