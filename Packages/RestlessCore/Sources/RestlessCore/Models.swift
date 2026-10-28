import Foundation

public struct LinkRequest: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let url: URL
    public let sourceBundleID: String?
    public let alternativeRequested: Bool

    public init(id: UUID = UUID(), url: URL, sourceBundleID: String?, alternativeRequested: Bool) {
        self.id = id
        self.url = url
        if let sourceBundleID, !sourceBundleID.isEmpty {
            self.sourceBundleID = sourceBundleID
        } else {
            self.sourceBundleID = nil
        }
        self.alternativeRequested = alternativeRequested
    }
}

public struct Rule: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var enabled: Bool
    public var domains: [String]
    public var sourceApps: [String]
    public var target: String

    public init(
        id: UUID = UUID(),
        name: String,
        enabled: Bool = true,
        domains: [String] = [],
        sourceApps: [String] = [],
        target: String
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.domains = domains
        self.sourceApps = sourceApps
        self.target = target
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, enabled, domains, sourceApps, target
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        domains = try container.decodeIfPresent([String].self, forKey: .domains) ?? []
        sourceApps = try container.decodeIfPresent([String].self, forKey: .sourceApps) ?? []
        target = try container.decode(String.self, forKey: .target)
    }
}

public struct Config: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1
    public static let initial = Config()

    public var schemaVersion: Int
    public var defaultBrowser: String?
    public var alternativeBrowser: String?
    public var shownBrowsers: [String]
    public var rules: [Rule]
    public var diagnostics: Bool
    public var showMenuBarIcon: Bool

    public init(
        schemaVersion: Int = Config.currentSchemaVersion,
        defaultBrowser: String? = nil,
        alternativeBrowser: String? = nil,
        shownBrowsers: [String] = [],
        rules: [Rule] = [],
        diagnostics: Bool = false,
        showMenuBarIcon: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.defaultBrowser = defaultBrowser
        self.alternativeBrowser = alternativeBrowser
        self.shownBrowsers = shownBrowsers
        self.rules = rules
        self.diagnostics = diagnostics
        self.showMenuBarIcon = showMenuBarIcon
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, defaultBrowser, alternativeBrowser, shownBrowsers, rules, diagnostics, showMenuBarIcon
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        defaultBrowser = try container.decodeIfPresent(String.self, forKey: .defaultBrowser)
        alternativeBrowser = try container.decodeIfPresent(String.self, forKey: .alternativeBrowser)
        shownBrowsers = try container.decodeIfPresent([String].self, forKey: .shownBrowsers) ?? []
        rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        diagnostics = try container.decodeIfPresent(Bool.self, forKey: .diagnostics) ?? false
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(defaultBrowser, forKey: .defaultBrowser)
        try container.encode(alternativeBrowser, forKey: .alternativeBrowser)
        try container.encode(shownBrowsers, forKey: .shownBrowsers)
        try container.encode(rules, forKey: .rules)
        try container.encode(diagnostics, forKey: .diagnostics)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
    }
}

public struct BrowserApp: Sendable, Hashable, Identifiable {
    public let bundleID: String
    public let name: String
    public let appURL: URL

    public var id: String {
        bundleID
    }

    public init(bundleID: String, name: String, appURL: URL) {
        self.bundleID = bundleID
        self.name = name
        self.appURL = appURL
    }
}

public enum RouteReason: Sendable, Equatable {
    case alternative
    case rule(UUID)
    case defaultBrowser
}

public enum RouteDecision: Sendable, Equatable {
    case open(bundleID: String, reason: RouteReason)
    case prompt
}

public enum ConfigIssue: Error, Sendable, Equatable {
    case unreadable(String)
    case unsupportedSchema(Int)
    case invalid([String])
}

public enum ConfigStatus: Sendable, Equatable {
    case missing
    case loaded
    case invalid(ConfigIssue)
}

public enum ConfigSaveError: Error, Sendable, Equatable {
    case fileInvalid
    case changedExternally
    case invalid(ConfigIssue)
    case writeFailed(String)
}
