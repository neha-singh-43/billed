import BilledCore
import SwiftUI

extension ServiceProvider {
    var logoImage: Image {
        let name = switch self {
        case .cursor: "cursor"
        case .codex: "codex"
        case .antigravity: "antigravity"
        case .opencode: "opencode"
        case .claude: "claude"
        }
        guard let url = Bundle.module.url(forResource: "Logos/\(name)", withExtension: "svg"),
              let data = try? Data(contentsOf: url),
              let nsImage = NSImage(data: data)
        else {
            return Image(systemName: iconName)
        }
        nsImage.size = NSSize(width: 16, height: 16)
        return Image(nsImage: nsImage)
    }
}
