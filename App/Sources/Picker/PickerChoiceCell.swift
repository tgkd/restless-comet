import SwiftUI

struct PickerChoiceCell: View {
    let item: PickerChoiceItem
    let isHighlighted: Bool
    let onHover: () -> Void
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            VStack(spacing: PickerMetrics.labelSpacing) {
                Text(item.shortcutLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(height: PickerMetrics.labelHeight)
                Image(nsImage: item.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: PickerMetrics.iconSize, height: PickerMetrics.iconSize)
                    .padding(PickerMetrics.iconPadding)
                    .background {
                        RoundedRectangle(cornerRadius: PickerMetrics.highlightCornerRadius, style: .continuous)
                            .fill(isHighlighted ? Color.accentColor : Color.clear)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.browser.name)
        .accessibilityLabel(item.browser.name)
        .onContinuousHover { phase in
            if case .active = phase {
                onHover()
            }
        }
    }
}
