import ElementaryUI

/// Errors thrown while compiling a route tree from declared records.
public enum RouteTreeError: Error, Equatable, Sendable {
  /// Two route declarations produced the same final path pattern.
  case duplicateRoute(path: String)
  /// A path pattern declared the same parameter name more than once.
  case duplicateParameter(path: String, name: String)
}

/// Builds a typed route tree programmatically.
///
/// Most applications use `@Routes`, which generates calls into `RouteBuilder`. The type remains
/// public so macro expansion in downstream modules can compile and so advanced callers can build a
/// route tree manually when needed.
public final class RouteBuilder<RouteContent: View> {
  private var records: [RecordBuilder] = []
  private var notFoundRenderer: ((RouteNotFoundContext) -> RouteContent)?
  private var errorRenderer: ((RouteErrorContext) -> RouteContent)?
  private var nextID = 0

  /// Creates an empty route builder.
  public init() {}

  /// Registers a route that does not need a `RouteContext`.
  @discardableResult
  public func _route(
    _ path: String,
    @HTMLBuilder render: @escaping () -> RouteContent
  ) -> RouteHandle {
    _route(path, parent: nil, render: render)
  }

  /// Registers a nested route that does not need a `RouteContext`.
  @discardableResult
  public func _route(
    _ path: String,
    parent: RouteHandle?,
    @HTMLBuilder render: @escaping () -> RouteContent
  ) -> RouteHandle {
    let typed: (RouteContext) throws(RouteValueError) -> RouteContent = {
      _ throws(RouteValueError) in
      render()
    }
    return add(path: path, parent: parent, render: typed)
  }

  /// Registers a route that renders from a full `RouteContext`.
  @discardableResult
  public func _route(
    _ path: String,
    @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    _route(path, parent: nil, render: render)
  }

  /// Registers a nested route that renders from a full `RouteContext`.
  @discardableResult
  public func _route(
    _ path: String,
    parent: RouteHandle?,
    @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    return add(path: path, parent: parent, render: render)
  }

  /// Registers the renderer used when no route matches the current location.
  public func _notFound(
    @HTMLBuilder render: @escaping (RouteNotFoundContext) -> RouteContent
  ) {
    notFoundRenderer = render
  }

  /// Registers the renderer used when a matched route throws `RouteValueError`.
  public func _error(
    @HTMLBuilder render: @escaping (RouteErrorContext) -> RouteContent
  ) {
    errorRenderer = render
  }

  /// Compiles the registered route records into a `RouteTree`.
  public func _build() throws(RouteTreeError) -> RouteTree<RouteContent> {
    var compiled: [RouteTree<RouteContent>.Record] = []
    var seenPaths: [String] = []
    let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.handle.id, $0) })

    for record in records {
      let pattern = try RoutePattern(resolvedPath(for: record, recordsByID: recordsByID))
      if seenPaths.contains(pattern.path) {
        throw RouteTreeError.duplicateRoute(path: pattern.path)
      }
      seenPaths.append(pattern.path)
      compiled.append(
        RouteTree.Record(
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
  func add(
    path: String,
    parent: RouteHandle?,
    render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    let handle = RouteHandle(id: .init(rawValue: nextID))
    nextID += 1
    records.append(RecordBuilder(handle: handle, parent: parent, path: path, render: render))
    return handle
  }

  private struct RecordBuilder {
    let handle: RouteHandle
    let parent: RouteHandle?
    let path: String
    let render: (RouteContext) throws(RouteValueError) -> RouteContent
  }

  private func resolvedPath(
    for record: RecordBuilder,
    recordsByID: [RouteHandle.ID: RecordBuilder]
  ) -> String {
    guard let parent = record.parent, let parentRecord = recordsByID[parent.id] else {
      return record.path
    }

    let parentPath = RouteLocation.normalizedPath(
      resolvedPath(for: parentRecord, recordsByID: recordsByID)
    )
    if record.path == "/" {
      return parentPath
    }

    let childPath = record.path == "/" ? "" : record.path
    let trimmedParent =
      parentPath.count > 1 && parentPath.last == "/" ? String(parentPath.dropLast()) : parentPath
    let trimmedChild = childPath.first == "/" ? String(childPath.dropFirst()) : childPath
    return trimmedChild.isEmpty ? trimmedParent : trimmedParent + "/" + trimmedChild
  }
}
