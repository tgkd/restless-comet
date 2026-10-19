import SwiftUI

struct SettingsConfigProblemView: View {
    let problem: SettingsConfigProblem

    private var listedDetails: [String] {
        Array(problem.details.prefix(SettingsMetrics.maxListedIssues))
    }

    private var unlistedCount: Int {
        problem.details.count - listedDetails.count
    }

    private var usesBullets: Bool {
        problem.details.count > 1
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 6) {
                Text(problem.title)
                    .fontWeight(.semibold)
                ForEach(Array(listedDetails.enumerated()), id: \.offset) { _, detail in
                    detailLine(detail)
                }
                if unlistedCount > 0 {
                    Text("And \(unlistedCount) more.")
                        .foregroundStyle(.secondary)
                }
                ForEach(problem.consequences, id: \.self) { consequence in
                    Text(consequence)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        } icon: {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func detailLine(_ detail: String) -> some View {
        if usesBullets {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                Text(detail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(detail)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
