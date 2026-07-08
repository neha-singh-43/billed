import BilledCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sessionSection
                    providersSection
                    displaySection
                    refreshSection
                    startupSection
                    privacySection
                }
                .padding(16)
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack {
            Button("← Back") { model.showSettings = false }
                .buttonStyle(.plain)
                .font(.body)
            Spacer()
            Text("Settings")
                .font(.headline)
            Spacer()
        }
        .padding(16)
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Active provider")
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
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Provider settings")
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
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Menu bar display")
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
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Refresh")
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
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Startup")
            Toggle("Launch at login", isOn: Binding(
                get: { model.preferences.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Privacy")
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
        .padding(12)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
    }
}
