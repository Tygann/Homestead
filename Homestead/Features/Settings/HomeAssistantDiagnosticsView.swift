import SwiftUI
import UIKit

// MARK: - Support And Diagnostics View

struct HomeAssistantDiagnosticsView: View {
    // MARK: - Properties

    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var didCopyDiagnostics = false

    // MARK: - Body

    var body: some View {
        let presentation = HomeAssistantSupportPresentation(
            connectionSettings: connectionSettings,
            homeAssistantService: homeAssistantService
        )

        Form {
            copySection(presentation)
            connectionSection(presentation)
            backgroundServicesSection(presentation)
            recentDataSection(presentation)
        }
        .navigationTitle("Support & Diagnostics")
        .toolbarTitleDisplayMode(.inline)
        .onChange(of: presentation.clipboardText) { _, _ in
            didCopyDiagnostics = false
        }
    }

    // MARK: - Sections

    private func copySection(_ presentation: HomeAssistantSupportPresentation) -> some View {
        Section {
            Button {
                UIPasteboard.general.string = presentation.clipboardText
                didCopyDiagnostics = true
                HapticFeedback.selection()
            } label: {
                Label(
                    didCopyDiagnostics ? "Diagnostics Copied" : "Copy Diagnostics",
                    systemImage: didCopyDiagnostics ? "checkmark.circle.fill" : "doc.on.doc"
                )
            }
            .accessibilityHint("Copies a privacy-safe support summary without tokens or cache file paths.")
        } footer: {
            Text("Use this when sharing details for support. Tokens and exact cache paths are not included.")
        }
    }

    private func connectionSection(_ presentation: HomeAssistantSupportPresentation) -> some View {
        Section("Connection") {
            ForEach(presentation.connectionRows) { row in
                LabeledContent(row.label, value: row.value)
            }

            if let mismatchWarning = presentation.mismatchWarning {
                Label {
                    Text(mismatchWarning)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .accessibilityLabel("Server mismatch. \(mismatchWarning)")
            }
        }
    }

    private func backgroundServicesSection(_ presentation: HomeAssistantSupportPresentation) -> some View {
        Section("Background Services") {
            ForEach(presentation.backgroundRows) { row in
                LabeledContent(row.label, value: row.value)
            }

            if let detail = presentation.backgroundDetail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let actionTitle = presentation.registrationActionTitle {
                Button(actionTitle) {
                    Task {
                        await homeAssistantService.registerMobileApp(settings: connectionSettings)
                    }
                }
                .disabled(!presentation.isRegistrationActionEnabled)
            }
        }
    }

    private func recentDataSection(_ presentation: HomeAssistantSupportPresentation) -> some View {
        Section("Recent Data") {
            ForEach(presentation.recentDataRows) { row in
                LabeledContent(row.label, value: row.value)
            }
        }
    }
}

#if DEBUG
#Preview("Support & Diagnostics — Healthy") {
    NavigationStack {
        HomeAssistantDiagnosticsView()
    }
    .withPreviewEnvironment(.settingsSample(.healthy))
}

#Preview("Support & Diagnostics — Degraded") {
    NavigationStack {
        HomeAssistantDiagnosticsView()
    }
    .withPreviewEnvironment(.settingsSample(.degraded))
}
#endif
