import SwiftUI

struct PickerContentView: View {
    let model: PickerViewModel
    let actions: PickerActions

    var body: some View {
        VStack(alignment: .leading, spacing: PickerMetrics.rowSpacing) {
            if let noticeText = model.noticeText {
                Text(noticeText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if model.items.isEmpty {
                fallbackRow
            } else {
                choicesRow
            }
        }
        .padding(PickerMetrics.contentPadding)
        .fixedSize()
        .focusEffectDisabled()
    }

    private var choicesRow: some View {
        HStack(alignment: .top, spacing: PickerMetrics.cellSpacing) {
            ForEach(model.items) { item in
                PickerChoiceCell(
                    item: item,
                    isHighlighted: model.highlightedIndex == item.index,
                    onHover: { actions.hover(item.index) },
                    onChoose: { actions.choose(item.index) }
                )
            }
            VStack(spacing: PickerMetrics.labelSpacing) {
                PickerPendingBadge(pendingCount: model.pendingCount)
                    .frame(height: PickerMetrics.labelHeight)
                PickerMoreButton(action: actions.showMenu)
                    .frame(height: PickerMetrics.iconBoxSize)
            }
            .frame(minWidth: PickerMetrics.trailingColumnMinWidth)
        }
    }

    private var fallbackRow: some View {
        HStack(spacing: PickerMetrics.rowSpacing) {
            Button("Copy", action: actions.copy)
            PickerPendingBadge(pendingCount: model.pendingCount)
            PickerMoreButton(action: actions.showMenu)
        }
    }
}
