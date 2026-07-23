import SwiftUI

struct PresenceDetailView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.homesteadEntityDetailSurfaceContext) private var surfaceContext

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }

    var body: some View {
        if entity.domain == .person {
            PersonPresenceDetailView(
                entityID: entity.entityID,
                presentationStyle: presentationStyle
            )
        } else if let record = stateStore.presenceRecord(for: entity.entityID) {
            EntityDetailScaffold(title: record.displayName, presentationStyle: presentationStyle) {
                identityHeader(record)
                trackerLocationSection(record)

                EntityActivityPreview(
                    entityID: record.entityID,
                    source: .stateHistory,
                    tint: record.status.tint
                )

                EntityMetadataDisclosure(
                    entityBox: entityBox,
                    title: "Home Assistant",
                    systemImage: "house.and.flag",
                    rows: []
                )
            }
        } else {
            EntityUnavailableDetailView(
                title: entity.displayName,
                systemImage: "location.slash",
                presentationStyle: presentationStyle
            )
        }
    }

    // MARK: - Sections

    private func identityHeader(_ record: HAPresenceRecord) -> some View {
        VStack(spacing: AppSpacing.medium) {
            PeoplePresenceAvatarView(record: record, size: 104)

            VStack(spacing: AppSpacing.xSmall) {
                Label {
                    Text(record.status.title)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: record.status.systemImage)
                        .foregroundStyle(record.status.tint)
                }
                .font(.title2.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

                if let subtitle = EntityDetailHeroSubtitle.updated(entity) {
                    subtitle
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let status = detailState.status,
               detailState.operationalState != .unavailable {
                Text(status.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.tone.foregroundColor)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(status.tone.backgroundColor, in: Capsule())
            }

            if let message = detailState.message {
                EntityDetailStateMessage(
                    state: detailState.operationalState,
                    message: message
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.displayName), \(record.status.title)")
    }

    private func trackerLocationSection(_ record: HAPresenceRecord) -> some View {
        EntityDetailSection(title: "Tracking", systemImage: "location.fill") {
            if let linkedPersonEntityID = record.linkedPersonEntityID,
               let linkedPersonName = record.linkedPersonName {
                relatedEntityLink(
                    entityID: linkedPersonEntityID,
                    title: linkedPersonName,
                    subtitle: "Person using this tracker",
                    systemImage: "person.fill",
                    tint: .secondary
                )
            }

            let rows = trackingRows(for: record)
            if !rows.isEmpty {
                if record.linkedPersonEntityID != nil {
                    Divider()
                }
                ForEach(rows) { row in
                    row
                }
            }
        }
    }

    @ViewBuilder
    private func relatedEntityLink(
        entityID: String,
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        if let relatedEntityBox = stateStore.entityBox(for: entityID) {
            NavigationLink {
                EntityDetailDestinationView(
                    destination: EntityDetailDestination(
                        entityID: relatedEntityBox.entityID,
                        surfaceContext: surfaceContext
                    )
                )
            } label: {
                relatedEntityLabel(
                    title: title,
                    subtitle: subtitle,
                    systemImage: systemImage,
                    tint: tint,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        } else {
            relatedEntityLabel(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint,
                showsChevron: false
            )
        }
    }

    private func relatedEntityLabel(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: AppSpacing.small)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Presentation

    private func trackingRows(for record: HAPresenceRecord) -> [EntityMetadataRow] {
        var rows: [EntityMetadataRow] = []

        if let sourceTypeTitle = record.sourceTypeTitle {
            rows.append(EntityMetadataRow(title: "Method", value: sourceTypeTitle))
        }
        if let gpsAccuracyText = record.gpsAccuracyText {
            rows.append(EntityMetadataRow(title: "Accuracy", value: gpsAccuracyText))
        }
        if let batteryText = record.batteryText {
            rows.append(EntityMetadataRow(title: "Battery", value: batteryText))
        }
        if let deviceName = record.context.deviceName {
            rows.append(EntityMetadataRow(title: "Device", value: deviceName))
        }

        return rows
    }

}

#if DEBUG
#Preview("Person Presence") {
    let dependencies = PreviewDependencies.sample
    if let entityBox = dependencies.stateStore.entityBox(for: "person.tyler") {
        NavigationStack {
            PresenceDetailView(entityBox: entityBox, presentationStyle: .navigation)
        }
        .withPreviewEnvironment(dependencies)
    }
}

#Preview("Device Tracker") {
    let dependencies = PreviewDependencies.sample
    if let entityBox = dependencies.stateStore.entityBox(for: "device_tracker.tylers_iphone") {
        NavigationStack {
            PresenceDetailView(entityBox: entityBox, presentationStyle: .navigation)
        }
        .withPreviewEnvironment(dependencies)
    }
}
#endif
