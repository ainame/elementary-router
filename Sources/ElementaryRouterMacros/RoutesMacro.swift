import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private enum RoutesMode {
  case path
  case hash
}

public enum RoutesMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let structDeclaration = declaration.as(StructDeclSyntax.self) else {
      context.diagnose(
        .init(node: Syntax(declaration), message: RoutesDiagnostic.routesRequiresStruct)
      )
      return []
    }

    let containerName = structDeclaration.name.text
    let access = declaration.accessModifier
    let mode = parseRoutesMode(from: node, context: context)
    var routes: [RouteDeclaration] = []
    var layouts: [RouteDeclaration] = []
    var notFound: FunctionDeclSyntax?
    var routeError: FunctionDeclSyntax?

    for member in declaration.memberBlock.members {
      guard let function = member.decl.as(FunctionDeclSyntax.self) else {
        continue
      }

      if function.hasAttribute(named: "Route") {
        guard function.isStatic else {
          continue
        }

        guard let path = function.stringLiteralArgument(forAttributeNamed: "Route") else {
          context.diagnose(
            .init(node: Syntax(function), message: RoutesDiagnostic.routeRequiresStringLiteral)
          )
          continue
        }

        let route = RouteDeclaration(function: function, path: path)
        validate(route: route, context: context)
        validateUnique(route, against: routes, context: context)
        routes.append(route)
      }

      if function.hasAttribute(named: "Layout") {
        guard function.isStatic else {
          continue
        }

        guard let path = function.stringLiteralArgument(forAttributeNamed: "Layout") else {
          context.diagnose(
            .init(node: Syntax(function), message: RoutesDiagnostic.routeRequiresStringLiteral)
          )
          continue
        }

        let layout = RouteDeclaration(function: function, path: path)
        validate(route: layout, context: context)
        if !layout.parameters.contains(where: { $0.kind == .outlet }) {
          context.diagnose(
            .init(node: Syntax(function), message: RoutesDiagnostic.layoutRequiresOutlet)
          )
        }

        validateUnique(layout, against: layouts, context: context)
        layouts.append(layout)
      }

      if function.hasAttribute(named: "NotFound") {
        guard function.isStatic else {
          continue
        }
        if notFound != nil {
          context.diagnose(
            .init(node: Syntax(function), message: RoutesDiagnostic.duplicateNotFound)
          )
        } else {
          notFound = function
        }
      }

      if function.hasAttribute(named: "RouteError") {
        guard function.isStatic else {
          continue
        }
        if routeError != nil {
          context.diagnose(
            .init(node: Syntax(function), message: RoutesDiagnostic.duplicateRouteError)
          )
        } else {
          routeError = function
        }
      }
    }

    return [
      DeclSyntax(
        stringLiteral: routeViewDeclaration(
          access: access,
          containerName: containerName,
          routes: routes,
          layouts: layouts,
          notFound: notFound,
          routeError: routeError
        )
      ),
      DeclSyntax(
        stringLiteral: handlesDeclaration(access: access, routes: routes, layouts: layouts)
      ),
      DeclSyntax(
        stringLiteral: routeSetDeclaration(
          access: access,
          mode: mode,
          routes: routes,
          layouts: layouts
        )
      ),
      DeclSyntax(
        stringLiteral: routerEnvironmentKeyDeclaration(
          access: access,
          mode: mode,
          containerName: containerName
        )
      ),
      DeclSyntax(
        stringLiteral: routeSetEnvironmentKeyDeclaration(containerName: containerName)
      ),
      DeclSyntax(
        stringLiteral: providerDeclaration(
          access: access,
          mode: mode,
          containerName: containerName
        )
      ),
      DeclSyntax(
        stringLiteral: routerViewDeclaration(
          access: access,
          mode: mode,
          containerName: containerName
        )
      ),
      DeclSyntax(
        stringLiteral: linkDeclaration(
          access: access,
          containerName: containerName
        )
      ),
      DeclSyntax(
        stringLiteral: routesFunctionDeclaration(
          access: access,
          mode: mode,
          routes: routes,
          layouts: layouts,
          notFound: notFound,
          routeError: routeError
        )
      ),
    ]
  }
}

private struct RouteDeclaration {
  let function: FunctionDeclSyntax
  let path: String

  var name: String {
    function.name.text
  }

  var parameters: [RouteParameter] {
    function.signature.parameterClause.parameters.map { RouteParameter(parameter: $0) }
  }

  var storageParameters: [RouteParameter] {
    parameters.filter { $0.kind != .context && $0.kind != .outlet }
  }

  var pathStorageParameters: [RouteParameter] {
    storageParameters.filter { $0.kind == .path }
  }

  var queryParameters: [RouteParameter] {
    storageParameters.filter { $0.kind == .query }
  }

  var pathParameters: [String] {
    RoutePath(path).parameters
  }

  var hasWildcard: Bool {
    RoutePath(path).hasWildcard
  }

  var depth: Int {
    RoutePath(path).segments.count
  }

  var normalizedPath: String {
    RoutePath(path).normalized
  }
}

private struct RouteParameter {
  enum Kind {
    case path
    case query
    case wildcard
    case context
    case outlet
  }

  let label: String
  let type: String
  let defaultValue: String?

  init(parameter: FunctionParameterSyntax) {
    self.label = parameter.firstName.text
    self.type = parameter.type.trimmedDescription
    self.defaultValue = parameter.defaultValue?.value.trimmedDescription
  }

  var kind: Kind {
    if type == "RouteContext" {
      return .context
    }
    if type == "Outlet" || type.hasPrefix("Outlet<") || label == "outlet" {
      return .outlet
    }
    if type == "Wildcard" {
      return .wildcard
    }
    if queryValueType != nil {
      return .query
    }
    return .path
  }

  var queryValueType: String? {
    guard type.hasPrefix("Query<"), type.hasSuffix(">") else {
      return nil
    }
    return String(type.dropFirst("Query<".count).dropLast())
  }

  var storageType: String {
    if kind == .wildcard {
      return "String"
    }
    if let queryValueType {
      return queryValueType
    }
    return type
  }

  var callArgument: String {
    switch kind {
    case .context:
      return "\(label): context"
    case .outlet:
      return "\(label): outlet"
    case .wildcard:
      return "\(label): Wildcard(\(label))"
    case .query:
      return "\(label): Query(\(label))"
    case .path:
      return "\(label): \(label)"
    }
  }

  var queryDefaultValue: String? {
    guard kind == .query, let defaultValue else {
      return nil
    }

    if defaultValue.hasPrefix("Query("), defaultValue.hasSuffix(")") {
      return String(defaultValue.dropFirst("Query(".count).dropLast())
    }
    return defaultValue
  }
}

private struct RoutePath {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  var parameters: [String] {
    var result: [String] = []
    for segment in value.split(separator: "/") {
      if segment.first == ":" {
        result.append(String(segment.dropFirst()))
      }
    }
    return result
  }

  var hasWildcard: Bool {
    value.split(separator: "/").contains("*")
  }

  var segments: [String] {
    value.split(separator: "/").map(String.init)
  }

  var normalized: String {
    var result = value
    if result.isEmpty || result.first != "/" {
      result = "/" + result
    }
    while result.count > 1 && result.last == "/" {
      result.removeLast()
    }
    return result
  }

  /// The segments with parameter names erased, matching the runtime `RoutePattern.shape`.
  ///
  /// Two paths with the same shape match exactly the same URLs.
  var shape: [RouteSegmentShape] {
    segments.map { segment -> RouteSegmentShape in
      if segment == "*" {
        return .wildcard
      }
      if segment.first == ":" {
        return .parameter
      }
      return .literal(percentDecoded(segment))
    }
  }

  /// Returns `true` when `prefix` names the leading segments of this path.
  ///
  /// Parameters must use the same names so a layout and its children read the same values.
  /// Static segments compare percent-decoded, as the runtime matcher does.
  func hasSegmentPrefix(_ prefix: RoutePath) -> Bool {
    let own = segments
    let other = prefix.segments
    guard other.count <= own.count else {
      return false
    }
    for (lhs, rhs) in zip(own, other) where !segmentsMatch(lhs, rhs) {
      return false
    }
    return true
  }
}

private enum RouteSegmentShape: Equatable {
  case literal(String)
  case parameter
  case wildcard
}

private func segmentsMatch(_ lhs: String, _ rhs: String) -> Bool {
  if lhs == "*" || rhs == "*" || lhs.first == ":" || rhs.first == ":" {
    return lhs == rhs
  }
  return percentDecoded(lhs) == percentDecoded(rhs)
}

private func percentDecoded(_ value: String) -> String {
  let input = Array(value.utf8)
  var bytes: [UInt8] = []
  var index = 0

  while index < input.count {
    if input[index] == UInt8(ascii: "%"), index + 2 < input.count,
      let high = hexValue(input[index + 1]),
      let low = hexValue(input[index + 2])
    {
      bytes.append(high * 16 + low)
      index += 3
    } else {
      bytes.append(input[index])
      index += 1
    }
  }

  return String(decoding: bytes, as: UTF8.self)
}

private func hexValue(_ byte: UInt8) -> UInt8? {
  switch byte {
  case UInt8(ascii: "0")...UInt8(ascii: "9"): return byte - UInt8(ascii: "0")
  case UInt8(ascii: "A")...UInt8(ascii: "F"): return byte - UInt8(ascii: "A") + 10
  case UInt8(ascii: "a")...UInt8(ascii: "f"): return byte - UInt8(ascii: "a") + 10
  default: return nil
  }
}

private func validate(route: RouteDeclaration, context: some MacroExpansionContext) {
  let pathParameters = route.pathParameters
  let pathParameterNames = route.pathStorageParameters.map(\.label)

  for name in pathParameters where !pathParameterNames.contains(name) {
    context.diagnose(
      .init(
        node: Syntax(route.function),
        message: RoutesDiagnostic.missingPathParameter(name: name)
      )
    )
  }

  for parameter in route.pathStorageParameters where !pathParameters.contains(parameter.label) {
    context.diagnose(
      .init(
        node: Syntax(route.function),
        message: RoutesDiagnostic.extraPathParameter(name: parameter.label)
      )
    )
  }

  let wildcardParameters = route.storageParameters.filter { $0.kind == .wildcard }
  if route.hasWildcard && wildcardParameters.count != 1 {
    context.diagnose(
      .init(node: Syntax(route.function), message: RoutesDiagnostic.wildcardRequiresParameter)
    )
  }
  if !route.hasWildcard && !wildcardParameters.isEmpty {
    context.diagnose(
      .init(node: Syntax(route.function), message: RoutesDiagnostic.unexpectedWildcardParameter)
    )
  }

  let segments = RoutePath(route.path).segments
  if let wildcardIndex = segments.firstIndex(of: "*"), wildcardIndex != segments.count - 1 {
    context.diagnose(
      .init(node: Syntax(route.function), message: RoutesDiagnostic.wildcardMustBeLast)
    )
  }
}

/// Rejects a declaration that matches exactly the same URLs as an earlier one of the same kind.
private func validateUnique(
  _ route: RouteDeclaration,
  against existing: [RouteDeclaration],
  context: some MacroExpansionContext
) {
  let shape = RoutePath(route.path).shape
  guard let conflict = existing.first(where: { RoutePath($0.path).shape == shape }) else {
    return
  }

  let message =
    conflict.normalizedPath == route.normalizedPath
    ? RoutesDiagnostic.duplicateRoute(path: route.normalizedPath)
    : RoutesDiagnostic.ambiguousRoute(
      path: route.normalizedPath,
      conflictingPath: conflict.normalizedPath
    )
  context.diagnose(.init(node: Syntax(route.function), message: message))
}

/// Returns every layout that wraps `route`, from outermost to innermost.
///
/// A layout wraps a route when the layout path names the route's leading segments, including a
/// layout declared at exactly the route's path.
private func matchingLayouts(for route: RouteDeclaration, layouts: [RouteDeclaration])
  -> [RouteDeclaration]
{
  let path = RoutePath(route.path)
  return
    layouts
    .filter { path.hasSegmentPrefix(RoutePath($0.path)) }
    .sorted { $0.depth < $1.depth }
}

/// Returns the innermost layout that wraps `layout`, which becomes its parent in the route tree.
private func enclosingLayout(for layout: RouteDeclaration, layouts: [RouteDeclaration])
  -> RouteDeclaration?
{
  let path = RoutePath(layout.path)
  return
    layouts
    .filter { $0.depth < layout.depth && path.hasSegmentPrefix(RoutePath($0.path)) }
    .max { $0.depth < $1.depth }
}

private func relativePath(for route: RouteDeclaration, under layout: RouteDeclaration?) -> String {
  guard let layout else {
    return route.path
  }

  let remaining = RoutePath(route.path).segments.dropFirst(layout.depth)
  return remaining.isEmpty ? "/" : remaining.joined(separator: "/")
}

private func routeViewDeclaration(
  access: String,
  containerName: String,
  routes: [RouteDeclaration],
  layouts: [RouteDeclaration],
  notFound: FunctionDeclSyntax?,
  routeError: FunctionDeclSyntax?
) -> String {
  let layoutCases = layouts.map { layout in
    let values = layout.storageParameters.map { "\($0.label): \($0.storageType)" }
      .joined(separator: ", ")
    return values.isEmpty ? "case \(layout.name)" : "case \(layout.name)(\(values))"
  }

  let cases = routes.map { route in
    let values = route.storageParameters.map { "\($0.label): \($0.storageType)" }
      .joined(separator: ", ")
    return values.isEmpty ? "case \(route.name)" : "case \(route.name)(\(values))"
  }

  let notFoundCase = notFound == nil ? [] : ["case notFound(RouteNotFoundContext)"]
  let errorCase = routeError == nil ? [] : ["case routeError(RouteErrorContext)"]

  let layoutSwitchCases = layouts.map { layout in
    let expression = layoutCallExpression(
      containerName: containerName,
      layout: layout,
      outletExpression: "EmptyHTML()"
    )
    let parameters = layout.storageParameters
    if parameters.isEmpty {
      return """
              case .\(layout.name):
                \(expression)
        """
    }

    let bindings = parameters.map { "let \($0.label)" }.joined(separator: ", ")
    return """
            case .\(layout.name)(\(bindings)):
              \(expression)
      """
  }

  let switchCases = routes.map { route in
    let parameters = route.storageParameters
    let contentExpression = wrappedRouteExpression(
      containerName: containerName,
      route: route,
      layouts: layouts
    )
    if parameters.isEmpty {
      return """
              case .\(route.name):
                \(contentExpression)
        """
    }

    let bindings = parameters.map { "let \($0.label)" }.joined(separator: ", ")
    return """
            case .\(route.name)(\(bindings)):
              \(contentExpression)
      """
  }

  let notFoundSwitch = notFound.map { function in
    """
          case .notFound(let context):
            \(containerName).\(function.name.text)(context: context)
    """
  }

  let errorSwitch = routeError.map { function in
    """
          case .routeError(let context):
            \(containerName).\(function.name.text)(context: context)
    """
  }

  return """
      @View
      \(access)struct RouteView {
        \(access)enum Storage {
          \((layoutCases + cases + notFoundCase + errorCase).joined(separator: "\n    "))
        }

        let storage: Storage

        \(access)init(storage: Storage) {
          self.storage = storage
        }

        \(access)var body: some View {
          switch storage {
          \((layoutSwitchCases + switchCases + [notFoundSwitch, errorSwitch].compactMap { $0 }).joined(separator: "\n"))
          }
        }
      }
    """
}

private func wrappedRouteExpression(
  containerName: String,
  route: RouteDeclaration,
  layouts: [RouteDeclaration]
) -> String {
  let arguments = route.storageParameters.map(\.callArgument).joined(separator: ", ")
  var expression =
    route.storageParameters.isEmpty
    ? "\(containerName).\(route.name)()"
    : "\(containerName).\(route.name)(\(arguments))"

  for layout in matchingLayouts(for: route, layouts: layouts).reversed() {
    expression = layoutCallExpression(
      containerName: containerName,
      layout: layout,
      outletExpression: expression
    )
  }

  return expression
}

private func layoutCallExpression(
  containerName: String,
  layout: RouteDeclaration,
  outletExpression: String
) -> String {
  let arguments = layout.parameters.map { parameter in
    if parameter.kind == .outlet {
      return "\(parameter.label): Outlet(\(outletExpression))"
    }
    return parameter.callArgument
  }.joined(separator: ", ")
  return "\(containerName).\(layout.name)(\(arguments))"
}

private func handlesDeclaration(
  access: String,
  routes: [RouteDeclaration],
  layouts: [RouteDeclaration]
) -> String {
  let allRoutes = layouts + routes
  let properties = allRoutes.map { "\(access)let \($0.name): RouteHandle" }.joined(
    separator: "\n    "
  )
  let arguments = allRoutes.map { "\($0.name): RouteHandle" }.joined(separator: ", ")
  let assignments = allRoutes.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n      ")

  return """
      \(access)struct Handles {
        \(properties)

        \(access)init(\(arguments)) {
          \(assignments)
        }
      }
    """
}

private func routeSetDeclaration(
  access: String,
  mode: RoutesMode,
  routes: [RouteDeclaration],
  layouts: [RouteDeclaration]
) -> String {
  let hrefs = (layouts + routes).map {
    hrefFunctionDeclaration(access: access, mode: mode, route: $0)
  }
  .joined(separator: "\n\n")
  let routerType = routerType(mode: mode, routeViewType: "RouteView")
  let routerInitializer = routerInitializer(mode: mode, treeName: "tree")

  return """
      \(access)struct RouteSet {
        let tree: RouteTree<RouteView>
        \(access)let handles: Handles

        init(tree: RouteTree<RouteView>, handles: Handles) {
          self.tree = tree
          self.handles = handles
        }

        \(access)func router() -> \(routerType) {
          \(routerInitializer)
        }

      \(hrefs)
      }
    """
}

private func providerDeclaration(
  access: String,
  mode: RoutesMode,
  containerName: String
) -> String {
  let router = routerType(mode: mode, routeViewType: "RouteView")

  return """
      @View
      \(access)struct Provider<Content: View> {
        let routes: RouteSet
        let router: \(router)
        let content: Content

        \(access)init(_ router: \(router), @HTMLBuilder content: () -> Content) {
          do throws(RouteTreeError) {
            let routes = try \(containerName).routes()
            self.routes = routes
            self.router = router
            self.content = content()
          } catch {
            preconditionFailure("\(containerName).Provider could not build routes.")
          }
        }

        init(_ router: \(router), routes: RouteSet, @HTMLBuilder content: () -> Content) {
          self.routes = routes
          self.router = router
          self.content = content()
        }

        \(access)var body: some View {
          content.environment(\(containerName)._routerEnvironmentKey, router)
            .environment(\(containerName)._routeSetEnvironmentKey, routes)
        }
      }
    """
}

private func routerViewDeclaration(
  access: String,
  mode: RoutesMode,
  containerName: String
) -> String {
  let router = routerType(mode: mode, routeViewType: "RouteView")
  return """
      @View
      \(access)struct RouterView {
        let routes: RouteSet
        let router: \(router)

        \(access)init() {
          do throws(RouteTreeError) {
            let routes = try \(containerName).routes()
            self.routes = routes
            self.router = routes.router()
          } catch {
            preconditionFailure("\(containerName).RouterView could not build routes.")
          }
        }

        \(access)var body: some View {
          Provider(router, routes: routes) {
            rendered
          }
        }

        private var rendered: RouteView {
          do {
            return try router.renderCurrentRoute()
          } catch {
            preconditionFailure("\(containerName).RouterView could not render the current route.")
          }
        }
      }
    """
}

private func linkDeclaration(
  access: String,
  containerName: String
) -> String {
  return """
      @View
      \(access)struct Link<Content: View> {
        @Environment(\(containerName)._routerEnvironmentKey) var router

        let route: RouteHandle
        let params: RouteValues
        let query: RouteValues
        let hash: String
        let replace: Bool
        let target: HTMLAttributeValue.Target?
        let content: Content

        \(access)init(
          to route: RouteHandle,
          params: RouteValues = RouteValues(),
          query: RouteValues = RouteValues(),
          hash: String = "",
          replace: Bool = false,
          target: HTMLAttributeValue.Target? = nil,
          @HTMLBuilder content: () -> Content
        ) {
          self.route = route
          self.params = params
          self.query = query
          self.hash = hash
          self.replace = replace
          self.target = target
          self.content = content()
        }

        \(access)var body: some View {
          if let target {
            a(.href(href), .target(target), .data("router-link", value: "true")) {
              content
            }
            .onClick { event in
              handleClick(event)
            }
          } else {
            a(.href(href), .data("router-link", value: "true")) {
              content
            }
            .onClick { event in
              handleClick(event)
            }
          }
        }

        private func handleClick(_ event: MouseEvent) {
          guard
            event.button == 0,
            !event.altKey,
            !event.ctrlKey,
            !event.metaKey,
            !event.shiftKey,
            target == nil || target?.rawValue == "" || target?.rawValue == "_self"
          else {
            return
          }

          try? router?.navigate(
            to: route,
            params: params,
            query: query,
            hash: hash,
            replace: replace
          )
        }

        private var href: String {
          (try? router?.href(to: route, params: params, query: query, hash: hash)) ?? "#"
        }
      }
    """
}

private func routerEnvironmentKeyDeclaration(
  access: String,
  mode: RoutesMode,
  containerName: String
) -> String {
  let router = routerType(mode: mode, routeViewType: "RouteView")

  return """
      static let _routerEnvironmentKey = EnvironmentValues._Key<\(router)?>(
        "ElementaryRouter.\(containerName).router",
        defaultValue: nil
      )
    """
}

private func routeSetEnvironmentKeyDeclaration(containerName: String) -> String {
  return """
      static let _routeSetEnvironmentKey = EnvironmentValues._Key<RouteSet?>(
        "ElementaryRouter.\(containerName).routes",
        defaultValue: nil
      )
    """
}

private func routesFunctionDeclaration(
  access: String,
  mode: RoutesMode,
  routes: [RouteDeclaration],
  layouts: [RouteDeclaration],
  notFound: FunctionDeclSyntax?,
  routeError: FunctionDeclSyntax?
) -> String {
  // Register outer layouts first so each nested layout can reference its parent handle.
  let layoutRegistrations = layouts.enumerated()
    .sorted { ($0.element.depth, $0.offset) < ($1.element.depth, $1.offset) }
    .map { entry in
      routeRegistration(
        entry.element,
        method: "_layout",
        parent: enclosingLayout(for: entry.element, layouts: layouts)
      )
    }
  let registrations = routes.map { route in
    routeRegistration(
      route,
      method: "_route",
      parent: matchingLayouts(for: route, layouts: layouts).last
    )
  }

  let notFoundRegistration = notFound.map { function in
    """
        collection._notFound { context in
          RouteView(storage: .notFound(context))
        }
    """
  }

  let errorRegistration = routeError.map { function in
    """
        collection._error { context in
          RouteView(storage: .routeError(context))
        }
    """
  }

  let handles = (layouts + routes).map { "\($0.name): \($0.name)" }.joined(separator: ", ")
  return """
      \(access)static func routes() throws(RouteTreeError) -> RouteSet {
        let collection = RouteBuilder<RouteView>()
        \(layoutRegistrations.joined(separator: "\n"))
        \(registrations.joined(separator: "\n"))
        \([notFoundRegistration, errorRegistration].compactMap { $0 }.joined(separator: "\n"))
        return RouteSet(
          tree: try collection._build(),
          handles: Handles(\(handles))
        )
      }

      \(access)static func router() throws(RouteTreeError) -> \(routerType(mode: mode, routeViewType: "RouteView")) {
        try routes().router()
      }
    """
}

private func routerType(mode: RoutesMode, routeViewType: String) -> String {
  switch mode {
  case .path:
    return "Router<\(routeViewType)>"
  case .hash:
    return "HashRouter<\(routeViewType)>"
  }
}

private func routerInitializer(mode: RoutesMode, treeName: String) -> String {
  switch mode {
  case .path:
    return "Router(routes: \(treeName))"
  case .hash:
    return "HashRouter(routes: \(treeName))"
  }
}

private func parseRoutesMode(
  from node: AttributeSyntax,
  context: some MacroExpansionContext
) -> RoutesMode {
  guard case .argumentList(let arguments) = node.arguments else {
    return .path
  }

  guard
    let modeArgument = arguments.first(where: { argument in
      argument.label?.text == "mode"
    })
  else {
    return .path
  }

  let expression = modeArgument.expression.trimmedDescription
  switch expression {
  case ".path", "RoutesMode.path":
    return .path
  case ".hash", "RoutesMode.hash":
    return .hash
  default:
    context.diagnose(
      .init(node: Syntax(modeArgument.expression), message: RoutesDiagnostic.unsupportedRoutesMode)
    )
    return .path
  }
}

private func routeRegistration(
  _ route: RouteDeclaration,
  method: String,
  parent: RouteDeclaration?
) -> String {
  let storageArguments = route.storageParameters.map { parameter in
    switch parameter.kind {
    case .context:
      return "\(parameter.label): context"
    case .outlet:
      return "\(parameter.label): Outlet(EmptyHTML())"
    case .wildcard:
      return "\(parameter.label): try context.params.require(\"*\", String.self)"
    case .query:
      let valueType = parameter.queryValueType ?? parameter.storageType
      let parsed = "context.query.get(\"\(parameter.label)\", \(valueType).self)"
      if let defaultValue = parameter.queryDefaultValue {
        return "\(parameter.label): \(parsed) ?? \(defaultValue)"
      }
      return
        "\(parameter.label): try context.query.require(\"\(parameter.label)\", \(valueType).self)"
    case .path:
      return
        "\(parameter.label): try context.params.require(\"\(parameter.label)\", \(parameter.type).self)"
    }
  }.joined(separator: ", ")

  if route.storageParameters.isEmpty {
    return """
          let \(route.name) = collection.\(method)("\(relativePath(for: route, under: parent))", parent: \(registrationParent(parent: parent))) {
            RouteView(storage: .\(route.name))
          }
      """
  }

  return """
        let \(route.name) = collection.\(method)("\(relativePath(for: route, under: parent))", parent: \(registrationParent(parent: parent))) { context throws(RouteValueError) in
          RouteView(storage: .\(route.name)(\(storageArguments)))
        }
    """
}

private func registrationParent(parent: RouteDeclaration?) -> String {
  guard let parent else {
    return "nil"
  }
  return parent.name
}

private func hrefFunctionDeclaration(
  access: String,
  mode: RoutesMode,
  route: RouteDeclaration
) -> String {
  let pathParameters = route.storageParameters.filter {
    $0.kind == .path || $0.kind == .wildcard
  }
  let queryParameters = route.queryParameters

  let parameters = (pathParameters + queryParameters).map { parameter in
    if parameter.kind == .query, parameter.queryDefaultValue != nil {
      return "\(parameter.label): \(parameter.storageType)? = nil"
    }
    return "\(parameter.label): \(parameter.storageType)"
  }

  let signatureParameters = (parameters + ["hash: String = \"\""]).joined(separator: ", ")

  let pathPairs = pathParameters.map { parameter in
    let key = parameter.kind == .wildcard ? "*" : parameter.label
    return "\"\(key)\": RouteValues.ValueLiteral(\(parameter.label))"
  }.joined(separator: ", ")

  let paramsBuilder: String
  if pathPairs.isEmpty {
    paramsBuilder = "let params = RouteValues()"
  } else {
    paramsBuilder = "let params: RouteValues = [\(pathPairs)]"
  }

  let queryBuilder: String
  if queryParameters.isEmpty {
    queryBuilder = "let query = RouteValues()"
  } else {
    let lines = queryParameters.map { parameter in
      if parameter.queryDefaultValue != nil {
        return """
              if let \(parameter.label) {
                query = query.set("\(parameter.label)", \(parameter.label))
              }
          """
      }
      return """
            query = query.set("\(parameter.label)", \(parameter.label))
        """
    }.joined(separator: "\n")

    queryBuilder = """
        var query = RouteValues()
        \(lines)
      """
  }

  // Hash-mode helpers return the same fragment hrefs as `HashRouter.href(to:)`.
  let hrefMethod: String
  switch mode {
  case .path:
    hrefMethod = "_href"
  case .hash:
    hrefMethod = "_hashHref"
  }

  return """
      \(access)func \(route.name)Href(\(signatureParameters)) throws(RouteMatchError) -> String {
        \(paramsBuilder)
        \(queryBuilder)
        return try tree.\(hrefMethod)(to: handles.\(route.name), params: params, query: query, hash: hash)
      }
    """
}

extension DeclGroupSyntax {
  fileprivate var accessModifier: String {
    for modifier in modifiers {
      let text = modifier.name.text
      if text == "public" || text == "package" {
        return text + " "
      }
    }
    return ""
  }
}

extension FunctionDeclSyntax {
  fileprivate var isStatic: Bool {
    modifiers.contains { modifier in
      modifier.name.text == "static"
    }
  }

  fileprivate func hasAttribute(named expectedName: String) -> Bool {
    attributes.contains { element in
      guard case .attribute(let attribute) = element else {
        return false
      }
      return attribute.attributeName.trimmedDescription == expectedName
    }
  }

  fileprivate func stringLiteralArgument(forAttributeNamed expectedName: String) -> String? {
    for element in attributes {
      guard case .attribute(let attribute) = element,
        attribute.attributeName.trimmedDescription == expectedName,
        case .argumentList(let arguments) = attribute.arguments,
        let expression = arguments.first?.expression.as(StringLiteralExprSyntax.self)
      else {
        continue
      }

      for segment in expression.segments {
        guard case .stringSegment(let literal) = segment else {
          continue
        }
        return literal.content.text
      }
    }

    return nil
  }
}

extension SyntaxProtocol {
  fileprivate var trimmedDescription: String {
    trimmed.description
  }
}

private enum RoutesDiagnostic: DiagnosticMessage {
  case routesRequiresStruct
  case routeRequiresStringLiteral
  case missingPathParameter(name: String)
  case extraPathParameter(name: String)
  case wildcardRequiresParameter
  case unexpectedWildcardParameter
  case layoutRequiresOutlet
  case duplicateRoute(path: String)
  case ambiguousRoute(path: String, conflictingPath: String)
  case wildcardMustBeLast
  case duplicateNotFound
  case duplicateRouteError
  case unsupportedRoutesMode

  var message: String {
    switch self {
    case .routesRequiresStruct:
      "`@Routes` can only be attached to a struct."
    case .routeRequiresStringLiteral:
      "`@Route` requires a string literal path."
    case .missingPathParameter(let name):
      "Missing function parameter for path parameter `\(name)`."
    case .extraPathParameter(let name):
      "Function parameter `\(name)` does not appear in the route path."
    case .wildcardRequiresParameter:
      "Wildcard routes must declare exactly one `Wildcard` parameter."
    case .unexpectedWildcardParameter:
      "`Wildcard` parameters are only valid on routes whose path contains `*`."
    case .layoutRequiresOutlet:
      "`@Layout` functions must declare an outlet parameter."
    case .duplicateRoute(let path):
      "Duplicate route path `\(path)`."
    case .ambiguousRoute(let path, let conflictingPath):
      "Route path `\(path)` matches the same URLs as `\(conflictingPath)`."
    case .wildcardMustBeLast:
      "Wildcard `*` must be the last path segment."
    case .duplicateNotFound:
      "`@Routes` can only declare one `@NotFound` function."
    case .duplicateRouteError:
      "`@Routes` can only declare one `@RouteError` function."
    case .unsupportedRoutesMode:
      "`@Routes(mode:)` only supports `.path` and `.hash`."
    }
  }

  var diagnosticID: MessageID {
    MessageID(domain: "ElementaryRouterMacros", id: "\(self)")
  }

  var severity: DiagnosticSeverity {
    .error
  }
}
