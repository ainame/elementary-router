public struct RouteTree {
  let records: [CompiledRouteRecord]
  let notFoundRenderer: ((RouteNotFoundContext) -> Void)?
  let errorRenderer: ((RouteErrorContext) -> Void)?

  public func match(_ location: RouteLocation) -> RouteMatch? {
    matches(location).last
  }

  public func matches(_ location: RouteLocation) -> [RouteMatch] {
    guard let leaf = findLeafRecord(for: location) else { return [] }
    return matchStack(for: leaf, location: location)
  }

  public func href(
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

  public func resolve(_ location: RouteLocation) -> RouteRenderResolution {
    guard let record = findLeafRecord(for: location) else {
      return .notFound(
        RouteNotFoundContext(
          location: location,
          query: QueryString.parse(location.queryString)
        )
      )
    }

    let matches = matchStack(for: record, location: location)
    guard let match = matches.last else {
      return .notFound(
        RouteNotFoundContext(
          location: location,
          query: QueryString.parse(location.queryString)
        )
      )
    }

    let context = RouteContext(
      params: combinedParams(from: matches),
      query: QueryString.parse(location.queryString),
      location: location,
      match: match,
      matches: matches
    )

    do throws(RouteValueError) {
      try record.render(context)
      return .matched(context)
    } catch {
      return .error(RouteErrorContext(error: error, routeContext: context))
    }
  }

  func render(_ location: RouteLocation) throws(RouterRenderError) {
    switch resolve(location) {
    case .matched:
      throw RouterRenderError.unavailableUntilElementaryUIExposesTypeErasedView
    case .notFound(let context):
      notFoundRenderer?(context)
      throw RouterRenderError.unavailableUntilElementaryUIExposesTypeErasedView
    case .error(let context):
      if let errorRenderer {
        errorRenderer(context)
        throw RouterRenderError.unavailableUntilElementaryUIExposesTypeErasedView
      }
      throw RouterRenderError.routeRenderFailed(context.error)
    }
  }

  private func findLeafRecord(for location: RouteLocation) -> CompiledRouteRecord? {
    for record in records {
      if record.pattern.match(location.path) != nil {
        return record
      }
    }
    return nil
  }

  private func matchStack(for leaf: CompiledRouteRecord, location: RouteLocation) -> [RouteMatch] {
    var recordsByID: [RouteID: CompiledRouteRecord] = [:]
    for record in records {
      recordsByID[record.handle.id] = record
    }

    var chain: [CompiledRouteRecord] = []
    var current: CompiledRouteRecord? = leaf
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

  private func combinedParams(from matches: [RouteMatch]) -> RouteParameters {
    var params = RouteParameters()
    for match in matches {
      for (name, value) in match.params.pairs {
        params.append(name, value)
      }
    }
    return params
  }
}
