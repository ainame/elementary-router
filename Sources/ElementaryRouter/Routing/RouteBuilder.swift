import ElementaryUI

/// Errors thrown while compiling a route tree from declared records.
public enum RouteTreeError: Error, Equatable, Sendable {
  /// Two route declarations produced the same final path pattern.
  case duplicateRoute(path: String)
  /// Two route declarations match exactly the same URLs, so neither can take precedence.
  ///
  /// This happens when patterns differ only by parameter names, such as `/users/:id` and
  /// `/users/:name`, or only by the percent-encoding of a static segment.
  case ambiguousRoute(path: String, conflictingPath: String)
  /// A path pattern declared the same parameter name more than once.
  case duplicateParameter(path: String, name: String)
  /// A path pattern used `*` before its final segment.
  case invalidWildcard(path: String)
  /// A path pattern contained a static `.` or `..` segment, including `%2E` forms.
  ///
  /// Browsers resolve dot segments before routing, so such a route could never be reached.
  case dotSegment(path: String)
  /// A route or layout declared at `path` named a parent handle registered by a different
  /// `RouteBuilder`.
  case foreignParent(path: String)
  /// One feature type was mounted at `path` and again at `conflictingPath`.
  ///
  /// Feature views find their route set by its type, so the views of both mounts would read the
  /// same route set and link into one of them.
  case duplicateFeature(path: String, conflictingPath: String)
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
  private let registration = RouteRegistration()
  private var nextIndex = 0

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
    add(path: path, parent: parent, isLeaf: true, render: .content { _ in render() })
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
    add(path: path, parent: parent, isLeaf: true, render: ownContextRenderer(render))
  }

  /// Registers a route that renders from every context of its match stack.
  ///
  /// `render` receives one context per matched record, from the outermost ancestor to this
  /// route, so `contexts.last` is the route's own context and `contexts[0]` is the context of
  /// its outermost layout. Generated `@Routes` code uses this to give each enclosing layout its
  /// own decoded values. Ancestors registered with `_generatedLayout(_:parent:decode:)` have
  /// already decoded their values successfully when `render` runs.
  @discardableResult
  public func _generatedRoute(
    _ path: String,
    parent: RouteHandle?,
    render: @escaping ([RouteContext]) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    add(path: path, parent: parent, isLeaf: true, render: .content(render))
  }

  /// Registers a layout that does not need a `RouteContext`.
  ///
  /// A layout only composes its descendants. It joins the match stack when one of its
  /// descendants matches, but never matches a location on its own; register a route at the same
  /// path under the layout to make that path navigable.
  @discardableResult
  public func _layout(
    _ path: String,
    parent: RouteHandle?,
    @HTMLBuilder render: @escaping () -> RouteContent
  ) -> RouteHandle {
    add(path: path, parent: parent, isLeaf: false, render: .content { _ in render() })
  }

  /// Registers a layout that renders from a full `RouteContext`.
  ///
  /// A layout only composes its descendants. It joins the match stack when one of its
  /// descendants matches, but never matches a location on its own.
  @discardableResult
  public func _layout(
    _ path: String,
    parent: RouteHandle?,
    @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteHandle {
    add(path: path, parent: parent, isLeaf: false, render: ownContextRenderer(render))
  }

  /// Registers a layout that only decodes its own values.
  ///
  /// The layout's content is built by its descendant routes, which are registered with
  /// `_generatedRoute(_:parent:render:)`. `decode` runs with the layout's own context before any
  /// descendant renders; a `RouteValueError` it throws is reported with that context.
  @discardableResult
  public func _generatedLayout(
    _ path: String,
    parent: RouteHandle?,
    decode: @escaping (RouteContext) throws(RouteValueError) -> Void
  ) -> RouteHandle {
    add(path: path, parent: parent, isLeaf: false, render: .decode(decode))
  }

  /// Rejects a feature type mounted at more than one path.
  ///
  /// Each entry is the environment identity of a mounted feature's route set, such as
  /// `ShopRoutes<AppRoutes.RouteView>.RouteSet._environmentIdentity`, with its mount path. The
  /// identity is the specialized type itself, so aliases and module-qualified spellings of one
  /// feature are found, while features of other modules that share its name are not. Generated
  /// hosts call this before they register any route.
  public static func _checkDistinctFeatures(
    _ mounts: [(identity: ObjectIdentifier, path: String)]
  ) throws(RouteTreeError) {
    for index in mounts.indices {
      for earlier in mounts[..<index] where earlier.identity == mounts[index].identity {
        throw RouteTreeError.duplicateFeature(path: mounts[index].path, conflictingPath: earlier.path)
      }
    }
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
    let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.handle.id, $0) })

    // Handles are only created by registration, so a parent from this builder is always present.
    for record in records {
      if let parent = record.parent, parent.id.registration != registration {
        throw RouteTreeError.foreignParent(path: record.path)
      }
    }

    for record in records {
      let pattern = try RoutePattern(resolvedPath(for: record, recordsByID: recordsByID))
      // Routes conflict with routes and layouts with layouts. A layout never matches on its own,
      // so a layout sharing a path with an unrelated route cannot make matching ambiguous.
      // Records in the same ancestor chain may share a path: an index route under a layout.
      for seen in compiled
      where seen.isLeaf == record.isLeaf && seen.pattern.shape == pattern.shape {
        guard let seenRecord = recordsByID[seen.handle.id],
          !isAncestor(record, of: seenRecord, recordsByID: recordsByID),
          !isAncestor(seenRecord, of: record, recordsByID: recordsByID)
        else {
          continue
        }
        if seen.pattern.path == pattern.path {
          throw RouteTreeError.duplicateRoute(path: pattern.path)
        }
        throw RouteTreeError.ambiguousRoute(path: pattern.path, conflictingPath: seen.pattern.path)
      }
      compiled.append(
        RouteTree.Record(
          handle: record.handle,
          parent: record.parent,
          pattern: pattern,
          isLeaf: record.isLeaf,
          render: record.render
        )
      )
    }

    compiled.sort { lhs, rhs in
      let rank = lhs.pattern.compareRank(to: rhs.pattern)
      if rank != 0 {
        return rank < 0
      }
      let leftDepth = depth(of: lhs, recordsByID: recordsByID)
      let rightDepth = depth(of: rhs, recordsByID: recordsByID)
      if leftDepth != rightDepth {
        return leftDepth > rightDepth
      }
      return lhs.handle.id.index < rhs.handle.id.index
    }

    return RouteTree(
      registration: registration,
      identity: RouteTreeIdentity(),
      records: compiled,
      notFoundRenderer: notFoundRenderer,
      errorRenderer: errorRenderer
    )
  }

  private func ownContextRenderer(
    _ render: @escaping (RouteContext) throws(RouteValueError) -> RouteContent
  ) -> RouteTree<RouteContent>.Renderer {
    .content { contexts throws(RouteValueError) in
      try render(contexts[contexts.count - 1])
    }
  }

  @discardableResult
  func add(
    path: String,
    parent: RouteHandle?,
    isLeaf: Bool,
    render: RouteTree<RouteContent>.Renderer
  ) -> RouteHandle {
    let handle = RouteHandle(id: .init(registration: registration, index: nextIndex))
    nextIndex += 1
    records.append(
      RecordBuilder(handle: handle, parent: parent, path: path, isLeaf: isLeaf, render: render)
    )
    return handle
  }

  private struct RecordBuilder {
    let handle: RouteHandle
    let parent: RouteHandle?
    let path: String
    let isLeaf: Bool
    let render: RouteTree<RouteContent>.Renderer
  }

  private func isAncestor(
    _ ancestor: RecordBuilder,
    of descendant: RecordBuilder,
    recordsByID: [RouteHandle.ID: RecordBuilder]
  ) -> Bool {
    var current = descendant.parent.flatMap { recordsByID[$0.id] }
    while let record = current {
      if record.handle == ancestor.handle { return true }
      current = record.parent.flatMap { recordsByID[$0.id] }
    }
    return false
  }

  private func depth(
    of record: RouteTree<RouteContent>.Record,
    recordsByID: [RouteHandle.ID: RecordBuilder]
  ) -> Int {
    var depth = 0
    var current = record.parent.flatMap { recordsByID[$0.id] }
    while let record = current {
      depth += 1
      current = record.parent.flatMap { recordsByID[$0.id] }
    }
    return depth
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
    if trimmedChild.isEmpty {
      return trimmedParent
    }
    // A root parent already ends with the separator, so `:lang` under `/` is `/:lang`.
    return trimmedParent == "/" ? "/" + trimmedChild : trimmedParent + "/" + trimmedChild
  }
}
