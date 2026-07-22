import SwiftUI

struct DashboardCardIdentityEditing {
    let displayName: Binding<String>
    let editIcon: () -> Void
    let commitDisplayName: () -> Void
}

private struct DashboardCardIdentityEditingKey: EnvironmentKey {
    static let defaultValue: DashboardCardIdentityEditing? = nil
}

extension EnvironmentValues {
    var dashboardCardIdentityEditing: DashboardCardIdentityEditing? {
        get { self[DashboardCardIdentityEditingKey.self] }
        set { self[DashboardCardIdentityEditingKey.self] = newValue }
    }
}

extension View {
    func dashboardCardEditableTitle() -> some View {
        modifier(DashboardCardEditableTitleModifier())
    }

    func dashboardCardEditableIcon() -> some View {
        modifier(DashboardCardEditableIconModifier())
    }
}

private struct DashboardCardEditableTitleModifier: ViewModifier {
    @Environment(\.dashboardCardIdentityEditing) private var identityEditing

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identityEditing {
            TextField("Card Name", text: identityEditing.displayName)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit(identityEditing.commitDisplayName)
                .accessibilityLabel("Card name")
        } else {
            content
        }
    }
}

private struct DashboardCardEditableIconModifier: ViewModifier {
    @Environment(\.dashboardCardIdentityEditing) private var identityEditing

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identityEditing {
            Button(action: identityEditing.editIcon) {
                content
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change card icon")
            .accessibilityHint("Opens the icon picker")
        } else {
            content
        }
    }
}
