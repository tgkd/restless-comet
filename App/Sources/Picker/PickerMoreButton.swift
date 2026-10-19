import SwiftUI

struct PickerMoreButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: PickerMetrics.moreButtonSize, height: PickerMetrics.moreButtonSize)
                .background(.quaternary, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("More")
        .accessibilityLabel("More")
    }
}
