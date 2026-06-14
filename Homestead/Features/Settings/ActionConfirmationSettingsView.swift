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
                .pickerStyle(.navigationLink)

                HStack {
                    Text("Behavior")
                    Spacer()
                    Text(settings.mode.summary)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Toggle("Unlocking Locks", isOn: $settings.confirmsLockUnlocks)
                Toggle("Opening Security Covers", isOn: $settings.confirmsSecurityCoverOpens)
                Toggle("Activating Scenes", isOn: $settings.confirmsScenes)
                Toggle("Running Scripts", isOn: $settings.confirmsScripts)
                Toggle("Other Impactful Actions", isOn: $settings.confirmsOtherImpactfulActions)
            } header: {
                Text("Smart Confirmations")
            } footer: {
                Text("Smart Confirmations keeps everyday controls fast while asking before actions that may unlock, open, or trigger larger changes.")
            }
        }
        .navigationTitle("Action Confirmations")
        .toolbarTitleDisplayMode(.inline)
    }
}
