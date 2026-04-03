import SwiftUI

struct ModulePlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }
}
