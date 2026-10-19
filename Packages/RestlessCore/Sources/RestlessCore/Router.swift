import Foundation

public enum Router {
    public static func route(_ request: LinkRequest, config: Config, selfBundleID: String) -> RouteDecision {
        if request.alternativeRequested,
           let alternative = config.alternativeBrowser,
           isUsableTarget(alternative, selfBundleID: selfBundleID) {
            return .open(bundleID: alternative, reason: .alternative)
        }
        let host = HostMatcher.host(of: request.url)
        for rule in config.rules where rule.enabled && isUsableTarget(rule.target, selfBundleID: selfBundleID) {
            if ruleMatches(rule, host: host, sourceBundleID: request.sourceBundleID) {
                return .open(bundleID: rule.target, reason: .rule(rule.id))
            }
        }
        if let defaultBrowser = config.defaultBrowser, isUsableTarget(defaultBrowser, selfBundleID: selfBundleID) {
            return .open(bundleID: defaultBrowser, reason: .defaultBrowser)
        }
        return .prompt
    }

    private static func isUsableTarget(_ bundleID: String, selfBundleID: String) -> Bool {
        !bundleID.isEmpty && bundleID != selfBundleID
    }

    private static func ruleMatches(_ rule: Rule, host: String?, sourceBundleID: String?) -> Bool {
        if rule.domains.isEmpty && rule.sourceApps.isEmpty {
            return false
        }
        if !rule.domains.isEmpty && !anyDomainMatches(rule.domains, host: host) {
            return false
        }
        if !rule.sourceApps.isEmpty && !sourceMatches(rule.sourceApps, sourceBundleID: sourceBundleID) {
            return false
        }
        return true
    }

    private static func anyDomainMatches(_ domains: [String], host: String?) -> Bool {
        guard let host else {
            return false
        }
        return domains.contains { domain in
            guard let canonical = HostMatcher.canonicalDomain(domain) else {
                return false
            }
            return HostMatcher.matches(host: host, domain: canonical)
        }
    }

    private static func sourceMatches(_ sourceApps: [String], sourceBundleID: String?) -> Bool {
        guard let sourceBundleID else {
            return false
        }
        return sourceApps.contains(sourceBundleID)
    }
}
