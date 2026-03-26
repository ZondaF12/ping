import SwiftUI

struct PingRootView: View {
    var body: some View {
        NavigationStack {
            HomeView()
                .navigationTitle("Ping")
        }
    }
}

