import BilledCore
import SwiftUI

@main
struct BilledApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            // Give the panel an explicit height: in a `.window`-style
            // MenuBarExtra the content only gets a fixed width, so the flexible
            // ScrollView would otherwise collapse to zero height (blank panel) on
            // recent macOS. A fixed height lets the ScrollView lay out and scroll.
            PanelView(model: model)
                .frame(width: 360, height: 560)
        } label: {
            MenuBarLabelView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabelView: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            if case .stale = model.loadState {
                Circle()
                    .fill(.orange)
                    .frame(width: 5, height: 5)
            }
            Text(model.menuBarLabel)
                .monospacedDigit()
        }
        .foregroundStyle(labelColor)
        .accessibilityLabel(menuBarAccessibilityLabel)
    }

    private var menuBarAccessibilityLabel: String {
        "Usage, \(model.menuBarLabel)"
    }

    private var iconName: String {
        switch model.loadState {
        case .needsSetup, .error: "exclamationmark.triangle.fill"
        case .stale: "chart.line.uptrend.xyaxis"
        default: "sparkles"
        }
    }

    private var labelColor: Color {
        switch model.loadState {
        case .stale: .secondary
        case .error, .needsSetup: .orange
        default: .primary
        }
    }
}
