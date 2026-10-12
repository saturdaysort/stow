import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The Settings window (spec 5.3 to 5.5): System Settings style, system accent color.
public struct SettingsView: View {
    @Bindable var model: SettingsModel

    public init(model: SettingsModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            if !model.isInstalledCorrectly {
                Section {
                    Label("Stow must be in the Applications folder to hide icons.",
                          systemImage: "exclamationmark.triangle.fill")
                }
            }
            if !model.isTrusted {
                Section {
                    HStack {
                        Text("Allow Accessibility so Stow can list your menu bar apps.")
                        Spacer()
                        Button("Open Privacy & Security") { model.requestAccessibility() }
                    }
                }
            }
            Section {
                if model.apps.isEmpty {
                    Text(model.isTrusted ? "No apps with menu bar icons are running." : "Your menu bar apps will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.apps) { app in
                        AppRow(app: app) { hidden in model.setHidden(app, hidden) }
                    }
                }
            } header: {
                Text("Apps to hide")
            } footer: {
                Text("All of an app's menu bar icons hide together.")
            }
            Section("Behavior") {
                Picker("Hide again after", selection: Binding(get: { model.rehideDelay },
                                                               set: { model.setRehideDelay($0) })) {
                    ForEach(RehideDelay.allCases) { delay in
                        Text(delay.title).tag(delay)
                    }
                }
                LabeledContent("Keyboard shortcut") {
                    VStack(alignment: .trailing, spacing: 4) {
                        ShortcutRecorder(shortcut: model.shortcut) { model.setShortcut($0) }
                            .frame(width: 140, height: 22)
                        if let error = model.shortcutError {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                Toggle("Open at login", isOn: Binding(get: { model.loginStatus == .enabled },
                                                      set: { model.setLoginEnabled($0) }))
                if model.loginStatus == .requiresApproval {
                    HStack {
                        Text("Approve Stow in System Settings › General › Login Items")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Open") { model.openLoginItemsSettings() }
                    }
                }
            }
            Section("Always hidden") {
                HStack {
                    Text("To keep an app out of the menu bar for good, turn it off in System Settings.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Menu Bar Settings…") { model.openMenuBarSettings() }
                }
            }
            Section("About hiding") {
                Text(SettingsCopy.aboutHiding)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 620)
        .task { await model.refresh() }
        .task(id: model.isTrusted) {
            // While the Accessibility banner shows, fill the list as soon as access is granted.
            guard !model.isTrusted else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if await model.pollTrust() { break }
            }
        }
    }
}

struct AppRow: View {
    let app: ListedApp
    let onChange: @MainActor (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { app.isHidden }, set: { onChange($0) })) {
            HStack(spacing: 10) {
                Image(nsImage: AppIcons.icon(for: app.bundleID))
                    .resizable()
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                    if !app.isRunning {
                        Text("Not running").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityLabel(app.isRunning ? app.name : "\(app.name), not running")
    }
}

@MainActor
enum AppIcons {
    static func icon(for bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}
