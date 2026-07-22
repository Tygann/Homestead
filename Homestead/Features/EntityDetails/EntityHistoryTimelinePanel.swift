import SwiftUI

struct EntityActivityPanel<Footer: View>: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedRange: HAHistoryRangePreset = .day
    @State private var phase: EntityHistoryTimelinePhase = .idle

    let entityID: String
    let source: EntityDetailActivitySource
    let tint: Color
    let presentationMode: EntityHistoryPresentationMode
    @ViewBuilder let footer: Footer

    init(
        entityID: String,
        source: EntityDetailActivitySource,
        tint: Color,
        presentationMode: EntityHistoryPresentationMode,
        @ViewBuilder footer: () -> Footer
    ) {
        self.entityID = entityID
        self.source = source
        self.tint = tint
        self.presentationMode = presentationMode
        self.footer = footer()
    }

    var body: some View {
        EntityHistoryTimelinePanel(
            selectedRange: $selectedRange,
            phase: phase,
            tint: tint,
            presentationMode: presentationMode,
            refreshAction: refresh,
            footer: { footer }
        )
        .task(id: taskID) {
            await loadActivity()
        }
    }

    private var taskID: String {
        "\(entityID)-\(source)-\(selectedRange.rawValue)"
    }

    private func refresh() {
        Task { await loadActivity() }
    }

    @MainActor
    private func loadActivity() async {
        phase = .loading

        do {
            switch source {
            case .stateHistory:
                let interval = selectedRange.interval()
                let request = HAHistoryRequest(
                    startDate: interval.start,
                    endDate: interval.end,
                    entityID: entityID
                )
                phase = .loaded(
                    try await homeAssistantService.fetchTimeline(
                        settings: connectionSettings,
                        request: request,
                        range: selectedRange
                    )
                )
            case .automationTraces:
                phase = .loaded(
                    try await homeAssistantService.fetchAutomationTimeline(
                        entityID: entityID,
                        range: selectedRange
                    )
                )
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}

extension EntityActivityPanel where Footer == EmptyView {
    init(
        entityID: String,
        source: EntityDetailActivitySource,
        tint: Color,
        presentationMode: EntityHistoryPresentationMode = .full
    ) {
        self.init(
            entityID: entityID,
            source: source,
            tint: tint,
            presentationMode: presentationMode,
            footer: { EmptyView() }
        )
    }
}

struct EntityActivityPreview: View {
    let entityID: String
    let source: EntityDetailActivitySource
    let tint: Color
    var showsDisclosureIndicator = true

    var body: some View {
        EntityActivityPanel(
            entityID: entityID,
            source: source,
            tint: tint,
            presentationMode: .preview
        ) {
            Divider()

            NavigationLink {
                EntityActivityHistoryView(
                    entityID: entityID,
                    source: source,
                    tint: tint
                )
            } label: {
                EntityDetailNavigationRowLabel(
                    title: "Show All",
                    systemImage: "clock.arrow.circlepath",
                    showsDisclosureIndicator: showsDisclosureIndicator
                )
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }
}

struct EntityActivityHistoryPreview: View {
    let entityBox: HAEntityState
    let tint: Color

    @ViewBuilder
    var body: some View {
        if let source = EntityDetailFeatureProvider.features(for: entityBox).activitySource {
            EntityActivityPreview(
                entityID: entityBox.entityID,
                source: source,
                tint: tint
            )
        }
    }
}

private struct EntityActivityHistoryView: View {
    let entityID: String
    let source: EntityDetailActivitySource
    let tint: Color

    var body: some View {
        EntityDetailScaffold(title: "History", presentationStyle: .navigation) {
            EntityActivityPanel(
                entityID: entityID,
                source: source,
                tint: tint
            )
        }
    }
}

enum EntityHistoryTimelinePhase: Equatable {
    case idle
    case loading
    case loaded(HAHistoryTimeline)
    case failed

    var isLoading: Bool {
        if case .loading = self {
            return true
        }

        return false
    }
}

struct EntityHistoryTimelinePanel<Footer: View>: View {
    @Binding var selectedRange: HAHistoryRangePreset

    let phase: EntityHistoryTimelinePhase
    let tint: Color
    let presentationMode: EntityHistoryPresentationMode
    let refreshAction: () -> Void
    @ViewBuilder let footer: Footer

    var body: some View {
        EntityControlPanel(title: "History", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                if presentationMode == .full {
                    segmentedRangePicker
                }

                switch phase {
                case .idle, .loading:
                    loadingView
                case .loaded(let timeline):
                    if timeline.isEmpty {
                        unavailableView(timeline.summaryText)
                    } else {
                        timelineList(timeline)
                    }
                case .failed:
                    unavailableView("History unavailable", showsRetry: true)
                }

                footer
            }
        }
    }

    private var segmentedRangePicker: some View {
        Picker("Activity range", selection: $selectedRange) {
            ForEach(HAHistoryRangePreset.activityPresets) { range in
                Text(range.title)
                    .tag(range)
                    .accessibilityLabel(range.accessibilityTitle)
            }
        }
        .pickerStyle(.segmented)
        .disabled(phase.isLoading)
        .accessibilityLabel("Activity range")
    }

    private var loadingView: some View {
        HStack(spacing: AppSpacing.medium) {
            ProgressView()
                .frame(width: 32, height: 32)

            Text("Loading activity")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func timelineList(_ timeline: HAHistoryTimeline) -> some View {
        let maximumEntryCount = presentationMode == .preview ? 3 : 8
        let entries = Array(timeline.entries.suffix(maximumEntryCount).reversed())

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    timelineRow(entry, showsConnector: index < entries.count - 1)
                }
            }

            timelineFooter(timeline, visibleCount: entries.count)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(timeline.displayName) activity")
        .accessibilityValue(timeline.summaryText)
    }

    @ViewBuilder
    private func timelineFooter(_ timeline: HAHistoryTimeline, visibleCount: Int) -> some View {
        let hiddenCount = timeline.entries.count - visibleCount

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                summaryText(timeline.summaryText)

                Spacer(minLength: AppSpacing.small)

                if hiddenCount > 0 {
                    hiddenCountText(hiddenCount)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                summaryText(timeline.summaryText)

                if hiddenCount > 0 {
                    hiddenCountText(hiddenCount)
                }
            }
        }
    }

    private func timelineRow(_ entry: HAHistoryTimelineEntry, showsConnector: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(spacing: 0) {
                HomesteadIconView(icon: entry.resolvedIcon, pointSize: 12, weight: .bold)
                    .foregroundStyle(timelineToneColor(entry.tone))
                    .frame(width: 28, height: 28)
                    .background(timelineToneColor(entry.tone).opacity(0.12), in: Circle())

                if showsConnector {
                    Rectangle()
                        .fill(Color(.tertiaryLabel).opacity(0.3))
                        .frame(width: 2, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.bottom, showsConnector ? AppSpacing.small : 0)
            Spacer(minLength: AppSpacing.small)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title), \(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))")
    }

    private func unavailableView(_ message: String, showsRetry: Bool = false) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if showsRetry {
                Button("Retry") {
                    refreshAction()
                }
                .buttonStyle(.bordered)
                .disabled(phase.isLoading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func summaryText(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func hiddenCountText(_ count: Int) -> some View {
        Text("+\(count)")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }

    private func timelineToneColor(_ tone: HAHistoryTimelineTone) -> Color {
        switch tone {
        case .active:
            tint
        case .inactive:
            .secondary
        case .unavailable:
            .red
        }
    }
}

#if DEBUG
private struct EntityHistoryTimelinePreviewGallery: View {
    @State private var selectedRange: HAHistoryRangePreset = .day
    let tint: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                ForEach(Self.timelines, id: \.entityID) { timeline in
                    EntityHistoryTimelinePanel(
                        selectedRange: $selectedRange,
                        phase: .loaded(timeline),
                        tint: tint,
                        presentationMode: .full,
                        refreshAction: {},
                        footer: { EmptyView() }
                    )
                }
            }
            .padding(AppSpacing.large)
        }
        .frame(width: 320)
        .background(Color(.systemGroupedBackground))
    }

    private static let baseDate = Date(timeIntervalSince1970: 1_782_949_600)

    private static let timelines: [HAHistoryTimeline] = [
        HAHistoryTimeline(
            entityID: "binary_sensor.front_door",
            displayName: "Front Door",
            range: .day,
            entries: [
                entry(minutesAgo: 210, state: "off", title: "Closed", systemImage: "door.left.hand.closed", tone: .inactive),
                entry(minutesAgo: 24, state: "on", title: "Opened", systemImage: "door.left.hand.open", tone: .active)
            ]
        ),
        HAHistoryTimeline(
            entityID: "lock.front_door",
            displayName: "Front Door Lock",
            range: .day,
            entries: [
                entry(minutesAgo: 180, state: "locked", title: "Locked", systemImage: "lock.fill", tone: .inactive),
                entry(minutesAgo: 42, state: "unlocked", title: "Unlocked", systemImage: "lock.open.fill", tone: .active)
            ]
        ),
        HAHistoryTimeline(
            entityID: "switch.coffee_maker",
            displayName: "Coffee Maker",
            range: .day,
            entries: [
                entry(minutesAgo: 145, state: "on", title: "Turned On", systemImage: "lightswitch.on.fill", tone: .active),
                entry(minutesAgo: 128, state: "off", title: "Turned Off", systemImage: "lightswitch.off.fill", tone: .inactive)
            ]
        ),
        HAHistoryTimeline(
            entityID: "automation.good_night",
            displayName: "Good Night",
            range: .day,
            entries: [
                entry(minutesAgo: 95, state: "off", title: "Disabled", systemImage: "calendar", tone: .inactive),
                entry(minutesAgo: 72, state: "on", title: "Enabled", systemImage: "calendar.badge.clock", tone: .active)
            ]
        ),
        HAHistoryTimeline(
            entityID: "cover.primary_shades",
            displayName: "Primary Shades",
            range: .day,
            entries: [
                entry(minutesAgo: 75, state: "opening", title: "Opening", systemImage: "blinds.horizontal.open", tone: .active),
                entry(minutesAgo: 74, state: "open", title: "Opened", systemImage: "blinds.horizontal.open", tone: .active)
            ]
        ),
        HAHistoryTimeline(
            entityID: "person.tyler",
            displayName: "Tyler",
            range: .day,
            entries: [
                entry(minutesAgo: 64, state: "not_home", title: "Away", systemImage: "person", tone: .inactive),
                entry(minutesAgo: 22, state: "work", title: "At Work", systemImage: "mappin.and.ellipse", tone: .active)
            ]
        ),
        HAHistoryTimeline(
            entityID: "device_tracker.phone",
            displayName: "Phone",
            range: .day,
            entries: [
                entry(minutesAgo: 55, state: "home", title: "Home", systemImage: "location.fill", tone: .active),
                entry(minutesAgo: 14, state: "not_home", title: "Away", systemImage: "location", tone: .inactive)
            ]
        )
    ]

    private static func entry(
        minutesAgo: TimeInterval,
        state: String,
        title: String,
        systemImage: String,
        tone: HAHistoryTimelineTone
    ) -> HAHistoryTimelineEntry {
        HAHistoryTimelineEntry(
            occurredAt: baseDate.addingTimeInterval(-minutesAgo * 60),
            state: state,
            title: title,
            systemImage: systemImage,
            tone: tone
        )
    }
}

#Preview("History Small Light") {
    EntityHistoryTimelinePreviewGallery(tint: .accentColor)
        .withPreviewAccentColor()
}

#Preview("History Small Dark") {
    EntityHistoryTimelinePreviewGallery(tint: .accentColor)
        .withPreviewAccentColor()
        .preferredColorScheme(.dark)
}
#endif
