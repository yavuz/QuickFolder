import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: FolderStore
    @StateObject private var loginItemController = LoginItemController()
    @AppStorage(PreferenceKeys.recentLimit) private var recentLimit = 25
    @AppStorage(PreferenceKeys.finderHistoryEnabled) private var finderHistoryEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("QuickFolder")
                        .font(.title3.weight(.semibold))
                    Text("Menu bar access for pinned and recent folders.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Form {
                Toggle("Launch at login", isOn: Binding(
                    get: { loginItemController.isEnabled },
                    set: { loginItemController.setEnabled($0) }
                ))

                Picker("Recent limit", selection: $recentLimit) {
                    Text("10").tag(10)
                    Text("25").tag(25)
                    Text("50").tag(50)
                }
                .pickerStyle(.segmented)

                Toggle("Include macOS recent folders", isOn: $finderHistoryEnabled)
                    .onChange(of: finderHistoryEnabled) { _, isEnabled in
                        if isEnabled {
                            store.refreshFinderRecents()
                        }
                    }

                Button(role: .destructive) {
                    store.clearRecents()
                } label: {
                    Label("Clear Recents", systemImage: "clock.badge.xmark")
                }
            }
            .formStyle(.grouped)

            if let errorMessage = loginItemController.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(width: 430)
        .onAppear {
            loginItemController.refresh()
        }
    }
}
