import ElementaryUI

/// Errors thrown while building a destination or href for a route.
public enum RouteMatchError: Error, Equatable, Sendable {
  /// The supplied route handle was registered by a different route builder, such as another
  /// `@Routes` type or a separate `routes()` call.
  case foreignRoute
  /// The supplied route handle belongs to this tree's builder but was registered after the tree
  /// was built.
  case unknownRoute
  /// A required path parameter was missing, or empty, while building the target URL, or a query
  /// value required by an enclosing layout was missing.
  case missingRequiredParameter(name: String)
  /// A path value would produce a segment that the browser changes or removes.
  ///
  /// This is thrown for a path parameter equal to `.` or `..`, and for a wildcard value with a
  /// `.` or `..` component or an empty component from a leading, trailing, or repeated `/`.
  /// `name` is `*` for wildcard values. Encoding cannot avoid it, because URL parsers also resolve
  /// `%2E` forms. The value is rejected in hash mode too, so destinations behave the same in
  /// both modes.
  case invalidPathSegment(name: String, value: String)
  /// A typed value encoded to a string that its `RouteValue` type cannot decode again, so the
  /// route could never read it back, or a value of the URL that an enclosing layout cannot decode.
  case invalidValue(name: String, rawValue: String, expected: String)
  /// The built URL does not resolve to the requested route.
  ///
  /// This happens when a route with higher matching precedence claims the URL, such as
  /// `/users/new` for `user(name: "new")` on `/users/:name`, or when the handle is a layout,
  /// which never matches a location on its own.
  case unroutableLocation(href: String)
}

/// The compiled route graph used by `Router` and `HashRouter`.
///
/// `RouteTree` is normally produced by `@Routes` through generated `routes()` APIs. It remains
/// public so the generated code in downstream modules can construct typed routers.
public struct RouteTree<RouteContent: View> {
  struct Record {
    let handle: RouteHandle
    let parent: RouteHandle?
    let pattern: RoutePattern
    /// `false` for layouts, which join a match stack but never match a location on their own.
    let isLeaf: Bool
    let render: Renderer
  }

  /// How a record takes part in rendering a matched stack.
  enum Renderer {
    /// Renders content from the parent-to-self contexts of the match stack.
    ///
    /// The last context is the record's own. Only the leaf record's content is rendered; the
    /// content of an ancestor record is evaluated for its errors and then discarded.
    case content(([RouteContext]) throws(RouteValueError) -> RouteContent)
    /// Decodes the record's own values without producing content.
    ///
    /// Generated layouts use this so a failed layout value is reported with the layout's own
    /// context before the leaf builds the whole view tree.
    case decode((RouteContext) throws(RouteValueError) -> Void)

    func evaluate(_ contexts: [RouteContext]) throws(RouteValueError) -> RouteContent? {
      switch self {
      case .content(let render):
        return try render(contexts)
      case .decode(let decode):
        try decode(contexts[contexts.count - 1])
        return nil
      }
    }
  }

  enum Resolution: Sendable {
    case matched(RouteContext)
    case notFound(RouteNotFoundContext)
    case error(RouteErrorContext)
  }

  /// The builder registration whose handles this tree accepts.
  let registration: RouteRegistration
  /// The identity of this compiled snapshot, shared by every copy of it.
  ///
  /// A builder can register more routes and build again, so two trees from one registration
  /// may resolve different handles; only copies of one `_build()` result are the same tree.
  let identity: RouteTreeIdentity
  let records: [Record]
  let notFoundRenderer: ((RouteNotFoundContext) -> RouteContent)?
  let errorRenderer: ((RouteErrorContext) -> RouteContent)?

  /// Returns `true` when both values are copies of the same `_build()` result.
  public func _isSameTree(as other: RouteTree<RouteContent>) -> Bool {
    identity === other.identity
  }

  /// Returns `true` when `route` was registered by the builder that produced this tree.
  func owns(_ route: RouteHandle) -> Bool {
    route.id.registration == registration
  }

  func _match(_ location: RouteLocation) -> RouteMatch? {
    _matches(location).last
  }

  func _matches(_ location: RouteLocation) -> [RouteMatch] {
    guard let leaf = findLeafRecord(for: location) else { return [] }
    return matchStack(for: leaf, location: location)
  }

  /// Builds a validated destination for a route handle from raw path, query, and hash values.
  ///
  /// Generated destination factories call this with values they encoded from typed arguments.
  /// The built location must resolve back to `route` in this tree, so a URL claimed by a route
  /// with higher precedence, or a layout handle, throws `RouteMatchError.unroutableLocation`.
  public func _destination(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) -> RouteDestination<RouteContent> {
    guard owns(route) else {
      throw RouteMatchError.foreignRoute
    }
    guard let record = records.first(where: { $0.handle == route }) else {
      throw RouteMatchError.unknownRoute
    }

    let trimmedHash = RouteLocation.trimmedHash(hash)
    let location = RouteLocation(
      path: try record.pattern.buildPath(params: params),
      queryString: QueryString.stringify(query),
      hash: URLCoding.encode(trimmedHash, spaceAsPlus: false)
    )
    guard findLeafRecord(for: location)?.handle == route,
      let resolvedParams = record.pattern.match(location.path)
    else {
      throw RouteMatchError.unroutableLocation(href: location.href)
    }
    try validateLayoutValues(of: record, at: location)

    return RouteDestination(
      route: route,
      location: location,
      params: resolvedParams,
      query: query,
      hash: trimmedHash
    )
  }

  /// Checks that `destination` targets a route of this tree and still resolves to it here.
  ///
  /// A destination built from another tree of the same builder is accepted when this tree
  /// registered the route and no route of this tree claims the location first. Routers and
  /// generated route sets call this before they turn a destination into an href or navigation.
  public func _validate(_ destination: RouteDestination<RouteContent>) throws(RouteMatchError) {
    guard owns(destination.route) else {
      throw RouteMatchError.foreignRoute
    }
    guard records.contains(where: { $0.handle == destination.route }) else {
      throw RouteMatchError.unknownRoute
    }
    guard findLeafRecord(for: destination.location)?.handle == destination.route else {
      throw RouteMatchError.unroutableLocation(href: destination.location.href)
    }
  }

  /// Builds an href for a route handle using the supplied path, query, and hash values.
  public func _href(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    try _destination(to: route, params: params, query: query, hash: hash).location.href
  }

  /// Builds a hash-mode href, such as `#/users/42?tab=posts`, for a route handle.
  ///
  /// The route path, query, and hash are encoded exactly as `_href` encodes them and then placed
  /// after a single `#`, without encoding them a second time. A fragment-only href resolves
  /// against the current document URL, so the app's base path and outer query string are kept
  /// for normal clicks, modified clicks, and copied links. A document `<base href>` element
  /// changes that resolution, so hash-mode apps should not declare one.
  public func _hashHref(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    try "#" + _href(to: route, params: params, query: query, hash: hash)
  }

  func _resolve(_ location: RouteLocation) -> Resolution {
    guard let record = findLeafRecord(for: location) else {
      return .notFound(
        RouteNotFoundContext(
          location: location,
          query: QueryString.parse(location.queryString)
        )
      )
    }

    let matches = matchStack(for: record, location: location)
    guard !matches.isEmpty else {
      return .notFound(
        RouteNotFoundContext(
          location: location,
          query: QueryString.parse(location.queryString)
        )
      )
    }

    let contexts = routeContexts(for: matches, location: location)
    switch evaluate(contexts) {
    case .success:
      return .matched(contexts[contexts.count - 1])
    case .failure(let error):
      return .error(error.context)
    }
  }

  func _render(_ location: RouteLocation) throws(RouterRenderError) -> RouteContent {
    guard let record = findLeafRecord(for: location) else {
      let context = RouteNotFoundContext(
        location: location,
        query: QueryString.parse(location.queryString)
      )
      guard let notFoundRenderer else {
        throw RouterRenderError.routeNotFound
      }
      return notFoundRenderer(context)
    }

    let matches = matchStack(for: record, location: location)
    guard !matches.isEmpty else {
      let context = RouteNotFoundContext(
        location: location,
        query: QueryString.parse(location.queryString)
      )
      guard let notFoundRenderer else {
        throw RouterRenderError.routeNotFound
      }
      return notFoundRenderer(context)
    }

    let contexts = routeContexts(for: matches, location: location)
    switch evaluate(contexts) {
    case .success(let rendered):
      guard let rendered else {
        throw RouterRenderError.routeNotFound
      }
      return rendered
    case .failure(let failure):
      guard let errorRenderer else {
        throw RouterRenderError.routeRenderFailed(failure.context.error)
      }
      return errorRenderer(failure.context)
    }
  }

  /// A route value error reported with the context of the record that threw it.
  struct EvaluationFailure: Error {
    let context: RouteErrorContext
  }

  /// Evaluates every record of a match stack from parent to leaf and returns the leaf content.
  ///
  /// Each record sees the contexts from the root to itself, so a failure is reported with the
  /// context of the outermost record that threw, and no descendant is evaluated after it.
  private func evaluate(
    _ contexts: [RouteContext]
  ) -> Result<RouteContent?, EvaluationFailure> {
    let recordsByID = recordsByRouteID()
    var rendered: RouteContent?

    for index in contexts.indices {
      let context = contexts[index]
      guard let record = recordsByID[context.route.id] else { continue }

      do throws(RouteValueError) {
        let content = try record.render.evaluate(Array(contexts[...index]))
        rendered = index == contexts.count - 1 ? content : nil
      } catch {
        return .failure(
          EvaluationFailure(context: RouteErrorContext(error: error, routeContext: context))
        )
      }
    }

    return .success(rendered)
  }

  /// Checks that every generated layout above `leaf` can decode its own values at `location`.
  ///
  /// A destination is only valid when the whole match stack renders, so a layout's required
  /// query that is missing, or a layout value its type cannot decode, rejects the destination
  /// instead of producing a URL that renders `@RouteError`. Layouts registered with a content
  /// renderer are not evaluated here, because their renderers may have effects.
  private func validateLayoutValues(
    of leaf: Record,
    at location: RouteLocation
  ) throws(RouteMatchError) {
    let matches = matchStack(for: leaf, location: location)
    let recordsByID = recordsByRouteID()
    for context in routeContexts(for: matches, location: location).dropLast() {
      guard let record = recordsByID[context.route.id],
        case .decode(let decode) = record.render
      else {
        continue
      }
      do throws(RouteValueError) {
        try decode(context)
      } catch {
        switch error {
        case .missing(let name):
          throw RouteMatchError.missingRequiredParameter(name: name)
        case .invalid(let name, let rawValue, let expected):
          throw RouteMatchError.invalidValue(name: name, rawValue: rawValue, expected: expected)
        }
      }
    }
  }

  private func findLeafRecord(for location: RouteLocation) -> Record? {
    for record in records where record.isLeaf {
      if record.pattern.match(location.path) != nil {
        return record
      }
    }
    return nil
  }

  private func matchStack(
    for leaf: Record,
    location: RouteLocation
  ) -> [RouteMatch] {
    let recordsByID = recordsByRouteID()

    var chain: [Record] = []
    var current: Record? = leaf
    while let record = current {
      chain.append(record)
      if let parent = record.parent {
        current = recordsByID[parent.id]
      } else {
        current = nil
      }
    }

    // Every record of the chain must match, so the stack always has one entry per ancestor.
    // Generated renderers rely on this to read each layout's context by its depth.
    var matches: [RouteMatch] = []
    for record in chain.reversed() {
      let params =
        record.handle == leaf.handle
        ? record.pattern.match(location.path)
        : record.pattern.prefixMatch(location.path)
      guard let params else {
        return []
      }
      matches.append(RouteMatch(route: record.handle, path: record.pattern.path, params: params))
    }
    return matches
  }

  private func recordsByRouteID() -> [RouteHandle.ID: Record] {
    var recordsByID: [RouteHandle.ID: Record] = [:]
    for record in records {
      recordsByID[record.handle.id] = record
    }
    return recordsByID
  }

  private func routeContexts(for matches: [RouteMatch], location: RouteLocation) -> [RouteContext] {
    var contexts: [RouteContext] = []
    contexts.reserveCapacity(matches.count)

    let query = QueryString.parse(location.queryString)
    let matchedRoutes = matches.map { $0.route }

    for match in matches {
      contexts.append(
        RouteContext(
          route: match.route,
          path: match.path,
          params: match.params,
          query: query,
          location: location,
          matchedRoutes: matchedRoutes
        )
      )
    }

    return contexts
  }
}
