import ElementaryUI

/// Errors thrown while building an href from a route handle.
public enum RouteMatchError: Error, Equatable, Sendable {
  /// The supplied route handle was registered by a different route builder, such as another
  /// `@Routes` type or a separate `routes()` call.
  case foreignRoute
  /// The supplied route handle belongs to this tree's builder but was registered after the tree
  /// was built.
  case unknownRoute
  /// A required path parameter was missing, or empty, while building the target URL.
  case missingRequiredParameter(name: String)
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
    let render: (RouteContext) throws(RouteValueError) -> RouteContent
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

  /// Builds an href for a route handle using the supplied path, query, and hash values.
  public func _href(
    to route: RouteHandle,
    params: RouteValues = RouteValues(),
    query: RouteValues = RouteValues(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    guard owns(route) else {
      throw RouteMatchError.foreignRoute
    }
    guard let record = records.first(where: { $0.handle == route }) else {
      throw RouteMatchError.unknownRoute
    }

    var href = try record.pattern.buildPath(params: params)
    let queryString = QueryString.stringify(query)
    if !queryString.isEmpty {
      href += "?" + queryString
    }
    let trimmedHash = RouteLocation.trimmedHash(hash)
    if !trimmedHash.isEmpty {
      href += "#" + URLCoding.encode(trimmedHash, spaceAsPlus: false)
    }
    return href
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
    let recordsByID = recordsByRouteID()

    for context in contexts {
      guard let record = recordsByID[context.route.id] else { continue }

      do throws(RouteValueError) {
        _ = try record.render(context)
      } catch {
        return .error(RouteErrorContext(error: error, routeContext: context))
      }
    }

    return .matched(contexts[contexts.count - 1])
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
    let recordsByID = recordsByRouteID()
    var rendered: RouteContent?

    for context in contexts {
      guard let record = recordsByID[context.route.id] else { continue }

      do throws(RouteValueError) {
        rendered = try record.render(context)
      } catch {
        let errorContext = RouteErrorContext(error: error, routeContext: context)
        guard let errorRenderer else {
          throw RouterRenderError.routeRenderFailed(error)
        }
        return errorRenderer(errorContext)
      }
    }

    guard let rendered else {
      throw RouterRenderError.routeNotFound
    }
    return rendered
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

    var matches: [RouteMatch] = []
    for record in chain.reversed() {
      let params =
        record.handle == leaf.handle
        ? record.pattern.match(location.path)
        : record.pattern.prefixMatch(location.path)
      if let params {
        matches.append(RouteMatch(route: record.handle, path: record.pattern.path, params: params))
      }
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
