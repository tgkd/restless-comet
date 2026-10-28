import Foundation
import Testing
@testable import RestlessCore

@MainActor
final class ConfigStoreTests {
    private static let selfID = "com.restlesscomet.app"
    private static let slackRuleID = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    private static let youTubeRuleID = "0F2A5C58-6D63-4E8B-9B7B-0B4E1C9B8A11"

    private static let goodJSON = """
        {
          "schemaVersion": 1,
          "defaultBrowser": null,
          "alternativeBrowser": "com.google.Chrome",
          "shownBrowsers": ["com.apple.Safari", "com.google.Chrome", "com.apple.Safari"],
          "rules": [
            {
              "id": "\(slackRuleID)",
              "name": "Slack backoffice",
              "domains": ["Backoffice.Example.com."],
              "sourceApps": ["com.tinyspeck.slackmacgap"],
              "target": "com.google.Chrome"
            },
            {
              "id": "\(youTubeRuleID)",
              "name": "YouTube",
              "domains": ["youtube.com"],
              "target": "com.apple.Safari"
            }
          ]
        }
        """

    private static let editedJSON = """
        {"schemaVersion": 1, "defaultBrowser": "com.apple.Safari", "rules": []}
        """

    private static let editedConfig = Config(defaultBrowser: "com.apple.Safari")

    private static let brokenJSON = """
        {
          "schemaVersion": 1,
          "rules": [
            {"name": "half written",
        """

    private static let futureJSON = """
        {"schemaVersion": 2, "profiles": {"work": "com.google.Chrome"}, "rules": "moved to profiles"}
        """

    private static let selfAsDefaultJSON = """
        {"schemaVersion": 1, "defaultBrowser": "com.restlesscomet.app"}
        """

    private let directory: URL
    private let fileURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "RestlessCoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory
            .appending(path: "Application Support", directoryHint: .isDirectory)
            .appending(path: Self.selfID, directoryHint: .isDirectory)
            .appending(path: "config.json", directoryHint: .notDirectory)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func missingFileGivesTheInitialConfig() {
        let store = makeStore()
        store.load()
        #expect(store.config == Config.initial)
        #expect(store.status == .missing)
        #expect(!fileExists)
    }

    @Test func validFileIsLoadedCanonicalized() throws {
        try writeFile(Self.goodJSON, modifiedAt: 1_000_000)
        let before = try fileBytes()
        let expected = try goodConfig()
        let store = makeStore()
        store.load()
        #expect(store.status == .loaded)
        #expect(store.config == expected)
        #expect(try fileBytes() == before)
    }

    @Test func brokenJSONAtColdStartLeavesNoConfigAndTheFileUntouched() throws {
        try writeFile(Self.brokenJSON, modifiedAt: 1_000_000)
        let before = try fileBytes()
        let store = makeStore()
        store.load()
        #expect(store.config == nil)
        #expect(isUnreadable(store.status))

        store.reloadIfChanged()
        #expect(store.config == nil)
        #expect(throws: ConfigSaveError.fileInvalid) {
            try store.save(Config.initial)
        }
        #expect(try fileBytes() == before)
    }

    @Test func invalidConfigAtColdStartLeavesNoConfig() throws {
        try writeFile(Self.selfAsDefaultJSON, modifiedAt: 1_000_000)
        let before = try fileBytes()
        let store = makeStore()
        store.load()
        #expect(store.config == nil)
        guard case .invalid(.invalid(let problems)) = store.status else {
            Issue.record("expected an invalid status, got \(store.status)")
            return
        }
        #expect(problems.count == 1)
        #expect(try fileBytes() == before)
    }

    @Test func unreadableFileAtColdStartIsInvalid() throws {
        try writeFile(Self.goodJSON, modifiedAt: 1_000_000)
        let path = fileURL.path(percentEncoded: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path)
        }
        if FileManager.default.isReadableFile(atPath: path) {
            return
        }
        let store = makeStore()
        store.load()
        #expect(store.config == nil)
        #expect(isUnreadable(store.status))
    }

    @Test func externalValidEditIsSwappedIn() throws {
        try writeFile(Self.goodJSON, modifiedAt: 1_000_000)
        let store = makeStore()
        store.load()

        try writeFile(Self.editedJSON, modifiedAt: 2_000_000)
        store.reloadIfChanged()
        #expect(store.status == .loaded)
        #expect(store.config == Self.editedConfig)
    }

    @Test func externalBrokenEditKeepsTheLastGoodConfig() throws {
        try writeFile(Self.goodJSON, modifiedAt: 1_000_000)
        let expected = try goodConfig()
        let store = makeStore()
        store.load()

        try writeFile(Self.brokenJSON, modifiedAt: 2_000_000)
        let broken = try fileBytes()
        store.reloadIfChanged()
        #expect(store.config == expected)
        #expect(isUnreadable(store.status))
        #expect(try fileBytes() == broken)
    }

    @Test func fixingTheFileRecovers() throws {
        try writeFile(Self.goodJSON, modifiedAt: 1_000_000)
        let store = makeStore()
        store.load()

        try writeFile(Self.brokenJSON, modifiedAt: 2_000_000)
        store.reloadIfChanged()
        #expect(isUnreadable(store.status))

        try writeFile(Self.editedJSON, modifiedAt: 3_000_000)
        store.reloadIfChanged()
        #expect(store.status == .loaded)
        #expect(store.config == Self.editedConfig)
    }

    @Test func unknownSchemaAtColdStartIsPreservedAndNeverOverwritten() throws {
        try writeFile(Self.futureJSON, modifiedAt: 1_000_000)
        let before = try fileBytes()
        let store = makeStore()
        store.load()
        #expect(store.config == nil)
        #expect(store.status == .invalid(.unsupportedSchema(2)))

        #expect(throws: ConfigSaveError.fileInvalid) {
            try store.save(Config.initial)
        }
        #expect(try fileBytes() == before)
    }

    @Test func unknownSchemaAfterAGoodLoadKeepsTheGoodConfigAndRefusesSaves() throws {
        try writeFile(Self.goodJSON, modifiedAt: 1_000_000)
        let expected = try goodConfig()
        let store = makeStore()
        store.load()

        try writeFile(Self.futureJSON, modifiedAt: 2_000_000)
        let future = try fileBytes()
        store.reloadIfChanged()
        #expect(store.config == expected)
        #expect(store.status == .invalid(.unsupportedSchema(2)))

        #expect(throws: ConfigSaveError.fileInvalid) {
            try store.save(expected)
        }
        #expect(try fileBytes() == future)
    }

    @Test func saveRefusesWhenTheFileChangedSinceItWasLastSeen() throws {
        try writeFile(Self.goodJSON, modifiedAt: 1_000_000)
        let store = makeStore()
        store.load()

        try writeFile(Self.editedJSON, modifiedAt: 2_000_000)
        let external = try fileBytes()
        let mine = Config(defaultBrowser: "org.mozilla.firefox")
        #expect(throws: ConfigSaveError.changedExternally) {
            try store.save(mine)
        }
        #expect(store.config == Self.editedConfig)
        #expect(store.status == .loaded)
        #expect(try fileBytes() == external)

        try store.save(mine)
        #expect(store.config == mine)
        #expect(store.status == .loaded)
    }

    @Test func saveRejectsAnInvalidConfig() throws {
        let store = makeStore()
        store.load()
        let invalid = Config(rules: [Rule(name: "Loop", domains: ["x.com"], target: Self.selfID)])
        let error = #expect(throws: ConfigSaveError.self) {
            try store.save(invalid)
        }
        guard case .invalid(.invalid(let problems)) = error else {
            Issue.record("expected .invalid(.invalid), got \(String(describing: error))")
            return
        }
        #expect(problems.count == 1)
        #expect(store.config == Config.initial)
        #expect(store.status == .missing)
        #expect(!fileExists)
    }

    @Test func saveRejectsAnUnsupportedSchemaVersion() {
        let store = makeStore()
        store.load()
        #expect(throws: ConfigSaveError.invalid(.unsupportedSchema(7))) {
            try store.save(Config(schemaVersion: 7))
        }
        #expect(!fileExists)
    }

    @Test func saveWritesPrettySortedJSONThatRoundTrips() throws {
        let store = makeStore()
        store.load()
        let rule = Rule(
            name: "Work/Slack",
            domains: ["Backoffice.Example.com."],
            sourceApps: ["com.tinyspeck.slackmacgap"],
            target: "com.google.Chrome"
        )
        let config = Config(shownBrowsers: ["com.apple.Safari", "com.google.Chrome"], rules: [rule])
        try store.save(config)

        var canonicalRule = rule
        canonicalRule.domains = ["backoffice.example.com"]
        var canonical = config
        canonical.rules = [canonicalRule]
        #expect(store.config == canonical)
        #expect(store.status == .loaded)

        let data = try fileBytes()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\n  \"alternativeBrowser\""))
        #expect(text.contains("Work/Slack"))
        #expect(!text.contains("\\/"))
        #expect(text.hasSuffix("}\n"))

        let topLevelKeys = [
            "alternativeBrowser", "defaultBrowser", "diagnostics", "rules", "schemaVersion", "showMenuBarIcon",
            "shownBrowsers",
        ]
        let offsets = topLevelKeys.compactMap { text.range(of: "\"\($0)\"")?.lowerBound }
        #expect(offsets.count == topLevelKeys.count)
        #expect(offsets == offsets.sorted())

        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["defaultBrowser"] is NSNull)
        #expect(object["alternativeBrowser"] is NSNull)

        #expect(try JSONDecoder().decode(Config.self, from: data) == canonical)

        let freshStore = makeStore()
        freshStore.load()
        #expect(freshStore.status == .loaded)
        #expect(freshStore.config == canonical)
    }

    @Test func consecutiveSavesDoNotTripChangeDetection() throws {
        let store = makeStore()
        store.load()
        try store.save(Config(defaultBrowser: "com.apple.Safari"))
        try store.save(Config(defaultBrowser: "com.google.Chrome"))
        #expect(store.config?.defaultBrowser == "com.google.Chrome")

        store.reloadIfChanged()
        #expect(store.status == .loaded)
        #expect(store.config?.defaultBrowser == "com.google.Chrome")
    }

    @Test func deletedFileKeepsTheLastGoodConfig() throws {
        try writeFile(Self.goodJSON, modifiedAt: 1_000_000)
        let expected = try goodConfig()
        let store = makeStore()
        store.load()

        try FileManager.default.removeItem(at: fileURL)
        store.reloadIfChanged()
        #expect(store.config == expected)
        #expect(store.status == .missing)

        try store.save(expected)
        #expect(fileExists)
        #expect(store.status == .loaded)
    }

    @Test func unchangedModificationStampSkipsTheReparse() throws {
        try writeFile(#"{"schemaVersion": 1, "defaultBrowser": "com.example.aaaa"}"#, modifiedAt: 1_000_000)
        let store = makeStore()
        store.load()
        #expect(store.config?.defaultBrowser == "com.example.aaaa")

        try writeFile(#"{"schemaVersion": 1, "defaultBrowser": "com.example.bbbb"}"#, modifiedAt: 1_000_000)
        store.reloadIfChanged()
        #expect(store.config?.defaultBrowser == "com.example.aaaa")

        try setModificationDate(2_000_000)
        store.reloadIfChanged()
        #expect(store.config?.defaultBrowser == "com.example.bbbb")
    }

    private func makeStore() -> ConfigStore {
        ConfigStore(fileURL: fileURL, selfBundleID: Self.selfID)
    }

    private func goodConfig() throws -> Config {
        Config(
            alternativeBrowser: "com.google.Chrome",
            shownBrowsers: ["com.apple.Safari", "com.google.Chrome"],
            rules: [
                Rule(
                    id: try #require(UUID(uuidString: Self.slackRuleID)),
                    name: "Slack backoffice",
                    domains: ["backoffice.example.com"],
                    sourceApps: ["com.tinyspeck.slackmacgap"],
                    target: "com.google.Chrome"
                ),
                Rule(
                    id: try #require(UUID(uuidString: Self.youTubeRuleID)),
                    name: "YouTube",
                    domains: ["youtube.com"],
                    target: "com.apple.Safari"
                ),
            ]
        )
    }

    private func writeFile(_ text: String, modifiedAt secondsSince1970: TimeInterval) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: fileURL)
        try setModificationDate(secondsSince1970)
    }

    private func setModificationDate(_ secondsSince1970: TimeInterval) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: secondsSince1970)],
            ofItemAtPath: fileURL.path(percentEncoded: false)
        )
    }

    private func fileBytes() throws -> Data {
        try Data(contentsOf: fileURL)
    }

    private var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false))
    }

    private func isUnreadable(_ status: ConfigStatus) -> Bool {
        if case .invalid(.unreadable) = status {
            return true
        }
        return false
    }
}
