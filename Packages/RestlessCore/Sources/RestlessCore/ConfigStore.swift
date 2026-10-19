import Foundation
import Observation

@MainActor
@Observable
public final class ConfigStore {
    public let fileURL: URL
    public let selfBundleID: String
    public private(set) var config: Config?
    public private(set) var status: ConfigStatus

    public init(fileURL: URL, selfBundleID: String) {
        self.fileURL = fileURL
        self.selfBundleID = selfBundleID
        self.config = nil
        self.status = .missing
    }

    public func load() {}

    public func reloadIfChanged() {}

    public func save(_ newConfig: Config) throws(ConfigSaveError) {}
}
