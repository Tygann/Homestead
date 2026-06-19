import Foundation

struct ClimateSetpointAdjustment: Equatable, Sendable {
    let minimumTemperature: Double
    let maximumTemperature: Double
    let step: Double

    init(
        minimumTemperature: Double,
        maximumTemperature: Double,
        step: Double
    ) {
        self.minimumTemperature = min(minimumTemperature, maximumTemperature)
        self.maximumTemperature = max(minimumTemperature, maximumTemperature)
        self.step = step > 0 ? step : 1
    }

    init(climate: ClimateEntity) {
        self.init(
            minimumTemperature: climate.resolvedMinimumTemperature,
            maximumTemperature: climate.resolvedMaximumTemperature,
            step: climate.resolvedTemperatureStep
        )
    }

    func clampedSingleTemperature(_ temperature: Double) -> Double {
        steppedClamped(temperature, lowerBound: minimumTemperature, upperBound: maximumTemperature)
    }

    func clampedRange(lowTemperature: Double, highTemperature: Double) -> ClimateSetpointRange {
        let low = steppedClamped(
            lowTemperature,
            lowerBound: minimumTemperature,
            upperBound: maximumTemperature
        )
        let high = steppedClamped(
            highTemperature,
            lowerBound: low,
            upperBound: maximumTemperature
        )

        return ClimateSetpointRange(lowTemperature: low, highTemperature: high)
    }

    func adjustedLowTemperature(
        currentLowTemperature: Double,
        currentHighTemperature: Double,
        delta: Double
    ) -> ClimateSetpointRange {
        let high = clampedSingleTemperature(currentHighTemperature)
        let low = steppedClamped(
            currentLowTemperature + delta,
            lowerBound: minimumTemperature,
            upperBound: high
        )

        return ClimateSetpointRange(lowTemperature: low, highTemperature: high)
    }

    func adjustedHighTemperature(
        currentLowTemperature: Double,
        currentHighTemperature: Double,
        delta: Double
    ) -> ClimateSetpointRange {
        let low = clampedSingleTemperature(currentLowTemperature)
        let high = steppedClamped(
            currentHighTemperature + delta,
            lowerBound: low,
            upperBound: maximumTemperature
        )

        return ClimateSetpointRange(lowTemperature: low, highTemperature: high)
    }

    func steppedClamped(
        _ temperature: Double,
        lowerBound: Double,
        upperBound: Double
    ) -> Double {
        let orderedLowerBound = min(lowerBound, upperBound)
        let orderedUpperBound = max(lowerBound, upperBound)
        let rounded = (temperature / step).rounded() * step
        return min(max(rounded, orderedLowerBound), orderedUpperBound)
    }
}

struct ClimateSetpointRange: Equatable, Sendable {
    let lowTemperature: Double
    let highTemperature: Double
}
