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
      return []
    }

    let containerName = structDeclaration.name.text
    let access = declaration.accessModifier
    let routes = declaration.memberBlock.members.compactMap { member -> RouteDeclaration? in
      guard let function = member.decl.as(FunctionDeclSyntax.self),
        let path = function.stringLiteralArgument(forAttributeNamed: "Route")
      else {
        return nil
      }

      return RouteDeclaration(function: function, path: path)
    }

    let notFound = declaration.memberBlock.members.compactMap { member -> FunctionDeclSyntax? in
      guard let function = member.decl.as(FunctionDeclSyntax.self),
        function.hasAttribute(named: "NotFound")
      else {
        return nil
      }
      return function
    }.first

    let routeError = declaration.memberBlock.members.compactMap { member -> FunctionDeclSyntax? in
      guard let function = member.decl.as(FunctionDeclSyntax.self),
        function.hasAttribute(named: "RouteError")
      else {
        return nil
      }
      return function
    }.first

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
      DeclSyntax(stringLiteral: routeSetDeclaration(access: access)),
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

  var pathParameters: [String] {
    RoutePath(path).parameters
  }

  var hasWildcard: Bool {
    RoutePath(path).hasWildcard
  }
}

private struct RouteParameter {
  let label: String
  let type: String

  init(parameter: FunctionParameterSyntax) {
    self.label = parameter.firstName.text
    self.type = parameter.type.trimmedDescription
  }

  var storageType: String {
    if type == "Wildcard" {
      return "String"
    }
    return type
  }

  var callArgument: String {
    if type == "Wildcard" {
      return "\(label): Wildcard(\(label))"
    }
    return "\(label): \(label)"
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
}

private func routeViewDeclaration(
  access: String,
  containerName: String,
  routes: [RouteDeclaration],
  notFound: FunctionDeclSyntax?,
  routeError: FunctionDeclSyntax?
) -> String {
  let cases = routes.map { route in
    let values = route.parameters.map { "\($0.label): \($0.storageType)" }.joined(separator: ", ")
    return values.isEmpty ? "case \(route.name)" : "case \(route.name)(\(values))"
  }

  let notFoundCase = notFound == nil ? [] : ["case notFound(RouteNotFoundContext)"]
  let errorCase = routeError == nil ? [] : ["case routeError(RouteErrorContext)"]

  let switchCases = routes.map { route in
    let parameters = route.parameters
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

private func routeSetDeclaration(access: String) -> String {
  """
    \(access)struct RouteSet {
      \(access)let tree: RouteTree<RouteView>
      \(access)let handles: Handles

      \(access)init(tree: RouteTree<RouteView>, handles: Handles) {
        self.tree = tree
        self.handles = handles
      }
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
  let storageArguments = route.parameters.map { parameter in
    if parameter.type == "Wildcard" {
      return "\(parameter.label): try context.params.require(\"*\", String.self)"
    }
    return
      "\(parameter.label): try context.params.require(\"\(parameter.label)\", \(parameter.type).self)"
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
