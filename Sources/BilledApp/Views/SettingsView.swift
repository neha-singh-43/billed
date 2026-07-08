import BilledCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sessionSection
                    providersSection
                    displaySection
                    refreshSection
                    startupSection
                    privacySection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                model.showSettings = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.headline.weight(.semibold))
                Text("Providers and menu bar behavior")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var sessionSection: some View {
        settingsSection("Active provider", systemImage: "checkmark.seal") {
            Label(connectionText, systemImage: connectionIcon)
                .font(.caption)
                .foregroundStyle(model.authStatus.source == .none ? .red : .secondary)
            if model.authStatus.source == .localApp {
                Text("Using \(model.selectedProvider.displayName)'s local account or data source.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Open \(model.selectedProvider.displayName), sign in or create local state, then reopen this panel.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var connectionText: String {
        switch model.authStatus.source {
        case .localApp:
            if let email = model.authStatus.email {
                return "Connected via \(model.selectedProvider.displayName) (\(email))"
            }
            return "Connected via \(model.selectedProvider.displayName)"
        case .none:
            return "\(model.selectedProvider.displayName) not connected"
        }
    }

    private var connectionIcon: String {
        switch model.authStatus.source {
        case .localApp: "checkmark.seal.fill"
        case .none: "exclamationmark.triangle.fill"
        }
    }

    private var providersSection: some View {
        settingsSection("Provider settings", systemImage: "square.grid.2x2") {
            ForEach(ServiceProvider.allCases) { provider in
                providerRow(provider)
            }
        }
    }

    private func providerRow(_ provider: ServiceProvider) -> some View {
        let isSelected = provider == model.selectedProvider
        let isAvailable = provider.isAvailable
        let isEnabled = model.isProviderEnabled(provider)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: provider.iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isAvailable ? (isEnabled ? .secondary : .tertiary) : .tertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 5) {
                Button {
                    model.selectedProvider = provider
                } label: {
                    HStack(spacing: 6) {
                        Text(provider.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        if isSelected {
                            Text("Selected")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        Spacer()
                        Toggle("Enabled", isOn: Binding(
                            get: { model.isProviderEnabled(provider) },
                            set: { model.setProviderEnabled(provider, $0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
                .buttonStyle(.plain)
                HStack(spacing: 6) {
                    Text(provider.settingsDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Label(isAvailable ? "Available" : "Missing", systemImage: isAvailable ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.caption2)
                        .foregroundStyle(isAvailable ? .green : .secondary)
                        .labelStyle(.titleAndIcon)
                }
                Text(provider.settingsPaths.joined(separator: " · "))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .opacity(isEnabled ? 1 : 0.55)
    }

    private var displaySection: some View {
        settingsSection("Menu bar display", systemImage: "menubar.rectangle") {
            Picker("Unit", selection: Binding(
                get: { model.preferences.menuBarUnit },
                set: { newValue in
                    model.preferences.menuBarUnit = newValue
                    Task { await model.menuBarMetricChanged() }
                }
            )) {
                ForEach(MenuBarUnit.allCases) { unit in
                    Text(unit.title).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("Choose whether the menu bar shows tokens or dollars for the selected usage range.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var refreshSection: some View {
        settingsSection("Refresh", systemImage: "arrow.clockwise") {
            Stepper(
                "Interval: \(model.preferences.refreshIntervalMinutes) min",
                value: Binding(
                    get: { model.preferences.refreshIntervalMinutes },
                    set: { model.preferences.refreshIntervalMinutes = $0 }
                ),
                in: 60...240,
                step: 15
            )
            Text("Dashboard endpoints are unofficial; 60 min minimum.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var startupSection: some View {
        settingsSection("Startup", systemImage: "poweron") {
            Toggle("Launch at login", isOn: Binding(
                get: { model.preferences.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
        }
    }

    private var privacySection: some View {
        settingsSection("Privacy", systemImage: "lock.shield") {
            Text("Usage data stays on this Mac. Local app credentials and state are read on demand and are never stored by Billed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done") { model.showSettings = false }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func settingsSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
