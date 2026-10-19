import Foundation

public enum HostMatcher {
    public static func host(of url: URL) -> String? {
        fatalError("unimplemented")
    }

    public static func canonicalDomain(_ raw: String) -> String? {
        fatalError("unimplemented")
    }

    public static func domain(fromUserInput raw: String) -> String? {
        fatalError("unimplemented")
    }

    public static func matches(host: String, domain: String) -> Bool {
        fatalError("unimplemented")
    }
}
