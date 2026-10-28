import SwiftUI

struct PickerMoreButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: PickerMetrics.moreButtonSize, height: PickerMetrics.moreButtonSize)
                .background {
                    Circle()
                        .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("More")
        .accessibilityLabel("More")
    }
}
