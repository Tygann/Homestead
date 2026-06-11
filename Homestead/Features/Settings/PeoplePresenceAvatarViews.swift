import SwiftUI
import UIKit

struct PeoplePresenceAvatarStackView: View {
    let records: [HAPresenceRecord]
    var size: CGFloat = 38
    var width: CGFloat?
    var maximumVisibleCount: Int? = 3

    var body: some View {
        let visibleRecords = Array(records.prefix(maximumVisibleCount ?? records.count))
        let overlap = avatarOverlap(for: visibleRecords.count)
        let contentWidth = intrinsicWidth(for: visibleRecords.count, overlap: overlap)
        let stackWidth = width ?? contentWidth
        let stackAlignment: Alignment = visibleRecords.count <= 1 ? .center : .leading

        HStack(spacing: -overlap) {
            ForEach(Array(visibleRecords.enumerated()), id: \.element.entityID) { index, record in
                PeoplePresenceAvatarView(record: record, size: size)
                    .zIndex(Double(visibleRecords.count - index))
            }

            if visibleRecords.isEmpty {
                Image(systemName: "person.3.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(Color.secondary.opacity(0.16), in: Circle())
            }
        }
        .frame(width: contentWidth, height: size, alignment: .leading)
        .frame(width: stackWidth, height: size, alignment: stackAlignment)
    }

    private func avatarOverlap(for count: Int) -> CGFloat {
        guard count > 1 else {
            return 0
        }

        let minimumOverlap = size * 0.18
        guard let width else {
            return minimumOverlap
        }

        let fitOverlap = size - ((width - size) / CGFloat(count - 1))
        return max(minimumOverlap, fitOverlap)
    }

    private func intrinsicWidth(for count: Int, overlap: CGFloat) -> CGFloat {
        guard count > 0 else {
            return size
        }

        return size + CGFloat(count - 1) * (size - overlap)
    }
}

struct PeoplePresenceAvatarView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var image: Image?

    let record: HAPresenceRecord
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: record.iconSystemName)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(record.status.tint)
                    .frame(width: size, height: size)
                    .background(record.status.tint.opacity(0.12), in: Circle())
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: taskID) {
            await loadImage()
        }
        .accessibilityHidden(true)
    }

    private var taskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title,
            record.entityPicturePath ?? "no-picture"
        ].joined(separator: "|")
    }

    private func loadImage() async {
        guard let entityPicturePath = record.entityPicturePath,
              let request = await homeAssistantService.homeAssistantImageRequest(
                settings: connectionSettings,
                pathOrURL: entityPicturePath
              ) else {
            image = nil
            return
        }

        guard let uiImage = await HomeAssistantImageCache.shared.image(for: request) else {
            image = nil
            return
        }

        image = Image(uiImage: uiImage)
    }
}

extension HAPresenceStatus {
    var tint: Color {
        switch self {
        case .home:
            return .green
        case .zone:
            return .accentColor
        case .away:
            return .secondary
        case .unknown:
            return .orange
        case .unavailable:
            return .red
        }
    }
}
