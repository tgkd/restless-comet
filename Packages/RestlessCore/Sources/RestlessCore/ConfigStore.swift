import Foundation
import Observation

@MainActor
@Observable
public final class ConfigStore {
    public let fileURL: URL
    public let selfBundleID: String
    public private(set) var config: Config?
    public private(set) var status: ConfigStatus

    @ObservationIgnored private var lastSeenFile: FileSnapshot?

    public init(fileURL: URL, selfBundleID: String) {
        self.fileURL = fileURL
        self.selfBundleID = selfBundleID
        self.config = nil
        self.status = .missing
    }

    public func load() {
        reload(observing: currentSnapshot())
    }

    public func reloadIfChanged() {
        let snapshot = currentSnapshot()
        if snapshot != lastSeenFile {
            reload(observing: snapshot)
        }
    }

    public func save(_ newConfig: Config) throws(ConfigSaveError) {
        let snapshot = currentSnapshot()
        if snapshot != lastSeenFile {
            reload(observing: snapshot)
            throw ConfigSaveError.changedExternally
        }
        if case .invalid = status {
            throw ConfigSaveError.fileInvalid
        }
        let validated: Config
        switch ConfigValidator.validate(newConfig, selfBundleID: selfBundleID) {
        case .success(let canonical):
            validated = canonical
        case .failure(let issue):
            throw ConfigSaveError.invalid(issue)
        }
        try write(validated)
        lastSeenFile = currentSnapshot()
        apply(config: validated, status: .loaded)
    }

    private var resolvedFileURL: URL {
        fileURL.resolvingSymlinksInPath()
    }

    private func reload(observing snapshot: FileSnapshot) {
        lastSeenFile = snapshot
        switch snapshot {
        case .absent:
            apply(config: config ?? .initial, status: .missing)
        case .inaccessible(let reason):
            apply(config: config, status: .invalid(.unreadable(reason)))
        case .present:
            switch readCandidate() {
            case .success(let candidate):
                apply(config: candidate, status: .loaded)
            case .failure(let issue):
                apply(config: config, status: .invalid(issue))
            }
        }
    }

    private func apply(config newConfig: Config?, status newStatus: ConfigStatus) {
        if config != newConfig {
            config = newConfig
        }
        if status != newStatus {
            status = newStatus
        }
    }

    private func currentSnapshot() -> FileSnapshot {
        do {
            let attributes = try FileManager.default.attributesOfItem(
                atPath: resolvedFileURL.path(percentEncoded: false)
            )
            return .present(
                modificationDate: attributes[.modificationDate] as? Date,
                size: (attributes[.size] as? NSNumber)?.uint64Value,
                fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
            )
        } catch {
            if Self.isNoSuchFile(error) {
                return .absent
            }
            return .inaccessible(error.localizedDescription)
        }
    }

    private func readCandidate() -> Result<Config, ConfigIssue> {
        let data: Data
        do {
            data = try Data(contentsOf: resolvedFileURL)
        } catch {
            return .failure(.unreadable(error.localizedDescription))
        }
        let decoder = JSONDecoder()
        let declaredVersion: Int
        do {
            declaredVersion = try decoder.decode(SchemaVersionProbe.self, from: data).schemaVersion
        } catch {
            return .failure(.unreadable(Self.describeDecodingFailure(error)))
        }
        if declaredVersion != Config.currentSchemaVersion {
            return .failure(.unsupportedSchema(declaredVersion))
        }
        let decoded: Config
        do {
            decoded = try decoder.decode(Config.self, from: data)
        } catch {
            return .failure(.unreadable(Self.describeDecodingFailure(error)))
        }
        return ConfigValidator.validate(decoded, selfBundleID: selfBundleID)
    }

    private func write(_ config: Config) throws(ConfigSaveError) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let destination = resolvedFileURL
        do {
            var data = try encoder.encode(config)
            data.append(contentsOf: "\n".utf8)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: destination, options: .atomic)
        } catch {
            throw ConfigSaveError.writeFailed(error.localizedDescription)
        }
    }

    private static func isNoSuchFile(_ error: any Error) -> Bool {
        if let cocoaError = error as? CocoaError,
           cocoaError.code == .fileReadNoSuchFile || cocoaError.code == .fileNoSuchFile {
            return true
        }
        if let posixError = error as? POSIXError, posixError.code == .ENOENT {
            return true
        }
        return false
    }

    private static func describeDecodingFailure(_ error: any Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        switch decodingError {
        case .dataCorrupted(let context):
            if let underlying = context.underlyingError,
               let detail = (underlying as NSError).userInfo[NSDebugDescriptionErrorKey] as? String {
                return located("Not valid JSON: \(detail)", at: context.codingPath)
            }
            return located(context.debugDescription, at: context.codingPath)
        case .keyNotFound(let key, let context):
            return located("Missing required key \"\(key.stringValue)\".", at: context.codingPath)
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return located(context.debugDescription, at: context.codingPath)
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    private static func located(_ message: String, at codingPath: [any CodingKey]) -> String {
        var path = ""
        for key in codingPath {
            if let index = key.intValue {
                path += "[\(index)]"
            } else if path.isEmpty {
                path = key.stringValue
            } else {
                path += ".\(key.stringValue)"
            }
        }
        return path.isEmpty ? message : "\(path): \(message)"
    }
}

private enum FileSnapshot: Equatable {
    case absent
    case present(modificationDate: Date?, size: UInt64?, fileNumber: UInt64?)
    case inaccessible(String)
}

private struct SchemaVersionProbe: Decodable {
    let schemaVersion: Int
}
