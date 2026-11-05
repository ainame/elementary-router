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
    // A generic route struct is a feature: its routes are mounted into a host route tree whose
    // route view is the generic parameter.
    let isFeature = structDeclaration.genericParameterClause != nil
    let featureRoot = structDeclaration.genericParameterClause.flatMap { clause in
      clause.parameters.count == 1 ? clause.parameters.first?.name.text : nil
    }
    if isFeature, featureRoot == nil {
      context.diagnose(
        .init(node: Syntax(structDeclaration.name), message: RoutesDiagnostic.featureGenericParameters)
      )
      return []
    }
    if isFeature, let modeArgument = node.modeArgument {
      context.diagnose(.init(node: Syntax(modeArgument), message: RoutesDiagnostic.featureMode))
    }
    let mode = isFeature ? .path : parseRoutesMode(from: node, context: context)
    // Declarations with an error get no generated code, so an invalid signature is reported once,
    // by its diagnostic, instead of again as malformed or mistyped generated Swift.
    let diagnosed = DiagnosedDeclarations(context)
    var routes: [RouteDeclaration] = []
    var layouts: [RouteDeclaration] = []
    var mounts: [MountDeclaration] = []
    var notFound: FunctionDeclSyntax?
    var routeError: FunctionDeclSyntax?

    for member in declaration.memberBlock.members {
      if let alias = member.decl.as(TypeAliasDeclSyntax.self), alias.hasAttribute(named: "Mount") {
        if isFeature {
          diagnosed.diagnose(.init(node: Syntax(alias), message: RoutesDiagnostic.featureMount))
        } else if let path = alias.stringLiteralArgument(forAttributeNamed: "Mount") {
          if let mount = parseMount(alias, path: path, containerName: containerName, context: diagnosed) {
            mounts.append(mount)
          }
        } else {
          diagnosed.diagnose(
            .init(node: Syntax(alias), message: RoutesDiagnostic.mountRequiresStringLiteral)
          )
        }
        continue
      }

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
        validate(route: route, context: diagnosed)
        validateSignature(of: route, isLayout: false, context: diagnosed)
        validateDestinationFactory(for: route, context: diagnosed)
        validateUnique(route, against: routes, context: diagnosed)
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
        validate(route: layout, context: diagnosed)
        validateSignature(of: layout, isLayout: true, context: diagnosed)
        validateUnique(layout, against: layouts, context: diagnosed)
        layouts.append(layout)
      }

      if isFeature, function.hasAttribute(named: "NotFound") || function.hasAttribute(named: "RouteError") {
        if function.isStatic {
          context.diagnose(.init(node: Syntax(function), message: RoutesDiagnostic.featureFallback))
        }
        continue
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

    validateNames(in: RouteHierarchy(routes: routes, layouts: layouts), context: diagnosed)
    if isFeature {
      validateFeatureNames(routes + layouts, context: diagnosed)
    }
    // Schemas combine a route with its layouts, so they are only checked for declarations that
    // are valid on their own; otherwise one bad signature would also be reported as a conflict.
    let checked = RouteHierarchy(
      routes: routes.filter(diagnosed.isValid),
      layouts: layouts.filter(diagnosed.isValid)
    )
    validateDestinationSchemas(in: checked, context: diagnosed)
    var hierarchy = RouteHierarchy(
      routes: checked.routes.filter(diagnosed.isValid),
      layouts: checked.layouts
    )

    let validMounts = mounts.filter(diagnosed.isValid)
    if !validMounts.isEmpty {
      validateMounts(
        validMounts,
        in: hierarchy,
        declaredNames: (routes + layouts).map(\.name),
        context: diagnosed
      )
      hierarchy = RouteHierarchy(
        routes: hierarchy.routes.filter(diagnosed.isValid),
        layouts: hierarchy.layouts.filter(diagnosed.isValid),
        mounts: validMounts.filter(diagnosed.isValid)
      )
    }

    if let featureRoot {
      return featureDeclarations(
        access: access,
        containerName: containerName,
        root: featureRoot,
        hierarchy: hierarchy
      )
      .map { DeclSyntax(stringLiteral: $0) }
    }

    let mountHandleNames = Dictionary(
      uniqueKeysWithValues: hierarchy.mounts.map { mount in
        (mount.name, context.makeUniqueName("\(mount.name)Handles").text)
      }
    )

    return [
      DeclSyntax(
        stringLiteral: routeViewDeclaration(
          access: access,
          containerName: containerName,
          containerReference: containerName,
          hierarchy: hierarchy,
          notFound: notFound,
          routeError: routeError
        )
      ),
      DeclSyntax(
        stringLiteral: handlesDeclaration(
          access: access,
          routes: hierarchy.routes,
          layouts: hierarchy.layouts,
          mounts: hierarchy.mounts
        )
      ),
      DeclSyntax(
        stringLiteral: routeSetDeclaration(
          access: access,
          mode: mode,
          containerName: containerName,
          hierarchy: hierarchy
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
          containerName: containerName,
          mounts: hierarchy.mounts
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
          mode: mode,
          containerName: containerName
        )
      ),
      DeclSyntax(
        stringLiteral: routesFunctionDeclaration(
          access: access,
          containerName: containerName,
          hierarchy: hierarchy,
          mountHandleNames: mountHandleNames,
          notFound: notFound,
          routeError: routeError
        )
      ),
    ]
  }
}

/// The declarations of a feature: a generic `@Routes` struct whose routes a host mounts.
///
/// The feature's route view is concrete for each host `root`, so the host's outlet stores it as
/// one case. A feature has no router, provider, link, or fallbacks; its host owns them.
private func featureDeclarations(
  access: String,
  containerName: String,
  root: String,
  hierarchy: RouteHierarchy
) -> [String] {
  [
    routeViewDeclaration(
      access: access,
      containerName: containerName,
      containerReference: "\(containerName)<\(root)>",
      hierarchy: hierarchy,
      notFound: nil,
      routeError: nil
    ),
    handlesDeclaration(
      access: access,
      routes: hierarchy.routes,
      layouts: hierarchy.layouts,
      mounts: []
    ),
    featureRouteSetDeclaration(
      access: access,
      containerName: containerName,
      root: root,
      hierarchy: hierarchy
    ),
    featureRegistrationDeclaration(access: access, root: root, hierarchy: hierarchy),
  ]
}

private func featureRouteSetDeclaration(
  access: String,
  containerName: String,
  root: String,
  hierarchy: RouteHierarchy
) -> String {
  let factories = hierarchy.routes.map {
    destinationFactoryDeclaration(
      access: access,
      containerName: containerName,
      route: $0,
      hierarchy: hierarchy,
      contentType: root
    )
  }
  .joined(separator: "\n\n")

  return """
      /// This feature's routes in a host route tree, with a typed destination factory per route.
      ///
      /// Destinations are `RouteDestination<\(root)>` values of the host tree, so the host router
      /// and `RouteLink` accept them, and the host's own destinations share their type.
      ///
      /// The host's `Provider` installs the route set by its type; feature views read it with
      /// `@Environment(\(containerName)<\(root)>.RouteSet.self) var routes: \(containerName)<\(root)>.RouteSet?`.
      /// Each specialization is its own environment key, so features with the same name in other
      /// modules, and this feature mounted by another host, never share a value.
      \(access)final class RouteSet: _RouteEnvironmentObject {
        let tree: RouteTree<\(root)>
        \(access)let handles: Handles

        /// Creates the route set for the handles `_register(into:under:wrap:)` returned, in the
        /// tree the host built after registering them. Generated host route sets call this.
        \(access)init(_mountedIn tree: RouteTree<\(root)>, handles: Handles) {
          self.tree = tree
          self.handles = handles
        }

      \(factories)
      }
    """
}

/// Registers the feature's layouts and routes below a host mount record.
///
/// Feature records read their contexts from the end of the match stack, because the host's
/// layouts and mount record come first. `wrap` places the feature's view into the host's view.
private func featureRegistrationDeclaration(
  access: String,
  root: String,
  hierarchy: RouteHierarchy
) -> String {
  let layouts = hierarchy.layouts
  let layoutRegistrations = layouts.enumerated()
    .sorted { ($0.element.depth, $0.offset) < ($1.element.depth, $1.offset) }
    .map { entry in
      layoutRegistration(
        entry.element,
        parent: hierarchy.parent(ofLayout: entry.element),
        topLevelParent: "mount"
      )
    }
  let registrations = hierarchy.routes.map {
    leafRegistration($0, hierarchy: hierarchy, isFeature: true)
  }
  let handles = (layouts + hierarchy.routes).map { "\($0.name): \($0.name)" }.joined(separator: ", ")

  return """
      /// Registers this feature's layouts and routes below `mount` in a host route builder.
      ///
      /// `mount` is a layout record the host registered at a static path. `wrap` places the
      /// feature's view into the host's root view; it receives the contexts of the whole match
      /// stack, outermost host layout first. Generated hosts call this for each `@Mount`.
      \(access)static func _register(
        into collection: RouteBuilder<\(root)>,
        under mount: RouteHandle,
        wrap: @escaping (RouteView, [RouteContext]) -> \(root)
      ) -> Handles {
        \(layoutRegistrations.joined(separator: "\n"))
        \(registrations.joined(separator: "\n"))
        return Handles(\(handles))
      }
    """
}

/// Forwards to the expansion context and records which declarations were diagnosed.
///
/// Every route diagnostic is attached to its function declaration, so a declaration without a
/// recorded diagnostic passed validation.
private final class DiagnosedDeclarations<Base: MacroExpansionContext>: MacroExpansionContext {
  private let base: Base
  private var nodes: Set<SyntaxIdentifier> = []

  init(_ base: Base) {
    self.base = base
  }

  func isValid(_ declaration: RouteDeclaration) -> Bool {
    !nodes.contains(declaration.function.id)
  }

  func isValid(_ mount: MountDeclaration) -> Bool {
    !nodes.contains(mount.alias.id)
  }

  var lexicalContext: [Syntax] {
    base.lexicalContext
  }

  func makeUniqueName(_ name: String) -> TokenSyntax {
    base.makeUniqueName(name)
  }

  func diagnose(_ diagnostic: Diagnostic) {
    nodes.insert(diagnostic.node.id)
    base.diagnose(diagnostic)
  }

  func location(
    of node: some SyntaxProtocol,
    at position: PositionInSyntaxNode,
    filePathMode: SourceLocationFilePathMode
  ) -> AbstractSourceLocation? {
    base.location(of: node, at: position, filePathMode: filePathMode)
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

/// A feature mounted by a host with `@Mount("/path") typealias Name = Feature<RouteView>`.
private struct MountDeclaration {
  let alias: TypeAliasDeclSyntax
  let path: String
  /// The feature type without generic arguments, such as `ShopRoutes` or `Shop.ShopRoutes`.
  let featureTypeName: String

  /// The name of the mount's handle and route set property: the alias with a lowercase initial.
  var name: String {
    let aliasName = alias.name.text
    return aliasName.prefix(1).lowercased() + String(aliasName.dropFirst())
  }

  var depth: Int {
    RoutePath(path).segments.count
  }

  var normalizedPath: String {
    RoutePath(path).normalized
  }

  /// The feature specialized with the host's route view, such as
  /// `ShopRoutes<AppRoutes.RouteView>`.
  func featureType(in containerName: String) -> String {
    "\(featureTypeName)<\(containerName).RouteView>"
  }
}

/// Reads a `@Mount` type alias, reporting a path or type the host cannot mount.
private func parseMount(
  _ alias: TypeAliasDeclSyntax,
  path: String,
  containerName: String,
  context: some MacroExpansionContext
) -> MountDeclaration? {
  func diagnose(_ message: RoutesDiagnostic) {
    context.diagnose(.init(node: Syntax(alias), message: message))
  }

  let type = alias.initializer.value
  var featureTypeName: String?
  var arguments: GenericArgumentClauseSyntax?
  if let identifier = type.as(IdentifierTypeSyntax.self) {
    featureTypeName = identifier.name.text
    arguments = identifier.genericArgumentClause
  } else if let member = type.as(MemberTypeSyntax.self) {
    featureTypeName = member.baseType.trimmedDescription + "." + member.name.text
    arguments = member.genericArgumentClause
  }

  var argument = arguments?.arguments.first?.trimmedDescription ?? ""
  if argument.hasSuffix(",") {
    argument.removeLast()
  }
  guard alias.genericParameterClause == nil, let featureTypeName,
    arguments?.arguments.count == 1,
    argument == "RouteView" || argument == "\(containerName).RouteView"
  else {
    diagnose(.mountRequiresFeatureType)
    return nil
  }

  var isValid = true
  for segment in RoutePath(path).segments {
    if segment == "*" || segment.first == ":" {
      diagnose(.mountRequiresStaticPath(path: RoutePath(path).normalized))
      isValid = false
      break
    }
    let decoded = percentDecoded(segment)
    if decoded == "." || decoded == ".." {
      diagnose(.dotSegment(segment: segment))
      isValid = false
    }
  }

  return isValid
    ? MountDeclaration(alias: alias, path: path, featureTypeName: featureTypeName) : nil
}

/// Rejects mounts that would conflict with each other or with the host's own declarations.
///
/// A mounted feature owns every URL below its path, and the host macro cannot see the feature's
/// routes. Rejecting host routes, nested host layouts, and other mounts inside a mount's path
/// therefore rules out every route that could match the same URLs as a feature route. A layout
/// wrapping a mount must not need a required query, because the feature's destination factories
/// cannot supply it.
private func validateMounts(
  _ mounts: [MountDeclaration],
  in hierarchy: RouteHierarchy,
  declaredNames: [String],
  context: some MacroExpansionContext
) {
  // Whether two mounts name one feature type cannot be decided from spellings: aliases and module
  // names can spell one type differently, and unrelated modules can declare features with one
  // name. Generated `routes()` compares the specialized route set types instead.
  var names = Set(declaredNames)

  for (index, mount) in mounts.enumerated() {
    func diagnose(_ message: RoutesDiagnostic) {
      context.diagnose(.init(node: Syntax(mount.alias), message: message))
    }

    if reservedDeclarationNames.contains(mount.name) || reservedRouteSetNames.contains(mount.name) {
      diagnose(.reservedGeneratedName(name: mount.name))
    } else if !names.insert(mount.name).inserted {
      diagnose(.duplicateName(name: mount.name))
    }

    let path = RoutePath(mount.path)
    for earlier in mounts[..<index] {
      let other = RoutePath(earlier.path)
      if path.hasSegmentPrefix(other) || other.hasSegmentPrefix(path) {
        diagnose(.overlappingMount(path: mount.normalizedPath, otherPath: earlier.normalizedPath))
      }
    }

    for layout in hierarchy.ancestors(ofMount: mount) {
      for query in layout.queryParameters where query.queryDefaultValue == nil {
        diagnose(.mountRequiredLayoutQuery(mount: mount.name, layout: layout.name, query: query.label))
      }
    }
  }

  for route in hierarchy.routes {
    let path = RoutePath(route.path)
    if let mount = mounts.first(where: { path.hasSegmentPrefix(RoutePath($0.path)) }) {
      context.diagnose(
        .init(
          node: Syntax(route.function),
          message: RoutesDiagnostic.declarationInsideMount(
            path: route.normalizedPath,
            mount: mount.name,
            mountPath: mount.normalizedPath
          )
        )
      )
    }
  }

  // A layout at exactly a mount's path wraps the mount; a deeper one would wrap feature routes.
  for layout in hierarchy.layouts {
    let path = RoutePath(layout.path)
    if let mount = mounts.first(where: {
      layout.depth > $0.depth && path.hasSegmentPrefix(RoutePath($0.path))
    }) {
      context.diagnose(
        .init(
          node: Syntax(layout.function),
          message: RoutesDiagnostic.declarationInsideMount(
            path: layout.normalizedPath,
            mount: mount.name,
            mountPath: mount.normalizedPath
          )
        )
      )
    }
  }
}

/// Names a feature declaration may not use, because `_register(into:under:wrap:)` binds them.
private let reservedFeatureNames: Set<String> = ["mount", "wrap"]

private func validateFeatureNames(
  _ declarations: [RouteDeclaration],
  context: some MacroExpansionContext
) {
  for declaration in declarations where reservedFeatureNames.contains(declaration.name) {
    context.diagnose(
      .init(
        node: Syntax(declaration.function),
        message: RoutesDiagnostic.reservedGeneratedName(name: declaration.name)
      )
    )
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
  /// The parameter's name inside the function, used in diagnostics.
  let name: String
  let type: String
  let defaultValue: String?

  init(parameter: FunctionParameterSyntax) {
    self.label = parameter.firstName.text
    self.name = (parameter.secondName ?? parameter.firstName).text
    self.type = parameter.type.trimmedDescription
    self.defaultValue = parameter.defaultValue?.value.trimmedDescription
  }

  /// `false` for a parameter declared with `_`, which generated calls cannot pass by label.
  var hasLabel: Bool {
    label != "_"
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

  /// The content type of an `Outlet<Content>` parameter, such as `Content`.
  var outletContentType: String? {
    var type = self.type
    if type.hasPrefix("ElementaryRouter.") {
      type = String(type.dropFirst("ElementaryRouter.".count))
    }
    guard type.hasPrefix("Outlet<"), type.hasSuffix(">") else {
      return nil
    }
    return String(type.dropFirst("Outlet<".count).dropLast())
  }

  /// The argument passed to the route function for a value bound from generated storage.
  func viewArgument(_ value: String) -> String {
    switch kind {
    case .context, .path:
      return "\(label): \(value)"
    case .outlet:
      return "\(label): Outlet(\(value))"
    case .wildcard:
      return "\(label): Wildcard(\(value))"
    case .query:
      return "\(label): Query(\(value))"
    }
  }

  /// The expression that decodes this parameter's stored value from `context`.
  ///
  /// Outlets are not decoded; their value is the child content.
  func decodedValue(from context: String) -> String? {
    switch kind {
    case .outlet:
      return nil
    case .context:
      return context
    case .wildcard:
      return "try \(context).params.require(\"*\", String.self)"
    case .query:
      let valueType = queryValueType ?? storageType
      if let defaultValue = queryDefaultValue {
        return "\(context).query.get(\"\(label)\", \(valueType).self) ?? \(defaultValue)"
      }
      return "try \(context).query.require(\"\(label)\", \(valueType).self)"
    case .path:
      return "try \(context).params.require(\"\(label)\", \(type).self)"
    }
  }

  /// The type of this parameter's associated value in generated route view storage.
  func associatedValueType(outletType: String) -> String {
    switch kind {
    case .context:
      return "RouteContext"
    case .outlet:
      return outletType
    case .path, .query, .wildcard:
      return storageType
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

  // Browsers resolve `.` and `..`, including `%2E` forms, before the router sees the path.
  for segment in segments where segment.first != ":" && segment != "*" {
    let decoded = percentDecoded(segment)
    if decoded == "." || decoded == ".." {
      context.diagnose(
        .init(
          node: Syntax(route.function),
          message: RoutesDiagnostic.dotSegment(segment: segment)
        )
      )
    }
  }
}

/// Members of the generated `RouteSet` that a destination factory must not shadow.
private let reservedRouteSetNames: Set<String> = ["tree", "handles", "router", "href"]

/// Rejects routes whose generated destination factory would collide with other generated API.
private func validateDestinationFactory(
  for route: RouteDeclaration,
  context: some MacroExpansionContext
) {
  if reservedRouteSetNames.contains(route.name) {
    context.diagnose(
      .init(
        node: Syntax(route.function),
        message: RoutesDiagnostic.reservedRouteName(name: route.name)
      )
    )
  }

  // Every factory takes a trailing `hash:` argument for the URL fragment.
  if route.storageParameters.contains(where: { $0.label == "hash" }) {
    context.diagnose(
      .init(node: Syntax(route.function), message: RoutesDiagnostic.reservedHashParameter)
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

/// Rejects route and layout signatures that generated route views cannot call.
private func validateSignature(
  of declaration: RouteDeclaration,
  isLayout: Bool,
  context: some MacroExpansionContext
) {
  let function = declaration.function
  func diagnose(_ message: RoutesDiagnostic) {
    context.diagnose(.init(node: Syntax(function), message: message))
  }

  if function.signature.effectSpecifiers != nil {
    diagnose(.unsupportedEffects)
  }

  var labels: Set<String> = []
  for parameter in declaration.parameters {
    if !parameter.hasLabel {
      diagnose(.unlabeledParameter(name: parameter.name))
    } else if !labels.insert(parameter.label).inserted {
      diagnose(.duplicateParameterLabel(label: parameter.label))
    }
  }

  let genericParameters =
    function.genericParameterClause?.parameters.map { $0.name.text } ?? []
  let outlets = declaration.parameters.filter { $0.kind == .outlet }

  guard isLayout else {
    if !genericParameters.isEmpty {
      diagnose(.genericRoute)
    }
    if !outlets.isEmpty {
      diagnose(.routeOutlet)
    }
    return
  }

  guard let outlet = outlets.first else {
    diagnose(.layoutRequiresOutlet)
    return
  }
  if outlets.count > 1 {
    diagnose(.multipleOutlets)
    return
  }
  // The generated outlet view is a concrete type, so it can only be passed for the layout's
  // single generic parameter.
  guard let content = outlet.outletContentType, genericParameters == [content] else {
    diagnose(.layoutOutletNotGeneric)
    return
  }
}

/// Names a generated declaration may not use, because generated code defines them itself.
///
/// `collection` is the builder local of `routes()`, `notFound` and `routeError` are the
/// fallback cases of `RouteView.Storage`, and `content` is the view of each layout's outlet enum.
private let reservedDeclarationNames: Set<String> = [
  "collection", "content", "notFound", "routeError",
]

/// Rejects route and layout names that would generate conflicting declarations.
private func validateNames(in hierarchy: RouteHierarchy, context: some MacroExpansionContext) {
  var names: Set<String> = []
  var outletTypes: [String: String] = [:]

  for declaration in hierarchy.layouts + hierarchy.routes {
    func diagnose(_ message: RoutesDiagnostic) {
      context.diagnose(.init(node: Syntax(declaration.function), message: message))
    }

    if reservedDeclarationNames.contains(declaration.name) {
      diagnose(.reservedGeneratedName(name: declaration.name))
    }
    if !names.insert(declaration.name).inserted {
      diagnose(.duplicateName(name: declaration.name))
      continue
    }
    if hierarchy.isLayout(declaration) {
      let type = outletTypeName(for: declaration)
      if let other = outletTypes[type] {
        diagnose(.outletTypeCollision(name: declaration.name, otherName: other, type: type))
      } else {
        outletTypes[type] = declaration.name
      }
    }
  }
}

/// The routes and layouts of one `@Routes` type, arranged as the registered route tree.
private struct RouteHierarchy {
  let routes: [RouteDeclaration]
  let layouts: [RouteDeclaration]
  var mounts: [MountDeclaration] = []

  /// One entry of a generated storage enum: a layout with its outlet, or a leaf route.
  struct Node {
    let declaration: RouteDeclaration
    let isLayout: Bool
  }

  func isLayout(_ declaration: RouteDeclaration) -> Bool {
    layouts.contains { $0.function.id == declaration.function.id }
  }

  /// The innermost layout that wraps `route`, which is its registration parent.
  func parent(ofRoute route: RouteDeclaration) -> RouteDeclaration? {
    matchingLayouts(for: route, layouts: layouts).last
  }

  /// The innermost layout that wraps `layout`, which is its registration parent.
  func parent(ofLayout layout: RouteDeclaration) -> RouteDeclaration? {
    enclosingLayout(for: layout, layouts: layouts)
  }

  /// The layouts that wrap `route`, from outermost to innermost, following registration parents.
  ///
  /// This is the order of the runtime match stack, so the layout at index `i` reads its values
  /// from the match context at index `i`, and the route from the context after the last layout.
  func ancestors(ofRoute route: RouteDeclaration) -> [RouteDeclaration] {
    var chain: [RouteDeclaration] = []
    var current = parent(ofRoute: route)
    while let layout = current {
      chain.append(layout)
      current = parent(ofLayout: layout)
    }
    return chain.reversed()
  }

  /// The innermost layout that wraps `mount`, including a layout at exactly the mount's path.
  func parent(ofMount mount: MountDeclaration) -> RouteDeclaration? {
    matchingLayouts(forPath: mount.path, layouts: layouts).last
  }

  /// The layouts that wrap `mount`, from outermost to innermost.
  func ancestors(ofMount mount: MountDeclaration) -> [RouteDeclaration] {
    var chain: [RouteDeclaration] = []
    var current = parent(ofMount: mount)
    while let layout = current {
      chain.append(layout)
      current = parent(ofLayout: layout)
    }
    return chain.reversed()
  }

  /// The mounts directly inside `layout`, or the top-level mounts for `nil`.
  func mounts(in layout: RouteDeclaration?) -> [MountDeclaration] {
    mounts.filter { parent(ofMount: $0)?.name == layout?.name }
  }

  /// Names of the layouts that wrap at least one route or mount.
  ///
  /// Other layouts never join a match stack, so they get no storage case or outlet view.
  var renderedLayoutNames: Set<String> {
    Set(
      routes.flatMap { ancestors(ofRoute: $0).map(\.name) }
        + mounts.flatMap { ancestors(ofMount: $0).map(\.name) }
    )
  }

  var renderedLayouts: [RouteDeclaration] {
    let names = renderedLayoutNames
    return layouts.filter { names.contains($0.name) }
  }

  /// The direct children of `layout`, or the top-level declarations for `nil`.
  ///
  /// Each child is one case of the layout's outlet storage, so the layout's own view stays
  /// outside the switch that selects among its children.
  func children(of layout: RouteDeclaration?) -> [Node] {
    let childLayouts = renderedLayouts.filter { parent(ofLayout: $0)?.name == layout?.name }
    let childRoutes = routes.filter { parent(ofRoute: $0)?.name == layout?.name }
    return childLayouts.map { Node(declaration: $0, isLayout: true) }
      + childRoutes.map { Node(declaration: $0, isLayout: false) }
  }
}

/// The generated outlet enum, nested in `RouteView`, that stores the children of `layout`.
private func outletTypeName(for layout: RouteDeclaration) -> String {
  layout.name.prefix(1).uppercased() + String(layout.name.dropFirst()) + "Outlet"
}

/// Returns every layout that wraps `route`, from outermost to innermost.
///
/// A layout wraps a route when the layout path names the route's leading segments, including a
/// layout declared at exactly the route's path.
private func matchingLayouts(for route: RouteDeclaration, layouts: [RouteDeclaration])
  -> [RouteDeclaration]
{
  matchingLayouts(forPath: route.path, layouts: layouts)
}

private func matchingLayouts(forPath path: String, layouts: [RouteDeclaration]) -> [RouteDeclaration] {
  let path = RoutePath(path)
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
  relativePath(route.path, under: layout)
}

private func relativePath(_ path: String, under layout: RouteDeclaration?) -> String {
  guard let layout else {
    return path
  }

  let remaining = RoutePath(path).segments.dropFirst(layout.depth)
  return remaining.isEmpty ? "/" : remaining.joined(separator: "/")
}

/// The storage case of a mount, which holds the mounted feature's route view.
private func mountCaseDeclaration(_ mount: MountDeclaration, containerName: String) -> String {
  "case \(mount.name)(\(mount.featureType(in: containerName)).RouteView)"
}

private func mountSwitchCase(_ mount: MountDeclaration) -> String {
  """
  case .\(mount.name)(let content):
    content
  """
}

/// `containerName` names the declaring type; `containerReference` is the expression that calls
/// its route functions, which is the type specialized with its root for a feature.
private func routeViewDeclaration(
  access: String,
  containerName: String,
  containerReference: String,
  hierarchy: RouteHierarchy,
  notFound: FunctionDeclSyntax?,
  routeError: FunctionDeclSyntax?
) -> String {
  let topLevel = hierarchy.children(of: nil)
  let topLevelMounts = hierarchy.mounts(in: nil)
  let cases =
    topLevel.map(storageCaseDeclaration)
    + topLevelMounts.map { mountCaseDeclaration($0, containerName: containerName) }
    + (notFound == nil ? [] : ["case notFound(RouteNotFoundContext)"])
    + (routeError == nil ? [] : ["case routeError(RouteErrorContext)"])

  let notFoundSwitch = notFound.map { function in
    """
    case .notFound(let context):
      \(containerReference).\(function.name.text)(context: context)
    """
  }
  let errorSwitch = routeError.map { function in
    """
    case .routeError(let context):
      \(containerReference).\(function.name.text)(context: context)
    """
  }
  let switchCases =
    topLevel.map { storageSwitchCase(containerName: containerReference, node: $0) }
    + topLevelMounts.map(mountSwitchCase)
    + [notFoundSwitch, errorSwitch].compactMap { $0 }

  let outlets = hierarchy.renderedLayouts.map { layout in
    outletStorageDeclaration(
      access: access,
      containerName: containerName,
      containerReference: containerReference,
      layout: layout,
      children: hierarchy.children(of: layout),
      mounts: hierarchy.mounts(in: layout)
    )
  }

  return """
    /// The typed view tree for every matched route of this route set.
    ///
    /// Each layout is rendered outside the switch that selects among its direct children, so
    /// navigating between routes that share a layout keeps that layout mounted.
    @View
    \(access)struct RouteView {
      \(access)enum Storage {
        \(cases.joined(separator: "\n"))
      }

      let storage: Storage

      \(access)init(storage: Storage) {
        self.storage = storage
      }

      \(access)var body: some View {
        \(switchBody(switchCases, subject: "storage"))
      }

      \(outlets.joined(separator: "\n\n"))
    }
    """
}

/// The enum, nested in `RouteView`, that stores and renders the matched child of `layout`.
///
/// The layout's own call is made by its parent, outside this enum's switch, so a change of child
/// replaces only the content of the outlet. The enum is rendered by the library's generic
/// `_RouteOutlet` view. It is a plain enum with an inline conformance, rather than a nested
/// `@View`, because conformances that `@View` adds to a type nested in macro-generated
/// `RouteView` are not emitted, which fails to link natively and to compile for Embedded Swift.
private func outletStorageDeclaration(
  access: String,
  containerName: String,
  containerReference: String,
  layout: RouteDeclaration,
  children: [RouteHierarchy.Node],
  mounts: [MountDeclaration]
) -> String {
  let cases =
    children.map(storageCaseDeclaration)
    + mounts.map { mountCaseDeclaration($0, containerName: containerName) }
  let switchCases =
    children.map { storageSwitchCase(containerName: containerReference, node: $0) }
    + mounts.map(mountSwitchCase)

  return """
    /// The matched child of the `\(layout.name)` layout.
    \(access)enum \(outletTypeName(for: layout)): _RouteOutletStorage {
      \(cases.joined(separator: "\n"))

      @HTMLBuilder \(access)var content: some View {
        \(switchBody(switchCases, subject: "self"))
      }
    }
    """
}

private func switchBody(_ cases: [String], subject: String) -> String {
  guard !cases.isEmpty else {
    return "EmptyHTML()"
  }
  return """
    switch \(subject) {
    \(cases.joined(separator: "\n"))
    }
    """
}

/// The type of the outlet value a layout receives for its children.
private func outletViewType(for layout: RouteDeclaration) -> String {
  "_RouteOutlet<\(outletTypeName(for: layout))>"
}

/// The storage case of a route or layout, with one associated value per function parameter.
///
/// A layout's outlet parameter stores the outlet view of its children.
private func storageCaseDeclaration(_ node: RouteHierarchy.Node) -> String {
  let declaration = node.declaration
  let outletType = node.isLayout ? outletViewType(for: declaration) : ""
  let values = declaration.parameters.map { parameter in
    "\(parameter.label): \(parameter.associatedValueType(outletType: outletType))"
  }
  return values.isEmpty
    ? "case \(declaration.name)"
    : "case \(declaration.name)(\(values.joined(separator: ", ")))"
}

/// The switch case that calls a route or layout function with its stored values.
///
/// Values are bound to generated names, so parameter labels never collide with locals.
private func storageSwitchCase(containerName: String, node: RouteHierarchy.Node) -> String {
  let declaration = node.declaration
  let parameters = declaration.parameters
  let arguments = parameters.enumerated().map { index, parameter in
    parameter.viewArgument("value\(index)")
  }
  let call = "\(containerName).\(declaration.name)(\(arguments.joined(separator: ", ")))"

  if parameters.isEmpty {
    return """
      case .\(declaration.name):
        \(call)
      """
  }

  let bindings = parameters.indices.map { "let value\($0)" }.joined(separator: ", ")
  return """
    case .\(declaration.name)(\(bindings)):
      \(call)
    """
}

private func handlesDeclaration(
  access: String,
  routes: [RouteDeclaration],
  layouts: [RouteDeclaration],
  mounts: [MountDeclaration]
) -> String {
  // A mount's handle is its mount record, so `.descendant` checks cover the whole feature.
  let names = layouts.map(\.name) + mounts.map(\.name) + routes.map(\.name)
  let properties = names.map { "\(access)let \($0): RouteHandle" }.joined(
    separator: "\n    "
  )
  let arguments = names.map { "\($0): RouteHandle" }.joined(separator: ", ")
  let assignments = names.map { "self.\($0) = \($0)" }.joined(separator: "\n      ")

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
  containerName: String,
  hierarchy: RouteHierarchy
) -> String {
  // Layouts never match a location on their own, so only routes get destination factories.
  let factories = hierarchy.routes.map {
    destinationFactoryDeclaration(
      access: access,
      containerName: containerName,
      route: $0,
      hierarchy: hierarchy
    )
  }
  .joined(separator: "\n\n")
  let routerType = routerType(mode: mode, routeViewType: "RouteView")
  let routerInitializer = routerInitializer(mode: mode, treeName: "tree")
  let mounts = hierarchy.mounts
  let mountProperties = mounts.map { mount in
    """
    /// The routes of the feature mounted at `\(mount.normalizedPath)`, in this route set's tree.
        \(access)let \(mount.name): \(mount.featureType(in: containerName)).RouteSet
    """
  }
  let mountParameters = mounts.map { ", \($0.name): \($0.featureType(in: containerName)).Handles" }
  let mountAssignments = mounts.map { mount in
    "self.\(mount.name) = \(mount.featureType(in: containerName)).RouteSet(_mountedIn: tree, handles: \(mount.name))"
  }

  return """
      \(access)struct RouteSet {
        let tree: RouteTree<RouteView>
        \(access)let handles: Handles
        \(mountProperties.joined(separator: "\n    "))

        init(tree: RouteTree<RouteView>, handles: Handles\(mountParameters.joined())) {
          self.tree = tree
          self.handles = handles
          \(mountAssignments.joined(separator: "\n      "))
        }

        \(access)func router() -> \(routerType) {
          \(routerInitializer)
        }

        \(access)func href(to destination: RouteDestination<RouteView>) throws(RouteMatchError) -> String {
          try tree._validate(destination)
          return \(destinationHrefExpression(mode: mode, destination: "destination"))
        }

      \(factories)
      }
    """
}

/// The href a generated link or route set uses for `destination` in the declared mode.
///
/// It matches `Router.href(to:)` and `HashRouter.href(to:)`, without needing a router.
private func destinationHrefExpression(mode: RoutesMode, destination: String) -> String {
  switch mode {
  case .path:
    return "\(destination).location.href"
  case .hash:
    return "\"#\" + \(destination).location.href"
  }
}

/// Query value types whose encoding always decodes again.
private let builtInRouteValueTypes: Set<String> = ["String", "Int", "Double", "Bool"]

/// One query value of a destination factory, shared by a route and every layout above it.
///
/// A query name is one URL value, so a route and its layouts that declare the same name read the
/// same value. The factory takes it once: required when any declaration has no default, and
/// otherwise optional, so that omitting it lets every declaration use its own default.
private struct DestinationQuery {
  let label: String
  let type: String
  var isRequired: Bool
}

/// The query values of `route` and its layouts, the route's own first, then each layout's from
/// the outermost layout in.
///
/// Conflicting types are reported by `validateDestinationSchemas`; the first declaration's type
/// is used here.
private func destinationQueries(
  for route: RouteDeclaration,
  hierarchy: RouteHierarchy
) -> [DestinationQuery] {
  var queries: [DestinationQuery] = []
  for declaration in [route] + hierarchy.ancestors(ofRoute: route) {
    for parameter in declaration.queryParameters {
      let isRequired = parameter.queryDefaultValue == nil
      if let index = queries.firstIndex(where: { $0.label == parameter.label }) {
        queries[index].isRequired = queries[index].isRequired || isRequired
      } else {
        queries.append(
          DestinationQuery(label: parameter.label, type: parameter.storageType, isRequired: isRequired)
        )
      }
    }
  }
  return queries
}

/// Rejects routes whose layouts would decode the route's URL values with incompatible schemas.
///
/// A route and its layouts read the same path and query values, so a value the route accepts
/// must decode for every layout too. Shared path parameters and shared query names must use one
/// type; otherwise a typed destination could build a URL that a layout cannot render.
private func validateDestinationSchemas(
  in hierarchy: RouteHierarchy,
  context: some MacroExpansionContext
) {
  var reported: Set<String> = []

  for route in hierarchy.routes {
    func diagnose(_ message: RoutesDiagnostic) {
      guard reported.insert(message.message).inserted else { return }
      context.diagnose(.init(node: Syntax(route.function), message: message))
    }

    let layouts = hierarchy.ancestors(ofRoute: route)
    var routePathTypes: [String: String] = [:]
    for parameter in route.pathStorageParameters where routePathTypes[parameter.label] == nil {
      routePathTypes[parameter.label] = canonicalTypeName(parameter.type)
    }
    // The factory's path and wildcard arguments, which a layout query must not share a label with.
    let routeArgumentLabels = Set(
      route.storageParameters.filter { $0.kind == .path || $0.kind == .wildcard }.map(\.label)
    )

    for layout in layouts {
      for parameter in layout.pathStorageParameters {
        if let routeType = routePathTypes[parameter.label],
          routeType != canonicalTypeName(parameter.type)
        {
          diagnose(
            .pathTypeConflict(
              name: parameter.label,
              layout: layout.name,
              layoutType: parameter.type,
              route: route.name,
              routeType: routeType
            )
          )
        }
      }
    }

    var queryOwners: [String: (owner: String, type: String)] = [:]
    for declaration in layouts + [route] {
      let isRoute = declaration.name == route.name
      for parameter in declaration.queryParameters {
        if !isRoute, parameter.label == "hash" {
          diagnose(.reservedHashParameter)
        }
        if !isRoute, routeArgumentLabels.contains(parameter.label) {
          diagnose(
            .queryPathConflict(name: parameter.label, owner: declaration.name, route: route.name)
          )
        }
        if let first = queryOwners[parameter.label] {
          if canonicalTypeName(first.type) != canonicalTypeName(parameter.storageType) {
            diagnose(
              .queryTypeConflict(
                name: parameter.label,
                firstOwner: first.owner,
                firstType: first.type,
                secondOwner: declaration.name,
                secondType: parameter.storageType
              )
            )
          }
        } else {
          queryOwners[parameter.label] = (declaration.name, parameter.storageType)
        }
      }
    }
  }
}

/// The spelling used to compare declared value types, with a leading `Swift.` removed.
///
/// Macros see type spellings, not resolved types, so `Int` and `Swift.Int` compare equal, but a
/// typealias and the type it names, or a type spelled with its module name, do not.
private func canonicalTypeName(_ type: String) -> String {
  type.hasPrefix("Swift.") ? String(type.dropFirst("Swift.".count)) : type
}

/// Returns `true` when a route's destination factory can never fail.
///
/// A route with no path or wildcard values has a static path, which matching precedence never
/// lets another route claim, and so do its layouts. Built-in query values always round-trip and
/// always decode for the route and its layouts. Any path value can be empty, invalid for a
/// custom `RouteValue`, or claimed by a static sibling route, so routes with path values get
/// throwing factories.
private func hasInfallibleDestination(
  _ route: RouteDeclaration,
  queries: [DestinationQuery]
) -> Bool {
  route.storageParameters.allSatisfy { $0.kind == .query }
    && queries.allSatisfy { builtInRouteValueTypes.contains(canonicalTypeName($0.type)) }
}

private func destinationFactoryDeclaration(
  access: String,
  containerName: String,
  route: RouteDeclaration,
  hierarchy: RouteHierarchy,
  contentType: String = "RouteView"
) -> String {
  let pathParameters = route.storageParameters.filter {
    $0.kind == .path || $0.kind == .wildcard
  }
  let queries = destinationQueries(for: route, hierarchy: hierarchy)

  let parameters =
    pathParameters.map { "\($0.label): \($0.storageType)" }
    + queries.map { query in
      query.isRequired ? "\(query.label): \(query.type)" : "\(query.label): \(query.type)? = nil"
    }
  let signatureParameters = (parameters + ["hash: String = \"\""]).joined(separator: ", ")

  // Values are chained onto one expression, so parameter names never collide with locals.
  let params = pathParameters.reduce("RouteValues()") { expression, parameter in
    let key = parameter.kind == .wildcard ? "*" : parameter.label
    return "\(expression)._setting(\"\(key)\", \(parameter.label))"
  }
  let query = queries.reduce("RouteValues()") { expression, query in
    // An omitted defaulted query value stays out of the URL; each declaration reads its default.
    let method = query.isRequired ? "_setting" : "_settingIfPresent"
    return "\(expression).\(method)(\"\(query.label)\", \(query.label))"
  }
  let build = """
    try self.tree._destination(
              to: self.handles.\(route.name),
              params: \(params),
              query: \(query),
              hash: hash
            )
    """

  if hasInfallibleDestination(route, queries: queries) {
    return """
        \(access)func \(route.name)(\(signatureParameters)) -> RouteDestination<\(contentType)> {
          do throws(RouteMatchError) {
            return \(build)
          } catch {
            preconditionFailure("\(containerName).RouteSet.\(route.name) failed to build a static destination.")
          }
        }
      """
  }

  return """
      \(access)func \(route.name)(\(signatureParameters)) throws(RouteMatchError) -> RouteDestination<\(contentType)> {
        \(build)
      }
    """
}

private func providerDeclaration(
  access: String,
  mode: RoutesMode,
  containerName: String,
  mounts: [MountDeclaration]
) -> String {
  let router = routerType(mode: mode, routeViewType: "RouteView")
  // Mounted features and `RouteLink` only know the route view type, so they read the router
  // through its navigator and each feature reads its own route set. Both are identified by their
  // type, which includes this route set's view.
  let mountEnvironment = mounts.map { mount in
    "\n      .environment(routes.\(mount.name))"
  }

  return """
      @View
      \(access)struct Provider<Content: View> {
        let routes: RouteSet
        let router: \(router)
        let content: Content

        \(access)init(_ routes: RouteSet, router: \(router), @HTMLBuilder content: () -> Content) {
          precondition(
            router._uses(routes.tree),
            "\(containerName).Provider requires a router created by the same RouteSet."
          )
          self.routes = routes
          self.router = router
          self.content = content()
        }

        \(access)var body: some View {
          content.environment(\(containerName)._routerEnvironmentKey, router)
            .environment(\(containerName)._routeSetEnvironmentKey, routes)
            .environment(router.navigator)\(mountEnvironment.joined())
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
      /// Renders the current route of a route set and provides that route set and its router.
      ///
      /// `RouterView()` owns its route set and router: they are created the first time the
      /// mounted view renders and are kept, with the router's history listener, until the view is
      /// unmounted. Rebuilding the parent body does not create them again.
      ///
      /// `RouterView(routes, router:)` renders the supplied pair, which the caller owns. When a
      /// later parent body supplies a different pair, the view renders that pair from then on.
      @View
      \(access)struct RouterView {
        // A session is cheap to create; only the one kept by the mounted view builds a router.
        @State var session = _RouterViewSession<RouteSet, \(router)> {
          do throws(RouteTreeError) {
            let routes = try \(containerName).routes()
            return (routes: routes, router: routes.router())
          } catch {
            preconditionFailure("\(containerName).RouterView could not build routes.")
          }
        }

        let supplied: (routes: RouteSet, router: \(router))?

        \(access)init() {
          self.supplied = nil
        }

        \(access)init(_ routes: RouteSet, router: \(router)) {
          precondition(
            router._uses(routes.tree),
            "\(containerName).RouterView requires a router created by the same RouteSet."
          )
          self.supplied = (routes: routes, router: router)
        }

        /// The rendered route set: the supplied one, or the one this view owns.
        var routes: RouteSet {
          supplied?.routes ?? session.routes
        }

        /// The rendered router: the supplied one, or the one this view owns.
        var router: \(router) {
          supplied?.router ?? session.router
        }

        \(access)var body: some View {
          Provider(routes, router: router) {
            rendered
          }
        }

        // `routes()` registers `@NotFound` and `@RouteError` as the route set's fallbacks; a
        // route set without them has no content to render for the failure.
        private var rendered: RouteView {
          do throws(RouterRenderError) {
            return try router.renderCurrentRoute()
          } catch {
            switch error {
            case .routeNotFound:
              preconditionFailure(
                "\(containerName).RouterView: no route matches the current location. Declare @NotFound to render it."
              )
            case .routeRenderFailed:
              preconditionFailure(
                "\(containerName).RouterView: a route value of the current location could not be decoded. Declare @RouteError to render it."
              )
            }
          }
        }
      }
    """
}

private func linkDeclaration(
  access: String,
  mode: RoutesMode,
  containerName: String
) -> String {
  return """
      @View
      \(access)struct Link<Content: View> {
        @Environment(\(containerName)._routerEnvironmentKey) var router

        let destination: RouteDestination<RouteView>
        let replace: Bool
        let target: HTMLAttributeValue.Target?
        let content: Content

        \(access)init(
          to destination: RouteDestination<RouteView>,
          replace: Bool = false,
          target: HTMLAttributeValue.Target? = nil,
          @HTMLBuilder content: () -> Content
        ) {
          self.destination = destination
          self.replace = replace
          self.target = target
          self.content = content()
        }

        \(access)var body: some View {
          if let target {
            a(.href(href), .target(target)) {
              content
            }
            .attributes(.data("router-link", value: "true"), when: usesClientNavigation)
            .onClick { event in
              handleClick(event)
            }
          } else {
            a(.href(href)) {
              content
            }
            .attributes(.data("router-link", value: "true"), when: usesClientNavigation)
            .onClick { event in
              handleClick(event)
            }
          }
        }

        /// The destination href in this route set's mode, which does not depend on a router.
        var href: String {
          \(destinationHrefExpression(mode: mode, destination: "destination"))
        }

        /// Client navigation needs a provided router that accepts the destination. Otherwise the
        /// anchor is left to normal browser navigation to the same href.
        private var usesClientNavigation: Bool {
          router?._accepts(destination) ?? false
        }

        private func handleClick(_ event: MouseEvent) {
          guard
            event.button == 0,
            !event.altKey,
            !event.ctrlKey,
            !event.metaKey,
            !event.shiftKey,
            target == nil || target?.rawValue == "" || target?.rawValue == "_self",
            let router,
            router._accepts(destination)
          else {
            return
          }

          do throws(RouteMatchError) {
            try router.navigate(to: destination, replace: replace)
          } catch {
            assertionFailure("\(containerName).Link could not navigate to an accepted destination.")
          }
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
  containerName: String,
  hierarchy: RouteHierarchy,
  mountHandleNames: [String: String],
  notFound: FunctionDeclSyntax?,
  routeError: FunctionDeclSyntax?
) -> String {
  let routes = hierarchy.routes
  let layouts = hierarchy.layouts
  let mounts = hierarchy.mounts
  // Register outer layouts first so each nested layout can reference its parent handle.
  let layoutRegistrations = layouts.enumerated()
    .sorted { ($0.element.depth, $0.offset) < ($1.element.depth, $1.offset) }
    .map { entry in
      layoutRegistration(
        entry.element,
        parent: hierarchy.parent(ofLayout: entry.element),
        topLevelParent: "nil"
      )
    }
  let mountRegistrations = mounts.map { mount in
    mountRegistration(
      mount,
      hierarchy: hierarchy,
      containerName: containerName,
      handlesName: mountHandleNames[mount.name] ?? "\(mount.name)Handles"
    )
  }
  let registrations = routes.map { leafRegistration($0, hierarchy: hierarchy, isFeature: false) }

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

  let handleNames = layouts.map(\.name) + mounts.map(\.name) + routes.map(\.name)
  let handles = handleNames.map { "\($0): \($0)" }.joined(separator: ", ")
  let mountArguments = mounts.map { mount in
    ",\n      \(mount.name): \(mountHandleNames[mount.name] ?? "\(mount.name)Handles")"
  }
  // Spellings cannot tell whether two aliases name one feature type, so the specialized route
  // set types are compared before anything is registered.
  let featureIdentities = mounts.map { mount in
    "(identity: \(mount.featureType(in: containerName)).RouteSet._environmentIdentity, path: \"\(mount.normalizedPath)\")"
  }
  let distinctFeatureCheck =
    featureIdentities.count < 2
    ? ""
    : "try RouteBuilder<RouteView>._checkDistinctFeatures([\(featureIdentities.joined(separator: ", "))])"
  return """
      \(access)static func routes() throws(RouteTreeError) -> RouteSet {
        \(distinctFeatureCheck)
        let collection = RouteBuilder<RouteView>()
        \(layoutRegistrations.joined(separator: "\n"))
        \(mountRegistrations.joined(separator: "\n"))
        \(registrations.joined(separator: "\n"))
        \([notFoundRegistration, errorRegistration].compactMap { $0 }.joined(separator: "\n"))
        return RouteSet(
          tree: try collection._build(),
          handles: Handles(\(handles))\(mountArguments.joined())
        )
      }
    """
}

/// Registers a mount record at the mount's static path and the mounted feature below it.
///
/// The wrapper builds the host's view around the feature's view, with each enclosing host layout
/// reading its values from its own context. Host layouts lead the match stack, so they read their
/// contexts from the start of it, as the host's own routes do.
private func mountRegistration(
  _ mount: MountDeclaration,
  hierarchy: RouteHierarchy,
  containerName: String,
  handlesName: String
) -> String {
  let ancestors = hierarchy.ancestors(ofMount: mount)
  var usesContexts = false
  let storage = wrappingLayouts(
    ".\(mount.name)(content)",
    in: ancestors,
    context: { "contexts[\($0)]" },
    usesContexts: &usesContexts
  )
  let parameters = usesContexts ? "content, contexts" : "content, _"
  let parent = registrationParent(parent: ancestors.last, topLevelParent: "nil")

  return """
    let \(mount.name) = collection._generatedLayout("\(relativePath(mount.path, under: ancestors.last))", parent: \(parent), decode: { _ in })
    let \(handlesName) = \(mount.featureType(in: containerName))._register(into: collection, under: \(mount.name), wrap: { \(parameters) in
      RouteView(storage: \(storage))
    })
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
  guard let modeArgument = node.modeArgument else {
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

/// Registers a layout whose decoder checks the layout's own values with its own context.
///
/// Decoding runs before any descendant renders, so a failure is reported with the layout's
/// context. Values that cannot fail, such as defaulted queries, are not decoded here.
/// `topLevelParent` is the parent of a layout that no other layout wraps: `nil` for a route set,
/// or the mount record for a feature.
private func layoutRegistration(
  _ layout: RouteDeclaration,
  parent: RouteDeclaration?,
  topLevelParent: String
) -> String {
  let decodes = layout.parameters.compactMap { parameter -> String? in
    guard parameter.kind != .context, let value = parameter.decodedValue(from: "context"),
      value.hasPrefix("try ")
    else {
      return nil
    }
    return "_ = \(value)"
  }
  let decode =
    decodes.isEmpty
    ? "{ _ in }"
    : """
    { context throws(RouteValueError) in
      \(decodes.joined(separator: "\n"))
    }
    """

  let registeredParent = registrationParent(parent: parent, topLevelParent: topLevelParent)
  return """
    let \(layout.name) = collection._generatedLayout("\(relativePath(for: layout, under: parent))", parent: \(registeredParent), decode: \(decode))
    """
}

/// Registers a route whose renderer builds the whole typed view tree for its match stack.
///
/// The match stack holds one context per enclosing layout, outermost first, followed by the
/// route's own context. Each layout's values, defaults, and `RouteContext` come from its own
/// context, so a layout never receives a value decoded for the route or another layout.
///
/// A feature's records follow the host's layouts and mount record in the stack, so a feature
/// reads its contexts from the end of the stack and passes the built view to `wrap`.
private func leafRegistration(
  _ route: RouteDeclaration,
  hierarchy: RouteHierarchy,
  isFeature: Bool
) -> String {
  let ancestors = hierarchy.ancestors(ofRoute: route)
  let depth = ancestors.count + 1
  func contextExpression(_ index: Int) -> String {
    isFeature ? "contexts[contexts.count - \(depth - index)]" : "contexts[\(index)]"
  }

  var usesContexts = isFeature
  let leaf = storageValue(
    route,
    context: contextExpression(ancestors.count),
    outlet: nil,
    usesContexts: &usesContexts
  )
  let storage = wrappingLayouts(
    leaf,
    in: ancestors,
    context: contextExpression,
    usesContexts: &usesContexts
  )

  let parameter = usesContexts ? "contexts throws(RouteValueError)" : "_"
  let view = "RouteView(storage: \(storage))"
  let parent = registrationParent(parent: ancestors.last, topLevelParent: isFeature ? "mount" : "nil")
  return """
    let \(route.name) = collection._generatedRoute("\(relativePath(for: route, under: ancestors.last))", parent: \(parent), render: { \(parameter) in
      \(isFeature ? "wrap(\(view), contexts)" : view)
    })
    """
}

/// The storage value of a route or layout, with each value decoded from `context`.
///
/// A layout's outlet parameter receives `outlet`. `usesContexts` is set when a value is read.
private func storageValue(
  _ declaration: RouteDeclaration,
  context: String,
  outlet: String?,
  usesContexts: inout Bool
) -> String {
  var readsContext = false
  let arguments = declaration.parameters.map { parameter in
    guard let value = parameter.decodedValue(from: context) else {
      return "\(parameter.label): \(outlet ?? "")"
    }
    readsContext = true
    return "\(parameter.label): \(value)"
  }
  if readsContext {
    usesContexts = true
  }
  return arguments.isEmpty
    ? ".\(declaration.name)"
    : ".\(declaration.name)(\(arguments.joined(separator: ", ")))"
}

/// Wraps `storage` in the storage values of `ancestors`, from the innermost layout out.
///
/// `context` returns the context expression of the layout at an index of `ancestors`.
private func wrappingLayouts(
  _ storage: String,
  in ancestors: [RouteDeclaration],
  context: (Int) -> String,
  usesContexts: inout Bool
) -> String {
  var storage = storage
  for (index, layout) in ancestors.enumerated().reversed() {
    let outlet = "_RouteOutlet<RouteView.\(outletTypeName(for: layout))>(storage: \(storage))"
    storage = storageValue(layout, context: context(index), outlet: outlet, usesContexts: &usesContexts)
  }
  return storage
}

private func registrationParent(parent: RouteDeclaration?, topLevelParent: String) -> String {
  guard let parent else {
    return topLevelParent
  }
  return parent.name
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
}

extension AttributeSyntax {
  /// The `mode:` argument of a `@Routes` attribute, if any.
  fileprivate var modeArgument: LabeledExprSyntax? {
    guard case .argumentList(let arguments) = arguments else {
      return nil
    }
    return arguments.first { $0.label?.text == "mode" }
  }
}

extension WithAttributesSyntax {
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
  case reservedRouteName(name: String)
  case reservedHashParameter
  case dotSegment(segment: String)
  case multipleOutlets
  case layoutOutletNotGeneric
  case routeOutlet
  case genericRoute
  case unsupportedEffects
  case unlabeledParameter(name: String)
  case duplicateParameterLabel(label: String)
  case duplicateName(name: String)
  case reservedGeneratedName(name: String)
  case outletTypeCollision(name: String, otherName: String, type: String)
  case pathTypeConflict(
    name: String,
    layout: String,
    layoutType: String,
    route: String,
    routeType: String
  )
  case queryTypeConflict(
    name: String,
    firstOwner: String,
    firstType: String,
    secondOwner: String,
    secondType: String
  )
  case queryPathConflict(name: String, owner: String, route: String)
  case featureGenericParameters
  case featureMode
  case featureFallback
  case featureMount
  case mountRequiresStringLiteral
  case mountRequiresFeatureType
  case mountRequiresStaticPath(path: String)
  case mountRequiredLayoutQuery(mount: String, layout: String, query: String)
  case overlappingMount(path: String, otherPath: String)
  case declarationInsideMount(path: String, mount: String, mountPath: String)

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
    case .reservedRouteName(let name):
      "Route name `\(name)` is reserved by the generated `RouteSet`."
    case .reservedHashParameter:
      "Route parameter `hash` conflicts with the generated destination `hash:` argument."
    case .dotSegment(let segment):
      "Route path segment `\(segment)` is a dot segment, which browsers remove from URLs."
    case .multipleOutlets:
      "`@Layout` functions must declare exactly one outlet parameter."
    case .layoutOutletNotGeneric:
      "`@Layout` outlet parameters must have type `Outlet<Content>`, where `Content` is the layout function's only generic parameter."
    case .routeOutlet:
      "`@Route` functions cannot declare an outlet parameter; use `@Layout` to wrap child routes."
    case .genericRoute:
      "`@Route` functions cannot be generic."
    case .unsupportedEffects:
      "`@Route` and `@Layout` functions cannot be `async` or `throws`."
    case .unlabeledParameter(let name):
      "Route parameter `\(name)` must have an argument label."
    case .duplicateParameterLabel(let label):
      "Route parameter label `\(label)` is declared more than once."
    case .duplicateName(let name):
      "Route name `\(name)` is declared more than once; `@Route` and `@Layout` functions need unique names."
    case .reservedGeneratedName(let name):
      "Route name `\(name)` is reserved by generated `@Routes` code."
    case .outletTypeCollision(let name, let otherName, let type):
      "Layouts `\(otherName)` and `\(name)` both generate `RouteView.\(type)`."
    case .pathTypeConflict(let name, let layout, let layoutType, let route, let routeType):
      "Path parameter `\(name)` is declared as `\(layoutType)` by layout `\(layout)` and as `\(routeType)` by route `\(route)`; a route and its layouts must decode it with one type."
    case .queryTypeConflict(let name, let firstOwner, let firstType, let secondOwner, let secondType):
      "Query `\(name)` is declared as `\(firstType)` by `\(firstOwner)` and as `\(secondType)` by `\(secondOwner)`; a route and its layouts share one query value, so they must declare it with one type."
    case .queryPathConflict(let name, let owner, let route):
      "Query `\(name)` of layout `\(owner)` has the same name as a path or wildcard parameter of route `\(route)`, so the route's destination factory cannot take both."
    case .featureGenericParameters:
      "A feature `@Routes` struct must declare exactly one generic parameter for the host route view, such as `<Root: View>`."
    case .featureMode:
      "Features cannot choose a routing mode; the host `@Routes` that mounts the feature owns it."
    case .featureFallback:
      "Features cannot declare `@NotFound` or `@RouteError`; the host `@Routes` that mounts the feature owns fallback policy."
    case .featureMount:
      "Features cannot mount other features; mount every feature in the host `@Routes`."
    case .mountRequiresStringLiteral:
      "`@Mount` requires a string literal path."
    case .mountRequiresFeatureType:
      "`@Mount` type aliases must name a feature specialized with this route set's view, such as `typealias Shop = ShopRoutes<RouteView>`."
    case .mountRequiresStaticPath(let path):
      "Mount path `\(path)` must be static; `:` parameters and `*` wildcards are not supported in mount paths."
    case .mountRequiredLayoutQuery(let mount, let layout, let query):
      "Mount `\(mount)` is wrapped by layout `\(layout)`, whose query `\(query)` has no default; the mounted feature's destinations cannot supply it."
    case .overlappingMount(let path, let otherPath):
      "Mount path `\(path)` overlaps mount path `\(otherPath)`; each mounted feature owns every URL below its path."
    case .declarationInsideMount(let path, let mount, let mountPath):
      "Route path `\(path)` is inside mount `\(mount)` at `\(mountPath)`; the mounted feature owns every URL below its path."
    }
  }

  var diagnosticID: MessageID {
    MessageID(domain: "ElementaryRouterMacros", id: "\(self)")
  }

  var severity: DiagnosticSeverity {
    .error
  }
}
