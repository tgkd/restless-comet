import Foundation

@MainActor
public final class RequestCoordinator {
    public typealias Routing = (LinkRequest, Config, String) -> RouteDecision

    public init(
        selfBundleID: String,
        config: @escaping @MainActor () -> Config?,
        catalog: any BrowserCataloging,
        opener: any BrowserOpening,
        picker: any PickerPresenting,
        route: @escaping Routing = Router.route
    ) {}

    public var pendingCount: Int {
        0
    }

    public func handle(_ request: LinkRequest) {}
}
