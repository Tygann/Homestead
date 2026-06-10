import SwiftUI
import UIKit

struct PeoplePresenceAvatarStackView: View {
    let records: [HAPresenceRecord]
    var size: CGFloat = 38

    private let visibleCount = 3

    var body: some View {
        let visibleRecords = Array(records.prefix(visibleCount))

        HStack(spacing: -size * 0.36) {
            ForEach(Array(visibleRecords.enumerated()), id: \.element.entityID) { index, record in
                PeoplePresenceAvatarView(record: record, size: size)
                    .overlay {
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    }
                    .zIndex(Double(visibleCount - index))
            }

            if visibleRecords.isEmpty {
                Image(systemName: "person.3.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(Color.secondary.opacity(0.16), in: Circle())
            }
        }
        .frame(height: size)
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

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let uiImage = UIImage(data: data) else {
                image = nil
                return
            }
            image = Image(uiImage: uiImage)
        } catch {
            image = nil
        }
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
