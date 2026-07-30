import SwiftUI

// MARK: - Action Confirmation Settings View
struct ActionConfirmationSettingsView: View {
    @Environment(ActionConfirmationSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("Mode", selection: $settings.mode) {
                    ForEach(ActionConfirmationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            } footer: {
                Text(settings.mode.summary)
            }

            if settings.mode == .smart {
                Section {
                    Toggle("Unlocking Locks", isOn: $settings.confirmsLockUnlocks)
                    Toggle("Opening Security Covers", isOn: $settings.confirmsSecurityCoverOpens)
                    Toggle("Activating Scenes", isOn: $settings.confirmsScenes)
                    Toggle("Running Scripts", isOn: $settings.confirmsScripts)
                    Toggle("Other Impactful Actions", isOn: $settings.confirmsOtherImpactfulActions)
                } header: {
                    Text("Confirm Before")
                } footer: {
                    Text("Choose which sensitive actions ask for confirmation.")
                }
            }
        }
        .navigationTitle("Safety")
        .toolbarTitleDisplayMode(.inline)
    }
}
