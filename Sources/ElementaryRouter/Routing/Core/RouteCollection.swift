import ElementaryUI

public final class RouteCollection<RouteContent: View> {
  private var records: [RecordBuilder] = []
  private var notFoundRenderer: ((RouteNotFoundContext) -> RouteContent)?
  private var errorRenderer: ((RouteErrorContext) -> RouteContent)?
  private var nextID = 0

  public init() {}

  @discardableResult
  public func route(
    _ path: String,
    @HTMLBuilder render: @escaping () -> RouteContent
  ) -> RouteHandle {
    route(path, parent: nil, render: render)
  }

  @discardableResult
  public func route(
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

  @discardableResult
  public func route(
    _ path: String,
    @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    route(path, parent: nil, render: render)
  }

  @discardableResult
  public func route(
    _ path: String,
    parent: RouteHandle?,
    @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    return add(path: path, parent: parent, render: render)
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
    var compiled: [RouteTree<RouteContent>.Record] = []
    var seenPaths: [String] = []

    for record in records {
      let pattern = try RoutePattern(record.path)
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
}
