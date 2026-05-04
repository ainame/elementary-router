import ElementaryUI

public enum RouteMatchError: Error, Equatable, Sendable {
  case unknownRoute
  case missingRequiredParameter(name: String)
}

public struct RouteTree<RouteContent: View> {
  struct Record {
    let handle: RouteHandle
    let parent: RouteHandle?
    let pattern: RoutePattern
    let render: (RouteContext) throws(RouteValueError) -> RouteContent
  }

  enum Resolution: Sendable {
    case matched(RouteContext)
    case notFound(RouteNotFoundContext)
    case error(RouteErrorContext)
  }

  let records: [Record]
  let notFoundRenderer: ((RouteNotFoundContext) -> RouteContent)?
  let errorRenderer: ((RouteErrorContext) -> RouteContent)?

  func _match(_ location: RouteLocation) -> RouteMatch? {
    _matches(location).last
  }

  func _matches(_ location: RouteLocation) -> [RouteMatch] {
    guard let leaf = findLeafRecord(for: location) else { return [] }
    return matchStack(for: leaf, location: location)
  }

  public func _href(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
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
    for record in records {
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
    let matchedRoutes = matches.map(\.route)

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
