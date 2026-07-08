import BilledCore
import SwiftUI

struct SetupView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect your account")
                .font(.headline)
            Text(setupMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                Task { await model.bootstrap() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var setupMessage: String {
        switch model.selectedProvider {
        case .cursor:
            "Couldn't find a signed-in Cursor app on this Mac. Open Cursor and sign in, then retry. Billed reads your login automatically, no setup needed."
        case .codex:
            "Couldn't find Codex local state on this Mac. Run Codex once, then retry."
        case .opencode:
            "Couldn't find Opencode local state on this Mac. Install or run Opencode once, then retry."
        case .antigravity:
            "Couldn't find Antigravity local state on this Mac. Open Antigravity and sign in, then retry."
        case .claude:
            "Couldn't find the Claude desktop app state on this Mac. Open Claude and sign in, then retry."
        }
    }
}
