import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private static let docsURL = URL(string: "https://brrr.now/how-it-works/")!
    private static let guidesURL = URL(string: "https://brrr.now/how-it-works/#guides")!

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SubscriptionPlaceholderView()
                } label: {
                    SettingsSymbolRow(
                        title: "Subscription",
                        subtitle: "Your free access ends 8 Apr 2026.",
                        systemImage: "heart.fill",
                        iconTint: .white,
                        iconBackground: Color(red: 0.55, green: 0.36, blue: 0.96),
                        trailingStyle: .none
                    )
                }

                NavigationLink {
                    WebhooksView()
                } label: {
                    SettingsSymbolRow(
                        title: "Webhooks",
                        subtitle: nil,
                        systemImage: "bolt.fill",
                        iconTint: .white,
                        iconBackground: Color(red: 0.2, green: 0.55, blue: 1.0),
                        trailingStyle: .none
                    )
                }
            }

            Section {
                Link(destination: Self.docsURL) {
                    SettingsSymbolRow(
                        title: "Documentation",
                        subtitle: nil,
                        systemImage: "doc.text.fill",
                        iconTint: .white,
                        iconBackground: Color.orange
                    )
                }
                .buttonStyle(.plain)

                Link(destination: Self.guidesURL) {
                    SettingsSymbolRow(
                        title: "Guides",
                        subtitle: nil,
                        systemImage: "graduationcap.fill",
                        iconTint: .white,
                        iconBackground: Color.green
                    )
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    SettingsSymbolRow(
                        title: "Send Test Notification",
                        subtitle: nil,
                        systemImage: "paperplane.fill",
                        iconTint: .white,
                        iconBackground: Color(red: 0.3, green: 0.75, blue: 0.85)
                    )
                }
                .buttonStyle(.plain)
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    SettingsSymbolRow(
                        title: "Notification Settings",
                        subtitle: nil,
                        systemImage: "bell.fill",
                        iconTint: .white,
                        iconBackground: Color.red.opacity(0.9),
                        trailingStyle: .external
                    )
                }
                .buttonStyle(.plain)
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    SettingsSymbolRow(
                        title: "About",
                        subtitle: nil,
                        systemImage: "info.circle.fill",
                        iconTint: .white,
                        iconBackground: Color(red: 0.45, green: 0.45, blue: 0.5),
                        trailingStyle: .none
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.secondary, Color.secondary.opacity(0.35))
                }
                .accessibilityLabel("Close")
            }
        }
    }
}

private struct SubscriptionPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscription details will appear here when billing is available.")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(HomeViewModel())
                .environmentObject(PushTokenStore())
        }
    }
}
