import SwiftUI
import WidgetKit

nonisolated enum HomesteadWidgetPlusAccess {
    static func isGranted(now: Date = .now, defaults: UserDefaults? = nil) -> Bool {
        HomesteadPlusEntitlementCache.snapshot(defaults: defaults)
            .grantsExtensionAccess(now: now)
    }
}

nonisolated enum HomesteadWidgetPlusPolicy {
    static func allowsSensorDisplay(
        _ display: HomesteadSensorWidgetDisplay,
        hasPlus: Bool
    ) -> Bool {
        hasPlus || display == .reading
    }

    static func allowsSensorBoard(hasPlus: Bool) -> Bool {
        hasPlus
    }
}

struct HomesteadPlusWidgetLockView: View {
    @Environment(\.widgetFamily) private var family
    private let previewFamily: WidgetFamily?

    init(previewFamily: WidgetFamily? = nil) {
        self.previewFamily = previewFamily
    }

    var body: some View {
        Group {
            if resolvedFamily == .accessoryCircular {
                Image(systemName: "lock.fill")
                    .widgetLabel("Plus")
            } else if resolvedFamily == .accessoryRectangular {
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

    private var resolvedFamily: WidgetFamily {
        previewFamily ?? family
    }
}
