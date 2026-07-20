import SwiftUI

struct PresenceDetailView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }

    var body: some View {
        if let record = stateStore.presenceRecord(for: entity.entityID) {
            EntityDetailScaffold(title: record.displayName, presentationStyle: presentationStyle) {
                hero(record)

                if !detailRows(for: record).isEmpty {
                    DashboardEntityContextPanel(
                        title: "Presence Details",
                        systemImage: "location.fill",
                        rows: detailRows(for: record)
                    )
                }

                relationships(record)

                EntityActivityPanel(
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
                systemImage: entity.domain == .person ? "person.crop.circle.badge.exclamationmark" : "location.slash",
                presentationStyle: presentationStyle
            )
        }
    }

    // MARK: - Sections

    private func hero(_ record: HAPresenceRecord) -> some View {
        EntityDetailHeroCard(
            icon: record.resolvedIcon,
            title: EntityCapabilityRegistry.profile(for: record.domain).categoryTitle,
            subtitle: EntityDetailHeroSubtitle.updated(entity),
            status: nil,
            iconColor: record.status.tint,
            statePresentation: detailState
        ) {
            HStack(alignment: .center, spacing: AppSpacing.large) {
                PeoplePresenceAvatarView(record: record, size: 88)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(record.status.title)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(record.status.tint)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    if let contextSummary = heroContext(for: record) {
                        Text(contextSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(record.displayName), \(record.status.title)")
        }
    }

    @ViewBuilder
    private func relationships(_ record: HAPresenceRecord) -> some View {
        if record.isPerson {
            EntityDetailSection(title: "Source Tracker", systemImage: "location.circle.fill") {
                if record.linkedTrackers.isEmpty {
                    Label("No active source tracker", systemImage: "location.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    ForEach(record.linkedTrackers) { tracker in
                        relatedEntityLink(
                            entityID: tracker.entityID,
                            title: tracker.displayName,
                            subtitle: trackerSubtitle(tracker),
                            systemImage: tracker.status.systemImage,
                            tint: tracker.status.tint
                        )
                    }
                }
            }
        } else if let linkedPersonEntityID = record.linkedPersonEntityID,
                  let linkedPersonName = record.linkedPersonName {
            EntityDetailSection(title: "Person", systemImage: "person.fill") {
                relatedEntityLink(
                    entityID: linkedPersonEntityID,
                    title: linkedPersonName,
                    subtitle: "Uses this tracker",
                    systemImage: "person.fill",
                    tint: .accentColor
                )
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
                EntityDetailSheet(entityBox: relatedEntityBox, presentationStyle: .navigation)
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
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
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
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Presentation

    private func detailRows(for record: HAPresenceRecord) -> [EntityMetadataRow] {
        var rows: [EntityMetadataRow] = []

        if let sourceTypeTitle = record.sourceTypeTitle {
            rows.append(EntityMetadataRow(title: "Tracking", value: sourceTypeTitle))
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

    private func trackerSubtitle(_ tracker: HAPresenceTrackerSummary) -> String {
        tracker.subtitle == tracker.entityID ? tracker.status.title : tracker.subtitle
    }

    private func heroContext(for record: HAPresenceRecord) -> String? {
        if record.isPerson, let tracker = record.linkedTrackers.first {
            return "Reported by \(tracker.displayName)"
        }
        if let linkedPersonName = record.linkedPersonName {
            return "Tracker for \(linkedPersonName)"
        }
        return record.sourceTypeTitle
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
