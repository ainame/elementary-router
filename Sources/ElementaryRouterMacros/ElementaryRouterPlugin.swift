import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ElementaryRouterPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    RoutesMacro.self,
    RouteMacro.self,
    LayoutMacro.self,
    NotFoundMacro.self,
    RouteErrorMacro.self,
  ]
}
