import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CameraDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var snapshotPhase: SnapshotPhase = .idle

    let entityBox: HAEntityState

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    statusCard
                    snapshotPanel
                    contextDetails
                }
                .padding(AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Camera")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadSnapshot() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!entity.isAvailable || snapshotPhase.isLoading)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: entity.entityID) {
            await loadSnapshot()
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                Image(systemName: presentation.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 64, height: 64)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Spacer()

                Text(presentation.subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(statusBackground, in: Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(statusSummary)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var snapshotPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Preview", systemImage: "camera.viewfinder")
                .font(.headline)

            snapshotContent
                .frame(maxWidth: .infinity)
                .frame(minHeight: 172)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    @ViewBuilder
    private var snapshotContent: some View {
        switch snapshotPhase {
        case .idle, .loading:
            ProgressView()
                .controlSize(.large)
        case .loaded(let data):
            #if canImport(UIKit)
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 172)
            } else {
                unavailableSnapshotContent
            }
            #else
            unavailableSnapshotContent
            #endif
        case .failed:
            unavailableSnapshotContent
        }
    }

    private var unavailableSnapshotContent: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Snapshot unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var contextDetails: some View {
        DashboardEntityContextPanel(
            title: "Home Assistant",
            systemImage: "camera",
            rows: [
                DashboardEntityDetailRow(title: "Entity ID", value: entity.entityID),
                DashboardEntityDetailRow(title: "Domain", value: entity.domain.displayName),
                DashboardEntityDetailRow(title: "State", value: entity.state.displayStateText)
            ]
        )
    }

    private var statusSummary: String {
        guard entity.isAvailable else { return "Camera unavailable" }
        return "Available"
    }

    private var iconColor: Color {
        entity.isAvailable ? presentation.accentColor : .secondary
    }

    private var statusColor: Color {
        entity.isAvailable ? presentation.accentColor : .red
    }

    private var iconBackground: Color {
        entity.isAvailable ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var statusBackground: Color {
        entity.isAvailable ? presentation.accentColor.opacity(0.12) : Color.red.opacity(0.12)
    }

    private func loadSnapshot() async {
        guard entity.isAvailable else {
            snapshotPhase = .failed
            return
        }

        snapshotPhase = .loading
        do {
            snapshotPhase = .loaded(try await homeAssistantService.fetchCameraSnapshot(entityID: entity.entityID))
        } catch {
            snapshotPhase = .failed
        }
    }
}

private enum SnapshotPhase: Equatable {
    case idle
    case loading
    case loaded(Data)
    case failed

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "camera.driveway") {
        CameraDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
