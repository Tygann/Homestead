import SwiftUI

struct TabsSettingsView: View {
    @Environment(HomesteadTabSettings.self) private var tabSettings

    var body: some View {
        @Bindable var tabSettings = tabSettings

        Form {
            Section {
                Picker("Primary Tab", selection: $tabSettings.primaryTab) {
                    ForEach(HomesteadPrimaryTab.allCases) { tab in
                        Label(tab.displayName, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
            } footer: {
                Text("Browse stays separate.")
            }
        }
        .navigationTitle("Tabs")
        .toolbarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TabsSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
