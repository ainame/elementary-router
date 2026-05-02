public enum HistoryAction: Equatable, Sendable {
    case push
    case replace
    case pop
}

public struct HistoryUpdate: Equatable, Sendable {
    public let action: HistoryAction
    public let location: RouteLocation

    public init(action: HistoryAction, location: RouteLocation) {
        self.action = action
        self.location = location
    }
}

public final class HistorySubscription {
    private var cancelBody: (() -> Void)?

    init(_ cancelBody: @escaping () -> Void) {
        self.cancelBody = cancelBody
    }

    public func cancel() {
        cancelBody?()
        cancelBody = nil
    }
}

public protocol RouterHistory: AnyObject {
    var location: RouteLocation { get }
    func push(_ location: RouteLocation)
    func replace(_ location: RouteLocation)
    func go(_ delta: Int)
    func listen(_ listener: @escaping (HistoryUpdate) -> Void) -> HistorySubscription
}

public extension RouterHistory where Self == MemoryHistory {
    static func memory(initialPath: String = "/") -> MemoryHistory {
        MemoryHistory(initialPath: initialPath)
    }
}

public extension RouterHistory where Self == BrowserHistory {
    static func browser() -> BrowserHistory {
        BrowserHistory()
    }
}

public extension RouterHistory where Self == HashHistory {
    static func hash() -> HashHistory {
        HashHistory()
    }
}
