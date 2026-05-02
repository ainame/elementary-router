public struct RouteTree {
  let records: [CompiledRouteRecord]
  let notFoundRenderer: ((RouteNotFoundContext) -> Void)?
  let errorRenderer: ((RouteErrorContext) -> Void)?

  public func match(_ location: RouteLocation) -> RouteMatch? {
    findRecord(for: location).match
  }

  public func href(
    to route: RouteHandle,
    params: RouteParameters = RouteParameters(),
    query: RouteParameters = RouteParameters(),
    hash: String = ""
  ) throws(RouteMatchError) -> String {
    guard let record = records.first(where: { $0.handle == route }) else {
      throw RouteMatchError.missingRequiredParameter(name: "route")
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
    let result = findRecord(for: location)
    guard let record = result.record, let match = result.match else {
      return .notFound(
        RouteNotFoundContext(
          location: location,
          query: QueryString.parse(location.queryString)
        )
      )
    }

    let context = RouteContext(
      params: match.params,
      query: QueryString.parse(location.queryString),
      location: location,
      match: match
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

  private func findRecord(for location: RouteLocation) -> (
    record: CompiledRouteRecord?, match: RouteMatch?
  ) {
    for record in records {
      if let params = record.pattern.match(location.path) {
        return (
          record,
          RouteMatch(route: record.handle, path: record.pattern.path, params: params)
        )
      }
    }
    return (nil, nil)
  }
}
