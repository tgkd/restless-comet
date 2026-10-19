import Foundation

public enum ConfigValidator {
    public static func validate(_ config: Config, selfBundleID: String) -> Result<Config, ConfigIssue> {
        if config.schemaVersion != Config.currentSchemaVersion {
            return .failure(.unsupportedSchema(config.schemaVersion))
        }
        var problems: [String] = []
        var canonical = config

        if let defaultBrowser = config.defaultBrowser, defaultBrowser == selfBundleID {
            problems.append(
                "defaultBrowser \"\(defaultBrowser)\" is this app itself; "
                    + "use another browser's bundle id, or null to always prompt."
            )
        }
        if let alternativeBrowser = config.alternativeBrowser, alternativeBrowser == selfBundleID {
            problems.append(
                "alternativeBrowser \"\(alternativeBrowser)\" is this app itself; "
                    + "use another browser's bundle id, or null for none."
            )
        }
        for (index, bundleID) in config.shownBrowsers.enumerated() where bundleID == selfBundleID {
            problems.append("shownBrowsers[\(index)] \"\(bundleID)\" is this app itself; remove it from the list.")
        }
        canonical.shownBrowsers = withoutDuplicates(config.shownBrowsers)

        var rules: [Rule] = []
        for (index, rule) in config.rules.enumerated() {
            let ruleLabel = label(of: rule, at: index)
            rules.append(validated(rule, label: ruleLabel, selfBundleID: selfBundleID, problems: &problems))
        }
        canonical.rules = rules

        if problems.isEmpty {
            return .success(canonical)
        }
        return .failure(.invalid(problems))
    }

    private static func validated(
        _ rule: Rule,
        label: String,
        selfBundleID: String,
        problems: inout [String]
    ) -> Rule {
        if isBlank(rule.target) {
            problems.append("\(label): target is empty; set it to a browser's bundle id.")
        } else if rule.target == selfBundleID {
            problems.append(
                "\(label): target \"\(rule.target)\" is this app itself; use another browser's bundle id."
            )
        }
        if rule.domains.isEmpty && rule.sourceApps.isEmpty {
            problems.append(
                "\(label): domains and sourceApps are both empty, so the rule can never match; "
                    + "add at least one domain or source app."
            )
        }

        var canonicalRule = rule
        canonicalRule.domains = rule.domains.enumerated().map { domainIndex, domain in
            guard let canonicalDomain = HostMatcher.canonicalDomain(domain) else {
                problems.append(
                    "\(label): domains[\(domainIndex)] \"\(domain)\" is not a bare host; "
                        + "write it like \"example.com\" with no scheme, path, port, wildcard or spaces "
                        + "(subdomains match automatically)."
                )
                return domain
            }
            return canonicalDomain
        }
        for (sourceIndex, sourceApp) in rule.sourceApps.enumerated() where isBlank(sourceApp) {
            problems.append("\(label): sourceApps[\(sourceIndex)] is empty; use an app's bundle id.")
        }
        return canonicalRule
    }

    private static func label(of rule: Rule, at index: Int) -> String {
        rule.name.isEmpty ? "rules[\(index)]" : "rules[\(index)] \"\(rule.name)\""
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func withoutDuplicates(_ bundleIDs: [String]) -> [String] {
        var seen = Set<String>()
        return bundleIDs.filter { seen.insert($0).inserted }
    }
}
