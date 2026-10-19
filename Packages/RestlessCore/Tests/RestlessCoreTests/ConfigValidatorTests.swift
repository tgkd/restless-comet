import Foundation
import Testing
@testable import RestlessCore

struct ConfigValidatorTests {
    private let selfID = "com.restlesscomet.app"
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"
    private let slack = "com.tinyspeck.slackmacgap"

    @Test func initialConfigIsValid() {
        #expect(validate(Config.initial) == .success(Config.initial))
    }

    @Test func validConfigIsCanonicalized() {
        let rule = Rule(
            name: "Work",
            enabled: false,
            domains: ["Blog.X.COM.", "bücher.de", "[2001:DB8::1]"],
            sourceApps: [slack],
            target: chrome
        )
        let config = Config(
            defaultBrowser: safari,
            alternativeBrowser: chrome,
            shownBrowsers: [safari, chrome],
            rules: [rule],
            diagnostics: true
        )
        var expectedRule = rule
        expectedRule.domains = ["blog.x.com", "xn--bcher-kva.de", "2001:db8::1"]
        var expected = config
        expected.rules = [expectedRule]
        #expect(validate(config) == .success(expected))
    }

    @Test func shownBrowsersAreDedupedInOrder() {
        let config = Config(shownBrowsers: [chrome, safari, chrome, "org.mozilla.firefox", safari])
        var expected = config
        expected.shownBrowsers = [chrome, safari, "org.mozilla.firefox"]
        #expect(validate(config) == .success(expected))
    }

    @Test func canonicalizationIsIdempotent() throws {
        let config = Config(
            shownBrowsers: [chrome, chrome],
            rules: [Rule(name: "x", domains: ["X.com.", "BÜCHER.de"], target: safari)]
        )
        let once = try validate(config).get()
        #expect(validate(once) == .success(once))
    }

    @Test(arguments: [0, 2, 99])
    func unsupportedSchemaIsReportedBeforeAnythingElse(version: Int) {
        let config = Config(
            schemaVersion: version,
            defaultBrowser: "com.restlesscomet.app",
            rules: [Rule(name: "broken", target: "")]
        )
        #expect(validate(config) == .failure(.unsupportedSchema(version)))
    }

    @Test func selfAsDefaultBrowserIsRejected() {
        let problems = messages(validate(Config(defaultBrowser: selfID)))
        #expect(problems.count == 1)
        #expect(problems.first?.contains("defaultBrowser") == true)
        #expect(problems.first?.contains(selfID) == true)
    }

    @Test func selfAsAlternativeBrowserIsRejected() {
        let problems = messages(validate(Config(alternativeBrowser: selfID)))
        #expect(problems.count == 1)
        #expect(problems.first?.contains("alternativeBrowser") == true)
    }

    @Test func selfInShownBrowsersIsRejected() {
        let problems = messages(validate(Config(shownBrowsers: [safari, selfID])))
        #expect(problems.count == 1)
        #expect(problems.first?.contains("shownBrowsers[1]") == true)
    }

    @Test func selfAsRuleTargetIsRejected() {
        let config = Config(rules: [Rule(name: "Loop", domains: ["x.com"], target: selfID)])
        let problems = messages(validate(config))
        #expect(problems.count == 1)
        #expect(problems.first?.contains("rules[0] \"Loop\"") == true)
        #expect(problems.first?.contains("target") == true)
    }

    @Test func selfInEveryFieldIsReportedTogether() {
        let config = Config(
            defaultBrowser: selfID,
            alternativeBrowser: selfID,
            shownBrowsers: [selfID],
            rules: [Rule(name: "Loop", domains: ["x.com"], target: selfID)]
        )
        let problems = messages(validate(config))
        #expect(problems.count == 4)
        for field in ["defaultBrowser", "alternativeBrowser", "shownBrowsers[0]", "rules[0]"] {
            #expect(problems.contains(where: { $0.contains(field) }), "no message names \(field)")
        }
    }

    @Test(arguments: ["", "   "])
    func emptyRuleTargetIsRejected(target: String) {
        let config = Config(rules: [Rule(name: "Nowhere", domains: ["x.com"], target: target)])
        let problems = messages(validate(config))
        #expect(problems.count == 1)
        #expect(problems.first?.contains("rules[0] \"Nowhere\"") == true)
        #expect(problems.first?.contains("target is empty") == true)
    }

    @Test func ruleWithBothListsEmptyIsRejected() {
        let config = Config(rules: [Rule(name: "Everything", target: chrome)])
        let problems = messages(validate(config))
        #expect(problems.count == 1)
        #expect(problems.first?.contains("rules[0] \"Everything\"") == true)
        #expect(problems.first?.contains("domains and sourceApps are both empty") == true)
    }

    @Test(arguments: [
        "https://x.com",
        "x.com/path",
        "x.com:443",
        "x .com",
        " x.com",
        "x..com",
        ".x.com",
        "",
        "*.x.com",
    ])
    func nonBareDomainIsRejected(domain: String) {
        let config = Config(rules: [Rule(name: "Bad domain", domains: ["ok.com", domain], target: chrome)])
        let problems = messages(validate(config))
        #expect(problems.count == 1)
        #expect(problems.first?.contains("rules[0] \"Bad domain\": domains[1]") == true)
        #expect(problems.first?.contains("\"\(domain)\"") == true)
    }

    @Test(arguments: ["", "  "])
    func emptySourceAppIsRejected(sourceApp: String) {
        let config = Config(rules: [Rule(name: "Blank source", sourceApps: [slack, sourceApp], target: chrome)])
        let problems = messages(validate(config))
        #expect(problems.count == 1)
        #expect(problems.first?.contains("rules[0] \"Blank source\": sourceApps[1]") == true)
    }

    @Test func unnamedRuleIsNamedByIndex() {
        let config = Config(rules: [
            Rule(name: "Fine", domains: ["x.com"], target: chrome),
            Rule(name: "", domains: ["y.com"], target: ""),
        ])
        let problems = messages(validate(config))
        #expect(problems == ["rules[1]: target is empty; set it to a browser's bundle id."])
    }

    @Test func disabledRulesAreValidatedToo() {
        let config = Config(rules: [Rule(name: "Off", enabled: false, domains: ["https://x.com"], target: selfID)])
        #expect(messages(validate(config)).count == 2)
    }

    @Test func everyProblemIsReported() {
        let config = Config(
            defaultBrowser: selfID,
            rules: [
                Rule(name: "A", target: ""),
                Rule(name: "B", domains: ["x.com/a", "y.com:1"], sourceApps: [""], target: chrome),
            ]
        )
        let problems = messages(validate(config))
        #expect(problems.count == 6)
        #expect(problems.first?.hasPrefix("defaultBrowser") == true)
        #expect(problems.filter { $0.hasPrefix("rules[0] \"A\"") }.count == 2)
        #expect(problems.filter { $0.hasPrefix("rules[1] \"B\"") }.count == 3)
    }

    private func validate(_ config: Config) -> Result<Config, ConfigIssue> {
        ConfigValidator.validate(config, selfBundleID: selfID)
    }

    private func messages(_ result: Result<Config, ConfigIssue>) -> [String] {
        guard case .failure(.invalid(let messages)) = result else {
            Issue.record("expected .invalid, got \(result)")
            return []
        }
        return messages
    }
}
