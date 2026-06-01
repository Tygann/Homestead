import SwiftUI

struct CoverDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var position = 100.0
    @State private var isEditingPosition = false

    let entityBox: HAEntityState

    var body: some View {
        NavigationStack {
            if let cover = entityBox.coverEntity {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        coverStatusCard(cover)
                        movementControls(cover)

                        if cover.positionPercentage != nil,
                           homeAssistantService.serviceActionAvailable(domain: "cover", service: "set_cover_position") {
                            positionControls(cover)
                        }
                    }
                    .padding(AppSpacing.large)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Cover")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", role: .close) {
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    syncPosition(with: cover)
                }
                .onChange(of: cover.position) { _, _ in
                    guard !isEditingPosition else { return }
                    syncPosition(with: cover)
                }
            } else {
                ContentUnavailableView("Cover Unavailable", systemImage: "blinds.horizontal.closed")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func coverStatusCard(_ cover: CoverEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                Image(systemName: cover.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(cover.isOpen ? Color.accentColor : Color.secondary)
                    .frame(width: 64, height: 64)
                    .background(cover.isOpen ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Spacer()

                Text(statusBadgeText(for: cover))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(cover.isOpen ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(cover.isOpen ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground), in: Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(cover.displayName)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(cover.displaySubtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func movementControls(_ cover: CoverEntity) -> some View {
        let isPending = entityBox.pendingCommand != nil

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(spacing: AppSpacing.small) {
                Button {
                    Task { await homeAssistantService.openCover(entityID: entityBox.entityID) }
                } label: {
                    Label("Open", systemImage: "arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPending || cover.state == "open" || !homeAssistantService.serviceActionAvailable(domain: "cover", service: "open_cover"))

                Button {
                    Task { await homeAssistantService.closeCover(entityID: entityBox.entityID) }
                } label: {
                    Label("Close", systemImage: "arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .disabled(isPending || cover.state == "closed" || !homeAssistantService.serviceActionAvailable(domain: "cover", service: "close_cover"))
            }

            Button {
                Task { await homeAssistantService.stopCover(entityID: entityBox.entityID) }
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.bordered)
            .disabled(isPending || !homeAssistantService.serviceActionAvailable(domain: "cover", service: "stop_cover"))
        }
        .controlSize(.large)
    }

    private func positionControls(_ cover: CoverEntity) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack {
                Label("Position", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Spacer()

                Text("\(Int(position))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(cover.isOpen ? Color.accentColor : Color.secondary)
            }

            Slider(
                value: $position,
                in: 0...100,
                step: 1,
                onEditingChanged: { editing in
                    isEditingPosition = editing
                    guard !editing else { return }

                    Task {
                        await homeAssistantService.setCoverPosition(
                            entityID: entityBox.entityID,
                            position: position
                        )
                    }
                }
            )
            .disabled(entityBox.pendingCommand != nil)
            .accessibilityLabel("Cover position")
            .accessibilityValue("\(Int(position)) percent")

            Text("Position is reported by Home Assistant when this cover supports it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func statusBadgeText(for cover: CoverEntity) -> String {
        if let position = cover.positionPercentage {
            return "\(position)%"
        }

        return cover.displayState
    }

    private func syncPosition(with cover: CoverEntity) {
        position = Double(cover.positionPercentage ?? 100)
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "cover.primary_shades") {
        CoverDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
