import SwiftUI

struct PickerContentView: View {
    let model: PickerViewModel
    let actions: PickerActions

    var body: some View {
        VStack(alignment: .leading, spacing: PickerMetrics.rowSpacing) {
            header
            if let noticeText = model.noticeText {
                Label(noticeText, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: PickerMetrics.headerMaxTextWidth, alignment: .leading)
                    .padding(.horizontal, PickerMetrics.headerSpacing)
            }
            if model.items.isEmpty {
                fallbackRow
            } else {
                choicesRow
            }
        }
        .padding(PickerMetrics.contentPadding)
        .fixedSize()
        .overlay {
            RoundedRectangle(cornerRadius: PickerMetrics.panelCornerRadius, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .focusEffectDisabled()
    }

    private var header: some View {
        HStack(spacing: PickerMetrics.headerSpacing) {
            Text(model.hostText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: PickerMetrics.headerMaxTextWidth, alignment: .leading)
                .help(model.urlText)
            Spacer(minLength: 0)
            PickerPendingBadge(pendingCount: model.pendingCount)
            PickerMoreButton(action: actions.showMenu)
        }
        .padding(.leading, PickerMetrics.headerSpacing)
    }

    private var choicesRow: some View {
        HStack(spacing: PickerMetrics.cellSpacing) {
            ForEach(model.items) { item in
                PickerChoiceCell(
                    item: item,
                    isHighlighted: model.highlightedIndex == item.index,
                    onHover: { actions.hover(item.index) },
                    onChoose: { actions.choose(item.index) }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var fallbackRow: some View {
        Button("Copy Link", action: actions.copy)
            .frame(maxWidth: .infinity)
    }
}
