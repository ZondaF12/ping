import SwiftUI

struct SettingsSymbolRow: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    let iconTint: Color
    let iconBackground: Color
    var trailingSystemImage: String = "chevron.right"
    var trailingStyle: TrailingStyle = .chevron

    enum TrailingStyle {
        case chevron
        case external
        case none
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 32, height: 32)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            switch trailingStyle {
            case .chevron:
                Image(systemName: trailingSystemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            case .external:
                Image(systemName: "arrow.up.forward.square")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            case .none:
                EmptyView()
            }
        }
        .contentShape(Rectangle())
    }
}
