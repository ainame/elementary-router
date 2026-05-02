#if canImport(JavaScriptKit)
import JavaScriptKit
#endif

public final class BrowserHistory: RouterHistory {
    private var fallback = MemoryHistory()

    #if canImport(JavaScriptKit)
    private var popStateClosure: JSClosure?
    #endif

    public init() {}

    public var location: RouteLocation {
        #if canImport(JavaScriptKit)
        guard let location = JSObject.global.location.object else {
            return fallback.location
        }
        let path = location.pathname.string ?? "/"
        let query = location.search.string ?? ""
        let hash = location["hash"].string ?? ""
        return RouteLocation(path: path, queryString: query, hash: hash)
        #else
        fallback.location
        #endif
    }

    public func push(_ location: RouteLocation) {
        #if canImport(JavaScriptKit)
        guard let history = JSObject.global.history.object else {
            fallback.push(location)
            return
        }
        _ = history["pushState"].function?.callAsFunction(
            this: history,
            JSValue.null,
            "",
            location.href
        )
        #else
        fallback.push(location)
        #endif
    }

    public func replace(_ location: RouteLocation) {
        #if canImport(JavaScriptKit)
        guard let history = JSObject.global.history.object else {
            fallback.replace(location)
            return
        }
        _ = history["replaceState"].function?.callAsFunction(
            this: history,
            JSValue.null,
            "",
            location.href
        )
        #else
        fallback.replace(location)
        #endif
    }

    public func go(_ delta: Int) {
        #if canImport(JavaScriptKit)
        guard let history = JSObject.global.history.object else {
            fallback.go(delta)
            return
        }
        _ = history["go"].function?.callAsFunction(this: history, delta)
        #else
        fallback.go(delta)
        #endif
    }

    public func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription {
        #if canImport(JavaScriptKit)
        let closure = JSClosure { _ in
            listener(HistoryUpdate(action: .pop, location: self.location))
            return .undefined
        }
        popStateClosure = closure
        _ = JSObject.global["addEventListener"].function?.callAsFunction(
            this: JSObject.global,
            "popstate",
            closure
        )
        return HistorySubscription {
            if let closure = self.popStateClosure {
                _ = JSObject.global["removeEventListener"].function?.callAsFunction(
                    this: JSObject.global,
                    "popstate",
                    closure
                )
            }
            self.popStateClosure = nil
        }
        #else
        fallback.listen(listener)
        #endif
    }
}
