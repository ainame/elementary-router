import ElementaryUI

public final class RouteCollection {
    private var records: [RouteRecordBuilder] = []
    private var notFoundRenderer: ((RouteNotFoundContext) -> Void)?
    private var errorRenderer: ((RouteErrorContext) -> Void)?
    private var nextID = 0

    public init() {}

    @discardableResult
    public func route<Content: View>(
        _ path: String,
        @HTMLBuilder render: @escaping () -> Content
    ) -> RouteHandle {
        let erased: (RouteContext) throws(RouteValueError) -> Void = { _ throws(RouteValueError) in
            _ = render()
        }
        return add(path: path, render: erased)
    }

    @discardableResult
    public func route<Content: View>(
        _ path: String,
        @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> Content
    ) -> RouteHandle {
        let erased: (RouteContext) throws(RouteValueError) -> Void = { context throws(RouteValueError) in
            _ = try render(context)
        }
        return add(path: path, render: erased)
    }

    public func scope(_ path: String) -> RouteScope {
        RouteScope(collection: self, prefix: path)
    }

    public func notFound<Content: View>(
        @HTMLBuilder render: @escaping (RouteNotFoundContext) -> Content
    ) {
        notFoundRenderer = { context in _ = render(context) }
    }

    public func error<Content: View>(
        @HTMLBuilder render: @escaping (RouteErrorContext) -> Content
    ) {
        errorRenderer = { context in _ = render(context) }
    }

    public func freeze() throws(RouteTreeError) -> RouteTree {
        var compiled: [CompiledRouteRecord] = []
        var seenPaths: [String] = []

        for record in records {
            let pattern = try RoutePattern(record.path)
            if seenPaths.contains(pattern.path) {
                throw RouteTreeError.duplicateRoute(path: pattern.path)
            }
            seenPaths.append(pattern.path)
            compiled.append(
                CompiledRouteRecord(
                    handle: record.handle,
                    pattern: pattern,
                    render: record.render
                )
            )
        }

        compiled.sort {
            if $0.pattern.specificity == $1.pattern.specificity {
                $0.handle.id.rawValue < $1.handle.id.rawValue
            } else {
                $0.pattern.specificity > $1.pattern.specificity
            }
        }

        return RouteTree(
            records: compiled,
            notFoundRenderer: notFoundRenderer,
            errorRenderer: errorRenderer
        )
    }

    @discardableResult
    fileprivate func add(path: String, render: @escaping (RouteContext) throws(RouteValueError) -> Void) -> RouteHandle {
        let handle = RouteHandle(id: RouteID(rawValue: nextID))
        nextID += 1
        records.append(RouteRecordBuilder(handle: handle, path: path, render: render))
        return handle
    }
}

public final class RouteScope {
    private let collection: RouteCollection
    private let prefix: String

    fileprivate init(collection: RouteCollection, prefix: String) {
        self.collection = collection
        self.prefix = RouteLocation.normalizedPath(prefix)
    }

    @discardableResult
    public func route<Content: View>(
        _ path: String,
        @HTMLBuilder render: @escaping () -> Content
    ) -> RouteHandle {
        let erased: (RouteContext) throws(RouteValueError) -> Void = { _ throws(RouteValueError) in
            _ = render()
        }
        return collection.add(path: joined(path), render: erased)
    }

    @discardableResult
    public func route<Content: View>(
        _ path: String,
        @HTMLBuilder render: @escaping (RouteContext) throws(RouteValueError) -> Content
    ) -> RouteHandle {
        let erased: (RouteContext) throws(RouteValueError) -> Void = { context throws(RouteValueError) in
            _ = try render(context)
        }
        return collection.add(path: joined(path), render: erased)
    }

    public func scope(_ path: String) -> RouteScope {
        RouteScope(collection: collection, prefix: joined(path))
    }

    private func joined(_ path: String) -> String {
        if path == "/" || path.isEmpty { return prefix }
        let child = path.first == "/" ? String(path.dropFirst()) : path
        if prefix == "/" { return "/" + child }
        return prefix + "/" + child
    }
}

private struct RouteRecordBuilder {
    let handle: RouteHandle
    let path: String
    let render: (RouteContext) throws(RouteValueError) -> Void
}

struct CompiledRouteRecord {
    let handle: RouteHandle
    let pattern: RoutePattern
    let render: (RouteContext) throws(RouteValueError) -> Void
}
