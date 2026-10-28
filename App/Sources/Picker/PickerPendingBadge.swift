import SwiftUI

struct PickerPendingBadge: View {
    let pendingCount: Int

    var body: some View {
        if pendingCount > 1 {
            Text(verbatim: "+\(pendingCount - 1)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
                .help("Links waiting after this one")
        }
    }
}
