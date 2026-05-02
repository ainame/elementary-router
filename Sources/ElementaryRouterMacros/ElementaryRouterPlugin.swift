import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ElementaryRouterPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    RoutesMacro.self,
    RouteMacro.self,
    NotFoundMacro.self,
    RouteErrorMacro.self,
  ]
}
