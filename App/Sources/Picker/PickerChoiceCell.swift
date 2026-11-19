import SwiftUI

struct PickerChoiceCell: View {
    let item: PickerChoiceItem
    let isHighlighted: Bool
    let onHover: () -> Void
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            VStack(spacing: PickerMetrics.nameSpacing) {
                Group {
                    if let icon = item.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: PickerMetrics.copySymbolSize, weight: .medium))
                            .foregroundStyle(isHighlighted ? .primary : .secondary)
                    }
                }
                .frame(width: PickerMetrics.iconSize, height: PickerMetrics.iconSize)
                Text(item.title)
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
        .help(item.action == .copy ? "Copy Link (⌘C)" : item.title)
        .accessibilityLabel(item.title)
        .onContinuousHover { phase in
            if case .active = phase {
                onHover()
            }
        }
    }
}
