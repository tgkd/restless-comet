import Foundation
import Testing
@testable import RestlessCore

struct ContractTests {
    @Test func initialConfigRoundTrips() throws {
        let data = try JSONEncoder().encode(Config.initial)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded == Config.initial)
    }

    @Test func unsetBrowsersAreWrittenAsNull() throws {
        let data = try JSONEncoder().encode(Config.initial)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"defaultBrowser\":null"))
        #expect(text.contains("\"alternativeBrowser\":null"))
    }

    @Test func ruleFillsMissingKeysWithDefaults() throws {
        let json = #"{"target":"com.apple.Safari"}"#
        let rule = try JSONDecoder().decode(Rule.self, from: Data(json.utf8))
        #expect(rule.enabled)
        #expect(rule.name.isEmpty)
        #expect(rule.domains.isEmpty)
        #expect(rule.sourceApps.isEmpty)
    }

    @Test func menuBarIconIsShownWhenTheKeyIsMissing() throws {
        let json = #"{"schemaVersion":1}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        #expect(config.showMenuBarIcon)
    }

    @Test func hiddenMenuBarIconRoundTrips() throws {
        let hidden = Config(showMenuBarIcon: false)
        let data = try JSONEncoder().encode(hidden)
        #expect(try JSONDecoder().decode(Config.self, from: data) == hidden)
    }

    @Test func configRequiresSchemaVersion() {
        let json = #"{"rules":[]}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        }
    }

    @Test func blankSourceBundleIDIsUnknown() throws {
        let url = try #require(URL(string: "https://example.com"))
        let request = LinkRequest(url: url, sourceBundleID: "", alternativeRequested: false)
        #expect(request.sourceBundleID == nil)
    }
}
