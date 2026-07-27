import SwiftUI
import WidgetKit

nonisolated enum HomesteadWidgetPlusAccess {
    static func isGranted(now: Date = .now, defaults: UserDefaults? = nil) -> Bool {
        HomesteadPlusEntitlementCache.snapshot(defaults: defaults)
            .grantsExtensionAccess(now: now)
    }
}

struct HomesteadPlusWidgetLockView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .accessoryCircular {
                Image(systemName: "lock.fill")
                    .widgetLabel("Plus")
            } else if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Homestead+")
                        .font(.headline)
                    Text("Open Homestead")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    Text("Homestead+")
                        .font(.headline)
                    Text("Open Homestead to restore access.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .widgetURL(HomesteadWidgetDeepLink.plusURL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Homestead Plus required. Open Homestead to restore access.")
    }
}
