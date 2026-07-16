import SwiftUI

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

struct EntityHistoryTimelinePanel: View {
    @Binding var selectedRange: HAHistoryRangePreset

    let phase: EntityHistoryTimelinePhase
    let tint: Color
    let refreshAction: () -> Void

    var body: some View {
        EntityControlPanel(title: "Recent Activity", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                rangePicker

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
                    unavailableView("Activity unavailable")
                }
            }
        }
    }

    private var rangePicker: some View {
        ViewThatFits(in: .horizontal) {
            horizontalRangePicker
            compactRangePicker
        }
    }

    private var horizontalRangePicker: some View {
        HStack(spacing: AppSpacing.small) {
            rangeButtons
            refreshButton
        }
    }

    private var compactRangePicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            rangeButtons

            refreshButton
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var rangeButtons: some View {
        HStack(spacing: AppSpacing.small) {
            ForEach(HAHistoryRangePreset.allCases) { range in
                EntityDetailPillButton(
                    title: range.title,
                    isSelected: selectedRange == range,
                    isDisabled: phase.isLoading,
                    tint: tint
                ) {
                    selectedRange = range
                }
                .accessibilityLabel(range.accessibilityTitle)
            }
        }
    }

    private var refreshButton: some View {
        Button {
            refreshAction()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(phase.isLoading)
        .accessibilityLabel("Refresh activity")
    }

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: 132)
                .overlay {
                    ProgressView()
                }

            Text("Loading activity")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func timelineList(_ timeline: HAHistoryTimeline) -> some View {
        let entries = Array(timeline.entries.suffix(8).reversed())

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

    private func unavailableView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: 112)
                .overlay {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
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
                        tint: tint
                    ) {}
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

#Preview("Recent Activity Small Light") {
    EntityHistoryTimelinePreviewGallery(tint: .accentColor)
        .withPreviewAccentColor()
}

#Preview("Recent Activity Small Dark") {
    EntityHistoryTimelinePreviewGallery(tint: .accentColor)
        .withPreviewAccentColor()
        .preferredColorScheme(.dark)
}
#endif
