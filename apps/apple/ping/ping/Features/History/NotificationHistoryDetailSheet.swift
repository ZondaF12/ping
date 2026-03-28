import SwiftUI

struct NotificationHistoryDetailSheet: View {
    let entry: NotificationHistoryEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private static let sentFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let title = entry.title, !title.isEmpty {
                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    if let subtitle = entry.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    let bodyText = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !bodyText.isEmpty {
                        Text(bodyText)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }

                    notificationImageLarge

                    if let destination = linkDestination {
                        Button {
                            openURL(destination)
                        } label: {
                            Label("Open Link", systemImage: "link")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.2, green: 0.55, blue: 1.0))
                    }

                    Label {
                        Text("Sent \(Self.sentFormatter.localizedString(for: entry.receivedAt, relativeTo: Date()))")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: entry.shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var linkDestination: URL? {
        guard let raw = entry.linkURL,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }
        return url
    }

    @ViewBuilder
    private var notificationImageLarge: some View {
        if let s = entry.imageURL, let url = URL(string: s), !s.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .overlay {
                            ProgressView()
                        }
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}
