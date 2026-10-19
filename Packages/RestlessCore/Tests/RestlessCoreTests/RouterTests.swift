import Foundation
import Testing
@testable import RestlessCore

struct RouterTests {
    private let selfID = "com.restlesscomet.app"
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"
    private let firefox = "org.mozilla.firefox"
    private let slack = "com.tinyspeck.slackmacgap"
    private let mail = "com.apple.mail"

    @Test func alternativeWinsWhenRequestedAndSet() throws {
        let rule = Rule(name: "x", domains: ["x.com"], target: safari)
        let config = Config(defaultBrowser: firefox, alternativeBrowser: chrome, rules: [rule])
        let decision = try route("https://x.com/", alternative: true, in: config)
        #expect(decision == .open(bundleID: chrome, reason: .alternative))
    }

    @Test func alternativeIsIgnoredWhenNotRequested() throws {
        let config = Config(defaultBrowser: firefox, alternativeBrowser: chrome)
        #expect(try route("https://x.com/", in: config) == .open(bundleID: firefox, reason: .defaultBrowser))
    }

    @Test func alternativeRequestedWithoutAlternativeGoesOnToTheRules() throws {
        let rule = Rule(name: "x", domains: ["x.com"], target: safari)
        let config = Config(defaultBrowser: firefox, alternativeBrowser: nil, rules: [rule])
        let matched = RouteDecision.open(bundleID: safari, reason: .rule(rule.id))
        let fallback = RouteDecision.open(bundleID: firefox, reason: .defaultBrowser)
        #expect(try route("https://x.com/", alternative: true, in: config) == matched)
        #expect(try route("https://y.com/", alternative: true, in: config) == fallback)
    }

    @Test func alternativeNamingSelfIsSkipped() throws {
        let rule = Rule(name: "x", domains: ["x.com"], target: safari)
        let config = Config(defaultBrowser: nil, alternativeBrowser: selfID, rules: [rule])
        let matched = RouteDecision.open(bundleID: safari, reason: .rule(rule.id))
        #expect(try route("https://x.com/", alternative: true, in: config) == matched)
        #expect(try route("https://y.com/", alternative: true, in: config) == .prompt)
    }

    @Test func firstMatchingRuleWins() throws {
        let first = Rule(name: "first", domains: ["x.com"], target: safari)
        let second = Rule(name: "second", domains: ["blog.x.com"], target: chrome)
        let config = Config(defaultBrowser: firefox, rules: [first, second])
        #expect(try route("https://blog.x.com/post", in: config) == .open(bundleID: safari, reason: .rule(first.id)))
    }

    @Test func disabledRulesAreSkipped() throws {
        let disabled = Rule(name: "off", enabled: false, domains: ["x.com"], target: safari)
        let enabled = Rule(name: "on", domains: ["x.com"], target: chrome)
        let config = Config(defaultBrowser: firefox, rules: [disabled, enabled])
        #expect(try route("https://x.com/", in: config) == .open(bundleID: chrome, reason: .rule(enabled.id)))

        let onlyDisabled = Config(defaultBrowser: firefox, rules: [disabled])
        #expect(try route("https://x.com/", in: onlyDisabled) == .open(bundleID: firefox, reason: .defaultBrowser))
    }

    @Test func ruleTargetNamingSelfIsSkipped() throws {
        let toSelf = Rule(name: "self", domains: ["x.com"], target: selfID)
        let fallback = Rule(name: "fallback", domains: ["x.com"], target: chrome)
        let config = Config(defaultBrowser: firefox, rules: [toSelf, fallback])
        #expect(try route("https://x.com/", in: config) == .open(bundleID: chrome, reason: .rule(fallback.id)))

        let onlySelf = Config(defaultBrowser: firefox, rules: [toSelf])
        #expect(try route("https://x.com/", in: onlySelf) == .open(bundleID: firefox, reason: .defaultBrowser))
    }

    @Test func emptyRuleTargetIsSkipped() throws {
        let empty = Rule(name: "empty", domains: ["x.com"], target: "")
        let config = Config(defaultBrowser: firefox, rules: [empty])
        #expect(try route("https://x.com/", in: config) == .open(bundleID: firefox, reason: .defaultBrowser))
    }

    @Test func domainsAndSourcesMustBothMatch() throws {
        let rule = Rule(
            name: "slack backoffice",
            domains: ["backoffice.example.com"],
            sourceApps: [slack],
            target: chrome
        )
        let config = Config(defaultBrowser: safari, rules: [rule])
        let matched = RouteDecision.open(bundleID: chrome, reason: .rule(rule.id))
        let fallback = RouteDecision.open(bundleID: safari, reason: .defaultBrowser)
        #expect(try route("https://backoffice.example.com/payouts", source: slack, in: config) == matched)
        #expect(try route("https://backoffice.example.com/payouts", source: mail, in: config) == fallback)
        #expect(try route("https://example.com/", source: slack, in: config) == fallback)
        #expect(try route("https://other.com/", source: mail, in: config) == fallback)
    }

    @Test func ruleWithBothListsEmptyNeverMatches() throws {
        let rule = Rule(name: "empty lists", target: chrome)
        let config = Config(defaultBrowser: nil, rules: [rule])
        #expect(try route("https://x.com/", source: slack, in: config) == .prompt)
        #expect(try route("https://x.com/", in: config) == .prompt)
        #expect(Router.route(fileRequest(), config: config, selfBundleID: selfID) == .prompt)
    }

    @Test func unknownSourceNeverMatchesASourceConstrainedRule() throws {
        let sourceOnly = Rule(name: "from slack", sourceApps: [slack], target: chrome)
        let both = Rule(name: "slack x", domains: ["x.com"], sourceApps: [slack], target: chrome)
        let config = Config(defaultBrowser: safari, rules: [sourceOnly, both])
        let fallback = RouteDecision.open(bundleID: safari, reason: .defaultBrowser)
        #expect(try route("https://x.com/", source: nil, in: config) == fallback)
        #expect(try route("https://x.com/", source: "", in: config) == fallback)
    }

    @Test func domainOnlyRuleStillMatchesAnUnknownSource() throws {
        let rule = Rule(name: "youtube", domains: ["youtube.com"], target: safari)
        let config = Config(defaultBrowser: chrome, rules: [rule])
        let decision = try route("https://www.youtube.com/watch?v=1", source: nil, in: config)
        #expect(decision == .open(bundleID: safari, reason: .rule(rule.id)))
    }

    @Test func sourceOnlyRuleMatchesAnyHost() throws {
        let rule = Rule(name: "from slack", sourceApps: [slack], target: chrome)
        let config = Config(defaultBrowser: safari, rules: [rule])
        let decision = try route("https://anything.example/", source: slack, in: config)
        #expect(decision == .open(bundleID: chrome, reason: .rule(rule.id)))
    }

    @Test func defaultBrowserIsUsedWhenNothingMatches() throws {
        let rule = Rule(name: "x", domains: ["x.com"], target: chrome)
        let config = Config(defaultBrowser: safari, rules: [rule])
        #expect(try route("https://y.com/", in: config) == .open(bundleID: safari, reason: .defaultBrowser))
    }

    @Test func nilDefaultBrowserMeansPrompt() throws {
        #expect(try route("https://y.com/", in: Config.initial) == .prompt)
    }

    @Test func defaultBrowserNamingSelfPrompts() throws {
        #expect(try route("https://y.com/", in: Config(defaultBrowser: selfID)) == .prompt)
    }

    @Test func emptyDefaultBrowserPrompts() throws {
        #expect(try route("https://y.com/", in: Config(defaultBrowser: "")) == .prompt)
    }

    @Test func fileURLNeverMatchesADomainRule() {
        let rule = Rule(name: "localhost", domains: ["localhost"], target: chrome)
        let config = Config(defaultBrowser: safari, rules: [rule])
        let decision = Router.route(fileRequest(), config: config, selfBundleID: selfID)
        #expect(decision == .open(bundleID: safari, reason: .defaultBrowser))
    }

    @Test func queryAndFragmentDoNotAffectMatching() throws {
        let yRule = Rule(name: "y", domains: ["y.com"], target: chrome)
        let xRule = Rule(name: "x", domains: ["x.com"], target: firefox)
        let link = "https://x.com/login?next=https://y.com/&host=y.com#y.com"
        let onlyY = Config(defaultBrowser: safari, rules: [yRule])
        let both = Config(defaultBrowser: safari, rules: [yRule, xRule])
        #expect(try route(link, in: onlyY) == .open(bundleID: safari, reason: .defaultBrowser))
        #expect(try route(link, in: both) == .open(bundleID: firefox, reason: .rule(xRule.id)))
    }

    @Test func userinfoCannotImpersonateAHost() throws {
        let rule = Rule(name: "y", domains: ["y.com"], target: chrome)
        let config = Config(defaultBrowser: safari, rules: [rule])
        #expect(try route("https://y.com@x.com/", in: config) == .open(bundleID: safari, reason: .defaultBrowser))
    }

    @Test func subdomainsMatchAndLookalikesDoNot() throws {
        let rule = Rule(name: "x", domains: ["x.com"], target: chrome)
        let config = Config(defaultBrowser: safari, rules: [rule])
        #expect(try route("https://blog.x.com/", in: config) == .open(bundleID: chrome, reason: .rule(rule.id)))
        #expect(try route("https://evil-x.com/", in: config) == .open(bundleID: safari, reason: .defaultBrowser))
    }

    @Test func domainsInAnUnvalidatedConfigAreNormalizedBeforeMatching() throws {
        let rule = Rule(name: "x", domains: ["X.COM.", "bücher.de"], target: chrome)
        let config = Config(defaultBrowser: safari, rules: [rule])
        let matched = RouteDecision.open(bundleID: chrome, reason: .rule(rule.id))
        #expect(try route("https://www.x.com/", in: config) == matched)
        #expect(try route("https://xn--bcher-kva.de/", in: config) == matched)
    }

    private func route(
        _ urlString: String,
        source: String? = nil,
        alternative: Bool = false,
        in config: Config
    ) throws -> RouteDecision {
        let url = try #require(URL(string: urlString))
        let request = LinkRequest(url: url, sourceBundleID: source, alternativeRequested: alternative)
        return Router.route(request, config: config, selfBundleID: selfID)
    }

    private func fileRequest() -> LinkRequest {
        LinkRequest(url: URL(fileURLWithPath: "/tmp/page.html"), sourceBundleID: nil, alternativeRequested: false)
    }
}
