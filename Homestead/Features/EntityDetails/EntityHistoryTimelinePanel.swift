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

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                Text(timeline.summaryText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: AppSpacing.small)

                if timeline.entries.count > entries.count {
                    Text("+\(timeline.entries.count - entries.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(timeline.displayName) activity")
        .accessibilityValue(timeline.summaryText)
    }

    private func timelineRow(_ entry: HAHistoryTimelineEntry, showsConnector: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(spacing: AppSpacing.xSmall) {
                Image(systemName: entry.systemImage)
                    .font(.caption.weight(.bold))
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

                Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
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
