import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public enum RouteMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    diagnoseIfNeeded(attribute: node, declaration: declaration, context: context)
    return []
  }
}

public enum LayoutMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    diagnoseIfNeeded(attribute: node, declaration: declaration, context: context)
    return []
  }
}

public enum NotFoundMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    diagnoseIfNeeded(attribute: node, declaration: declaration, context: context)
    return []
  }
}

public enum RouteErrorMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    diagnoseIfNeeded(attribute: node, declaration: declaration, context: context)
    return []
  }
}

private func diagnoseIfNeeded(
  attribute: AttributeSyntax,
  declaration: some DeclSyntaxProtocol,
  context: some MacroExpansionContext
) {
  guard let function = declaration.as(FunctionDeclSyntax.self),
    function.isStatic
  else {
    context.diagnose(
      .init(
        node: Syntax(declaration),
        message: RouteMarkerDiagnostic(
          attributeName: attribute.attributeName.trimmedDescription
        )
      )
    )
    return
  }
}

private struct RouteMarkerDiagnostic: DiagnosticMessage {
  let attributeName: String

  var message: String {
    "`@\(attributeName)` can only be attached to a static function."
  }

  var diagnosticID: MessageID {
    MessageID(domain: "ElementaryRouterMacros", id: "routeMarkerRequiresStaticFunction")
  }

  var severity: DiagnosticSeverity {
    .error
  }
}

extension FunctionDeclSyntax {
  fileprivate var isStatic: Bool {
    modifiers.contains { modifier in
      modifier.name.text == "static"
    }
  }
}

extension SyntaxProtocol {
  fileprivate var trimmedDescription: String {
    trimmed.description
  }
}
