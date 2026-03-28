import SwiftUI

struct RecentNotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NotificationHistoryStore
    @State private var confirmClearAll = false
    @State private var selectedEntry: NotificationHistoryEntry?

    private var daySections: [NotificationHistoryDaySection] {
        NotificationHistoryDaySection.build(entries: store.entries)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Settings")
                    Spacer()
                    Picker(
                        "Storage duration",
                        selection: Binding(
                            get: { store.retention },
                            set: { store.updateRetention($0) }
                        )
                    ) {
                        ForEach(NotificationHistoryRetention.allCases, id: \.self) { option in
                            Text(option.menuLabel).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accentColor(.secondary)
                }
                .accessibilityHint("Choose how long to keep history on this device")
            }

            if daySections.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No notifications yet",
                        systemImage: "bell.slash",
                        description: Text("Webhook pushes will appear here. History is stored only on this device.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(daySections) { section in
                    Section(header: Text(section.headerTitle())) {
                        ForEach(section.entries) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                NotificationHistoryRowContent(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Recent Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    confirmClearAll = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Clear all")
                .disabled(store.entries.isEmpty)
            }
        }
        .confirmationDialog(
            "Clear all notification history on this device?",
            isPresented: $confirmClearAll,
            titleVisibility: .visible
        ) {
            Button("Clear all", role: .destructive) {
                store.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await store.syncDeliveredNotifications()
        }
        .sheet(item: $selectedEntry) { entry in
            NotificationHistoryDetailSheet(entry: entry)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
    }
}

private struct NotificationHistoryRowContent: View {
    let entry: NotificationHistoryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                let bodyText = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasLine =
                    !(entry.title?.isEmpty ?? true)
                    || !(entry.subtitle?.isEmpty ?? true)
                    || !bodyText.isEmpty
                if hasLine {
                    if let title = entry.title, !title.isEmpty {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    if let subtitle = entry.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    if !bodyText.isEmpty {
                        Text(bodyText)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    Text(entry.primaryLine)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                Text(NotificationHistoryTimeFormatting.rowTrailingLabel(for: entry.receivedAt))
                    .foregroundStyle(.secondary)
                    .font(.caption)
                rowThumbnail
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var rowThumbnail: some View {
        if let s = entry.imageURL, let url = URL(string: s), !s.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 52, height: 52)
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}
