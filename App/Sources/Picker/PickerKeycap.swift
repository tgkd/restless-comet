import SwiftUI

struct PickerKeycap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: PickerMetrics.keycapSize, height: PickerMetrics.keycapSize)
            .background {
                RoundedRectangle(cornerRadius: PickerMetrics.keycapCornerRadius, style: .continuous)
                    .strokeBorder(.tertiary, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}
