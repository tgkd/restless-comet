import SwiftUI

struct SettingsErrorBanner: View {
    let model: AppModel

    var body: some View {
        if let message = model.lastError {
            Section {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Dismiss") {
                        model.lastError = nil
                    }
                }
            }
        }
    }
}
