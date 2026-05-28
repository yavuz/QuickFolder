import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: FolderStore
    @StateObject private var loginItemController = LoginItemController()
    @AppStorage(PreferenceKeys.recentLimit) private var recentLimit = 25
    @AppStorage(PreferenceKeys.finderHistoryEnabled) private var finderHistoryEnabled = true
    @AppStorage(PreferenceKeys.hotKeyKey) private var hotKeyKey = HotKeyConfig.defaultKey
    @AppStorage(PreferenceKeys.hotKeyModifiers) private var hotKeyModifiers = HotKeyConfig.defaultModifiers
    @AppStorage(PreferenceKeys.selectedTerminal) private var selectedTerminal = TerminalApp.terminal.rawValue

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

                Picker("Open folders in terminal with", selection: $selectedTerminal) {
                    ForEach(TerminalApp.allCases) { terminal in
                        Text(terminal.displayName).tag(terminal.rawValue)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Global shortcut")
                        .font(.headline)

                    HStack(spacing: 10) {
                        ForEach(HotKeyModifierOption.allCases) { modifier in
                            Toggle(modifier.symbol, isOn: modifierBinding(modifier))
                                .toggleStyle(.button)
                                .help(modifier.label)
                        }

                        TextField("Key", text: hotKeyKeyBinding)
                            .multilineTextAlignment(.center)
                            .frame(width: 48)
                            .textFieldStyle(.roundedBorder)

                        Text(HotKeyConfig.current.displayString)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 58, alignment: .leading)
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

    private var hotKeyKeyBinding: Binding<String> {
        Binding(
            get: { hotKeyKey },
            set: { newValue in
                if let key = HotKeyConfig.sanitizedKey(newValue) {
                    hotKeyKey = key
                }
            }
        )
    }

    private func modifierBinding(_ modifier: HotKeyModifierOption) -> Binding<Bool> {
        Binding(
            get: { hotKeyModifiers & modifier.carbonValue != 0 },
            set: { isEnabled in
                if isEnabled {
                    hotKeyModifiers |= modifier.carbonValue
                } else {
                    let updatedModifiers = hotKeyModifiers & ~modifier.carbonValue
                    hotKeyModifiers = updatedModifiers == 0 ? HotKeyConfig.defaultModifiers : updatedModifiers
                }
            }
        )
    }
}
