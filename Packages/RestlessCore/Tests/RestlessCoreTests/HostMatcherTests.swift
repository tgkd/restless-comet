import Foundation
import Testing
@testable import RestlessCore

struct HostMatcherTests {
    @Test(arguments: [
        ("x.com", "x.com"),
        ("blog.x.com", "x.com"),
        ("a.b.blog.x.com", "x.com"),
        ("backoffice.example.com", "backoffice.example.com"),
        ("localhost", "localhost"),
    ])
    func matchesExactHostAndSubdomains(host: String, domain: String) {
        #expect(HostMatcher.matches(host: host, domain: domain))
    }

    @Test(arguments: [
        ("evil-x.com", "x.com"),
        ("notx.com", "x.com"),
        ("xx.com", "x.com"),
        ("x.com", "blog.x.com"),
        ("x.com.evil.net", "x.com"),
        ("x.co", "x.com"),
    ])
    func doesNotMatchAcrossLabelBoundaries(host: String, domain: String) {
        #expect(!HostMatcher.matches(host: host, domain: domain))
    }

    @Test func emptyArgumentsNeverMatch() {
        #expect(!HostMatcher.matches(host: "", domain: "x.com"))
        #expect(!HostMatcher.matches(host: "x.com", domain: ""))
        #expect(!HostMatcher.matches(host: "", domain: ""))
    }

    @Test func hostIsLowercasedWithoutTrailingDot() throws {
        #expect(try HostMatcher.host(of: url("https://Blog.X.COM./path?q=1#frag")) == "blog.x.com")
        #expect(try HostMatcher.host(of: url("HTTPS://WWW.EXAMPLE.COM")) == "www.example.com")
        #expect(try HostMatcher.host(of: url("https://user:secret@x.com:8443/a")) == "x.com")
    }

    @Test func caseAndTrailingDotDoNotPreventAMatch() throws {
        let host = try #require(HostMatcher.host(of: url("https://BLOG.X.COM./")))
        let domain = try #require(HostMatcher.canonicalDomain("X.Com."))
        #expect(host == "blog.x.com")
        #expect(domain == "x.com")
        #expect(HostMatcher.matches(host: host, domain: domain))
    }

    @Test func ipv4LiteralsMatchOnlyExactly() throws {
        let host = try #require(HostMatcher.host(of: url("http://192.168.0.1:8080/admin")))
        #expect(host == "192.168.0.1")
        #expect(HostMatcher.matches(host: host, domain: "192.168.0.1"))
        #expect(!HostMatcher.matches(host: host, domain: "168.0.1"))
        #expect(!HostMatcher.matches(host: host, domain: "0.1"))
        #expect(!HostMatcher.matches(host: "10.0.0.1", domain: "0.0.1"))
        #expect(!HostMatcher.matches(host: "127.1", domain: "1"))
        #expect(HostMatcher.canonicalDomain("192.168.0.1") == "192.168.0.1")
    }

    @Test func ipv6LiteralsMatchOnlyExactly() throws {
        let host = try #require(HostMatcher.host(of: url("https://[2001:DB8::1]:8443/")))
        #expect(host == "2001:db8::1")
        #expect(try HostMatcher.host(of: url("http://[::1]/")) == "::1")
        #expect(HostMatcher.matches(host: host, domain: "2001:db8::1"))
        #expect(!HostMatcher.matches(host: host, domain: "db8::1"))
        #expect(HostMatcher.matches(host: "::ffff:1.2.3.4", domain: "::ffff:1.2.3.4"))
        #expect(!HostMatcher.matches(host: "::ffff:1.2.3.4", domain: "2.3.4"))
        #expect(!HostMatcher.matches(host: "::ffff:1.2.3.4", domain: "3.4"))
    }

    @Test func ipv6DomainsAreCanonicalizedWithoutBrackets() {
        #expect(HostMatcher.canonicalDomain("[2001:DB8::1]") == "2001:db8::1")
        #expect(HostMatcher.canonicalDomain("2001:db8::1") == "2001:db8::1")
        #expect(HostMatcher.canonicalDomain("[::1]") == "::1")
        #expect(HostMatcher.canonicalDomain("[::1]:8080") == nil)
        #expect(HostMatcher.canonicalDomain("[zzz]") == nil)
        #expect(HostMatcher.canonicalDomain(":::") == nil)
        #expect(HostMatcher.canonicalDomain("[]") == nil)
    }

    @Test func urlsWithoutAHostHaveNoHost() throws {
        #expect(HostMatcher.host(of: URL(fileURLWithPath: "/tmp/page.html")) == nil)
        #expect(try HostMatcher.host(of: url("file:///Users/me/page.html")) == nil)
        #expect(try HostMatcher.host(of: url("file://localhost/Users/me/page.html")) == nil)
        #expect(try HostMatcher.host(of: url("mailto:someone@x.com")) == nil)
        #expect(try HostMatcher.host(of: url("https:///path")) == nil)
    }

    @Test(arguments: [
        ("example.com", "example.com"),
        ("X.Com", "x.com"),
        ("x.com.", "x.com"),
        ("Backoffice.Example.COM", "backoffice.example.com"),
        ("localhost", "localhost"),
        ("a_b.x.com", "a_b.x.com"),
        ("my-host.x.com", "my-host.x.com"),
        ("xn--bcher-kva.de", "xn--bcher-kva.de"),
        ("192.168.0.1", "192.168.0.1"),
    ])
    func canonicalDomainAcceptsBareHosts(raw: String, expected: String) {
        #expect(HostMatcher.canonicalDomain(raw) == expected)
    }

    @Test(arguments: [
        "",
        ".",
        "https://x.com",
        "x.com/",
        "x.com/path",
        "x.com:8080",
        "x.com:",
        " x.com",
        "x.com ",
        "x .com",
        "x.com\n",
        "x..com",
        ".x.com",
        "x.com..",
        "*.x.com",
        "!!!",
        "x.com?q=1",
        "x.com#top",
        "user@x.com",
        "x%41.com",
        "x\\y.com",
        "\u{200B}x.com",
        "[x.com]",
        "ä..com",
        "<script>",
    ])
    func canonicalDomainRejectsAnythingButABareHost(raw: String) {
        #expect(HostMatcher.canonicalDomain(raw) == nil)
    }

    @Test(arguments: ["X.Com.", "bücher.de", "[2001:DB8::1]", "::1", "192.168.0.1", "a_b.Example.com"])
    func canonicalDomainIsIdempotent(raw: String) throws {
        let once = try #require(HostMatcher.canonicalDomain(raw))
        #expect(HostMatcher.canonicalDomain(once) == once)
    }

    @Test(arguments: [
        ("X.com", "x.com"),
        ("  x.com \n", "x.com"),
        ("https://backoffice.example.com/payouts?a=1", "backoffice.example.com"),
        ("HTTPS://WWW.EXAMPLE.COM", "www.example.com"),
        ("http://x.com:8080/a#b", "x.com"),
        ("https://user:secret@x.com/", "x.com"),
        ("x.com:8080", "x.com"),
        ("x.com/path?q=1", "x.com"),
        ("localhost:3000", "localhost"),
        ("https://[::1]:3000/", "::1"),
        ("[2001:db8::1]:443", "2001:db8::1"),
        ("https://bücher.de/katalog", "xn--bcher-kva.de"),
        ("https://x.com./", "x.com"),
    ])
    func userInputAcceptsBareHostsAndFullURLs(raw: String, expected: String) {
        #expect(HostMatcher.domain(fromUserInput: raw) == expected)
    }

    @Test(arguments: [
        "",
        "   ",
        "https://",
        "not a domain",
        "!!!",
        "javascript:alert(1)",
        "http://exa mple.com/",
        "file:///Users/me/page.html",
        "mailto:me@x.com",
        "user@x.com",
        "x..com",
        "https://*.x.com/",
        "https://x.com../",
    ])
    func userInputRejectsGarbage(raw: String) {
        #expect(HostMatcher.domain(fromUserInput: raw) == nil)
    }

    @Test func unicodeAndPunycodeSpellingsNormalizeToTheSameHost() throws {
        let unicodeHost = try #require(HostMatcher.host(of: url("https://bücher.de/katalog")))
        let punycodeHost = try #require(HostMatcher.host(of: url("https://xn--bcher-kva.de/katalog")))
        #expect(unicodeHost == "xn--bcher-kva.de")
        #expect(punycodeHost == "xn--bcher-kva.de")

        let unicodeDomain = try #require(HostMatcher.canonicalDomain("bücher.de"))
        let punycodeDomain = try #require(HostMatcher.canonicalDomain("xn--bcher-kva.de"))
        #expect(unicodeDomain == "xn--bcher-kva.de")
        #expect(punycodeDomain == "xn--bcher-kva.de")
        #expect(HostMatcher.canonicalDomain("BÜCHER.de") == "xn--bcher-kva.de")

        #expect(HostMatcher.matches(host: unicodeHost, domain: punycodeDomain))
        #expect(HostMatcher.matches(host: punycodeHost, domain: unicodeDomain))
        let subdomainHost = try #require(HostMatcher.host(of: url("https://shop.bücher.de/")))
        #expect(HostMatcher.matches(host: subdomainHost, domain: unicodeDomain))
    }

    private func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }
}
