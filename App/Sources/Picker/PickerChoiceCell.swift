import SwiftUI

struct PickerChoiceCell: View {
    let item: PickerChoiceItem
    let isHighlighted: Bool
    let onHover: () -> Void
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            VStack(spacing: PickerMetrics.nameSpacing) {
                Image(nsImage: item.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: PickerMetrics.iconSize, height: PickerMetrics.iconSize)
                Text(item.browser.name)
                    .font(.caption)
                    .foregroundStyle(isHighlighted ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, PickerMetrics.cellVerticalPadding)
            .frame(width: PickerMetrics.cellWidth)
            .background {
                RoundedRectangle(cornerRadius: PickerMetrics.highlightCornerRadius, style: .continuous)
                    .fill(isHighlighted ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            }
            .overlay(alignment: .topLeading) {
                if !item.shortcutLabel.isEmpty {
                    PickerKeycap(label: item.shortcutLabel)
                        .padding(PickerMetrics.keycapInset)
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
