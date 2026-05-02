import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

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
    var routes: [RouteDeclaration] = []
    var notFound: FunctionDeclSyntax?
    var routeError: FunctionDeclSyntax?
    var seenPaths: [String] = []

    for member in declaration.memberBlock.members {
      guard let function = member.decl.as(FunctionDeclSyntax.self) else {
        let text = member.decl.trimmedDescription
        if text.contains("@Route")
          || text.contains("@NotFound")
          || text.contains("@RouteError")
        {
          context.diagnose(
            .init(node: Syntax(member.decl), message: RoutesDiagnostic.routeRequiresStaticFunction)
          )
        }
        continue
      }

      if function.hasAttribute(named: "Route") {
        guard function.isStatic else {
          context.diagnose(
            .init(node: Syntax(function), message: RoutesDiagnostic.routeRequiresStaticFunction)
          )
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

        if seenPaths.contains(route.normalizedPath) {
          context.diagnose(
            .init(
              node: Syntax(function),
              message: RoutesDiagnostic.duplicateRoute(path: route.normalizedPath)
            )
          )
        }
        seenPaths.append(route.normalizedPath)
        routes.append(route)
      }

      if function.hasAttribute(named: "NotFound") {
        guard function.isStatic else {
          context.diagnose(
            .init(node: Syntax(function), message: RoutesDiagnostic.routeRequiresStaticFunction)
          )
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
          context.diagnose(
            .init(node: Syntax(function), message: RoutesDiagnostic.routeRequiresStaticFunction)
          )
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
          notFound: notFound,
          routeError: routeError
        )
      ),
      DeclSyntax(stringLiteral: handlesDeclaration(access: access, routes: routes)),
      DeclSyntax(stringLiteral: routeSetDeclaration(access: access, routes: routes)),
      DeclSyntax(
        stringLiteral: routesFunctionDeclaration(
          access: access,
          routes: routes,
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
    parameters.filter { $0.kind != .context }
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
}

private func routeViewDeclaration(
  access: String,
  containerName: String,
  routes: [RouteDeclaration],
  notFound: FunctionDeclSyntax?,
  routeError: FunctionDeclSyntax?
) -> String {
  let cases = routes.map { route in
    let values = route.storageParameters.map { "\($0.label): \($0.storageType)" }
      .joined(separator: ", ")
    return values.isEmpty ? "case \(route.name)" : "case \(route.name)(\(values))"
  }

  let notFoundCase = notFound == nil ? [] : ["case notFound(RouteNotFoundContext)"]
  let errorCase = routeError == nil ? [] : ["case routeError(RouteErrorContext)"]

  let switchCases = routes.map { route in
    let parameters = route.storageParameters
    if parameters.isEmpty {
      return """
              case .\(route.name):
                \(containerName).\(route.name)()
        """
    }

    let bindings = parameters.map { "let \($0.label)" }.joined(separator: ", ")
    let arguments = parameters.map(\.callArgument).joined(separator: ", ")
    return """
            case .\(route.name)(\(bindings)):
              \(containerName).\(route.name)(\(arguments))
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
          \((cases + notFoundCase + errorCase).joined(separator: "\n    "))
        }

        let storage: Storage

        \(access)init(storage: Storage) {
          self.storage = storage
        }

        \(access)var body: some View {
          switch storage {
          \((switchCases + [notFoundSwitch, errorSwitch].compactMap { $0 }).joined(separator: "\n"))
          }
        }
      }
    """
}

private func handlesDeclaration(access: String, routes: [RouteDeclaration]) -> String {
  let properties = routes.map { "\(access)let \($0.name): RouteHandle" }.joined(separator: "\n    ")
  let arguments = routes.map { "\($0.name): RouteHandle" }.joined(separator: ", ")
  let assignments = routes.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n      ")

  return """
      \(access)struct Handles {
        \(properties)

        \(access)init(\(arguments)) {
          \(assignments)
        }
      }
    """
}

private func routeSetDeclaration(access: String, routes: [RouteDeclaration]) -> String {
  let hrefs = routes.map { hrefFunctionDeclaration(access: access, route: $0) }.joined(
    separator: "\n\n"
  )

  return """
      \(access)struct RouteSet {
        \(access)let tree: RouteTree<RouteView>
        \(access)let handles: Handles

        \(access)init(tree: RouteTree<RouteView>, handles: Handles) {
          self.tree = tree
          self.handles = handles
        }

      \(hrefs)
      }
    """
}

private func routesFunctionDeclaration(
  access: String,
  routes: [RouteDeclaration],
  notFound: FunctionDeclSyntax?,
  routeError: FunctionDeclSyntax?
) -> String {
  let registrations = routes.map { route in
    routeRegistration(route)
  }

  let notFoundRegistration = notFound.map { function in
    """
        collection.notFound { context in
          RouteView(storage: .notFound(context))
        }
    """
  }

  let errorRegistration = routeError.map { function in
    """
        collection.error { context in
          RouteView(storage: .routeError(context))
        }
    """
  }

  let handles = routes.map { "\($0.name): \($0.name)" }.joined(separator: ", ")

  return """
      \(access)static func routes() throws(RouteTreeError) -> RouteSet {
        let collection = RouteCollection<RouteView>()
        \(registrations.joined(separator: "\n"))
        \([notFoundRegistration, errorRegistration].compactMap { $0 }.joined(separator: "\n"))
        return RouteSet(
          tree: try collection.freeze(),
          handles: Handles(\(handles))
        )
      }
    """
}

private func routeRegistration(_ route: RouteDeclaration) -> String {
  let storageArguments = route.storageParameters.map { parameter in
    switch parameter.kind {
    case .context:
      return "\(parameter.label): context"
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

  if route.parameters.isEmpty {
    return """
          let \(route.name) = collection.route("\(route.path)") {
            RouteView(storage: .\(route.name))
          }
      """
  }

  return """
        let \(route.name) = collection.route("\(route.path)") { context throws(RouteValueError) in
          RouteView(storage: .\(route.name)(\(storageArguments)))
        }
    """
}

private func hrefFunctionDeclaration(access: String, route: RouteDeclaration) -> String {
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
    return "(\"\(key)\", RouteValueLiteral(\(parameter.label)))"
  }.joined(separator: ", ")

  let queryBuilder: String
  if queryParameters.isEmpty {
    queryBuilder = "let query = RouteParameters()"
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
        var query = RouteParameters()
        \(lines)
      """
  }

  return """
      \(access)func \(route.name)Href(\(signatureParameters)) throws(RouteMatchError) -> String {
        let params = RouteParameters(\(pathPairs))
        \(queryBuilder)
        return try tree.href(to: handles.\(route.name), params: params, query: query, hash: hash)
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
  case routeRequiresStaticFunction
  case routeRequiresStringLiteral
  case missingPathParameter(name: String)
  case extraPathParameter(name: String)
  case wildcardRequiresParameter
  case unexpectedWildcardParameter
  case duplicateRoute(path: String)
  case duplicateNotFound
  case duplicateRouteError

  var message: String {
    switch self {
    case .routesRequiresStruct:
      "`@Routes` can only be attached to a struct."
    case .routeRequiresStaticFunction:
      "Route declarations must be static functions."
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
    case .duplicateRoute(let path):
      "Duplicate route path `\(path)`."
    case .duplicateNotFound:
      "`@Routes` can only declare one `@NotFound` function."
    case .duplicateRouteError:
      "`@Routes` can only declare one `@RouteError` function."
    }
  }

  var diagnosticID: MessageID {
    MessageID(domain: "ElementaryRouterMacros", id: "\(self)")
  }

  var severity: DiagnosticSeverity {
    .error
  }
}
