import SwiftUI

struct DeviceEntityStateAccessory: View {
    let entityBox: HAEntityState

    var body: some View {
        if let detailText {
            DeviceEntityDetailSlot(
                detailText: detailText,
                isAvailable: entityBox.homeEntity.isAvailable
            )
        }
    }

    private var detailText: String? {
        let entity = entityBox.homeEntity

        guard entity.isAvailable else {
            return "Unavailable"
        }

        if let sensor = entityBox.sensorEntity {
            return conciseDetail(sensor.formattedValue)
        }

        return conciseDetail(
            entity.state
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        )
    }

    private func conciseDetail(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private struct DeviceEntityDetailSlot: View {
    let detailText: String
    let isAvailable: Bool

    var body: some View {
        Text(detailText)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(isAvailable ? .secondary : Color.red)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .truncationMode(.tail)
            .frame(width: 86, alignment: .trailing)
            .accessibilityLabel("State \(detailText)")
    }
}
