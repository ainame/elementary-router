import ElementaryUI

public final class RouteCollection {
  private var records: [RouteRecordBuilder] = []
  private var notFoundRenderer: ((RouteNotFoundContext) -> Void)?
  private var errorRenderer: ((RouteErrorContext) -> Void)?
  private var nextID = 0

  public init() {}

  @discardableResult
  public func route<Content: View>(
    _ path: String,
    @HTMLBuilder render: @escaping () -> Content
  ) -> RouteHandle {
    let erased: (RouteContext) throws(RouteValueError) -> Void = { _ throws(RouteValueError) in
      _ = render()
    }
    return add(path: path, parent: nil, render: erased)
  }

  @discardableResult
  public func route<Content: View>(
    _ path: String,
    @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> Content
  ) -> RouteHandle {
    let erased: (RouteContext) throws(RouteValueError) -> Void = {
      context throws(RouteValueError) in
      _ = try render(context)
    }
    return add(path: path, parent: nil, render: erased)
  }

  public func scope(_ path: String) -> RouteScope {
    RouteScope(collection: self, prefix: path, parent: nil)
  }

  public func children(of parent: RouteHandle) -> RouteScope {
    guard let record = records.first(where: { $0.handle == parent }) else {
      preconditionFailure("Cannot create child routes for a handle that is not in this collection.")
    }
    return RouteScope(collection: self, prefix: record.path, parent: parent)
  }

  public func notFound<Content: View>(
    @HTMLBuilder render: @escaping (RouteNotFoundContext) -> Content
  ) {
    notFoundRenderer = { context in _ = render(context) }
  }

  public func error<Content: View>(
    @HTMLBuilder render: @escaping (RouteErrorContext) -> Content
  ) {
    errorRenderer = { context in _ = render(context) }
  }

  public func freeze() throws(RouteTreeError) -> RouteTree {
    var compiled: [CompiledRouteRecord] = []
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
    render: @escaping (RouteContext) throws(RouteValueError) -> Void
  ) -> RouteHandle {
    let handle = RouteHandle(id: RouteID(rawValue: nextID))
    nextID += 1
    records.append(RouteRecordBuilder(handle: handle, parent: parent, path: path, render: render))
    return handle
  }
}

public final class RouteScope {
  private let collection: RouteCollection
  private let prefix: String
  private let parent: RouteHandle?

  fileprivate init(collection: RouteCollection, prefix: String, parent: RouteHandle?) {
    self.collection = collection
    self.prefix = RouteLocation.normalizedPath(prefix)
    self.parent = parent
  }

  @discardableResult
  public func route<Content: View>(
    _ path: String,
    @HTMLBuilder render: @escaping () -> Content
  ) -> RouteHandle {
    let erased: (RouteContext) throws(RouteValueError) -> Void = { _ throws(RouteValueError) in
      _ = render()
    }
    return collection.add(path: joined(path), parent: parent, render: erased)
  }

  @discardableResult
  public func route<Content: View>(
    _ path: String,
    @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> Content
  ) -> RouteHandle {
    let erased: (RouteContext) throws(RouteValueError) -> Void = {
      context throws(RouteValueError) in
      _ = try render(context)
    }
    return collection.add(path: joined(path), parent: parent, render: erased)
  }

  public func scope(_ path: String) -> RouteScope {
    RouteScope(collection: collection, prefix: joined(path), parent: parent)
  }

  private func joined(_ path: String) -> String {
    if path == "/" || path.isEmpty { return prefix }
    let child = path.first == "/" ? String(path.dropFirst()) : path
    if prefix == "/" { return "/" + child }
    return prefix + "/" + child
  }
}

private struct RouteRecordBuilder {
  let handle: RouteHandle
  let parent: RouteHandle?
  let path: String
  let render: (RouteContext) throws(RouteValueError) -> Void
}

struct CompiledRouteRecord {
  let handle: RouteHandle
  let parent: RouteHandle?
  let pattern: RoutePattern
  let render: (RouteContext) throws(RouteValueError) -> Void
}
