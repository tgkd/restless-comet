import RestlessCore

struct SettingsDomainEntry: Identifiable {
    let id: Int
    let input: String
    let host: String?

    static func parse(_ text: String) -> [SettingsDomainEntry] {
        text.split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .enumerated()
            .map { offset, piece in
                let input = String(piece)
                return SettingsDomainEntry(id: offset, input: input, host: HostMatcher.domain(fromUserInput: input))
            }
    }

    static func uniqueHosts(in entries: [SettingsDomainEntry]) -> [String] {
        SettingsDeduplication.unique(entries.compactMap(\.host))
    }
}
