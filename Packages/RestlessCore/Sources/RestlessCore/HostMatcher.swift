import Foundation

public enum HostMatcher {
    public static func host(of url: URL) -> String? {
        if url.isFileURL {
            return nil
        }
        guard let rawHost = url.host(percentEncoded: false) else {
            return nil
        }
        return normalized(rawHost)
    }

    public static func canonicalDomain(_ raw: String) -> String? {
        if raw.isEmpty || raw.unicodeScalars.contains(where: forbiddenInBareHost.contains) {
            return nil
        }
        if let literal = ipv6Literal(raw) {
            return literal
        }
        if raw.contains(where: { $0 == ":" || $0 == "[" || $0 == "]" }) {
            return nil
        }
        guard let parsedHost = URL(string: "https://\(raw)")?.host(percentEncoded: false),
              let host = normalized(parsedHost) else {
            return nil
        }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.allSatisfy(isValidLabel) else {
            return nil
        }
        return host
    }

    public static func domain(fromUserInput raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        if let bareHost = canonicalDomain(trimmed) {
            return bareHost
        }
        let hasScheme = trimmed.contains("://")
        guard let url = URL(string: hasScheme ? trimmed : "https://\(trimmed)"), !url.isFileURL else {
            return nil
        }
        if !hasScheme && (url.user() != nil || url.password() != nil) {
            return nil
        }
        guard let urlHost = url.host(percentEncoded: false) else {
            return nil
        }
        return canonicalDomain(urlHost)
    }

    public static func matches(host: String, domain: String) -> Bool {
        if host.isEmpty || domain.isEmpty {
            return false
        }
        if host == domain {
            return true
        }
        if isIPLiteral(host) || isIPLiteral(domain) {
            return false
        }
        return host.hasSuffix(".\(domain)")
    }

    private static let forbiddenInBareHost = CharacterSet.whitespacesAndNewlines
        .union(.controlCharacters)
        .union(CharacterSet(charactersIn: "/\\?#@%"))

    private static func normalized(_ rawHost: String) -> String? {
        var host = rawHost.lowercased()
        if host.hasSuffix(".") {
            host.removeLast()
        }
        return host.isEmpty ? nil : host
    }

    private static func ipv6Literal(_ raw: String) -> String? {
        var candidate = Substring(raw)
        if candidate.count >= 2 && candidate.hasPrefix("[") && candidate.hasSuffix("]") {
            candidate = candidate.dropFirst().dropLast()
        }
        guard candidate.contains(":"), isIPv6Address(String(candidate)) else {
            return nil
        }
        guard let parsedHost = URL(string: "https://[\(candidate)]")?.host(percentEncoded: false) else {
            return nil
        }
        return normalized(parsedHost)
    }

    private static func isIPv6Address(_ text: String) -> Bool {
        var address = in6_addr()
        return inet_pton(AF_INET6, text, &address) == 1
    }

    private static func isIPLiteral(_ host: String) -> Bool {
        if host.contains(":") {
            return true
        }
        guard let lastLabel = host.split(separator: ".").last else {
            return false
        }
        if lastLabel.allSatisfy({ $0.isASCII && $0.isNumber }) {
            return true
        }
        let lowercasedLabel = lastLabel.lowercased()
        return lowercasedLabel.hasPrefix("0x")
            && lowercasedLabel.dropFirst(2).allSatisfy { $0.isASCII && $0.isHexDigit }
    }

    private static func isValidLabel(_ label: Substring) -> Bool {
        !label.isEmpty && label.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "-" || character == "_")
        }
    }
}
