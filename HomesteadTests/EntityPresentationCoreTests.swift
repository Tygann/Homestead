import Foundation
import Testing
@testable import Homestead

struct EntityPresentationCoreTests {
    @Test func referenceRequiresExplicitServerScope() {
        let profileID = UUID(uuidString: "5A21FC6E-47C9-4D83-91A4-4EC19F1E3900")!
        let reference = EntityPresentationReference(
            profileID: profileID,
            entityID: "sensor.kitchen_temperature"
        )

        #expect(EntityPresentationReference(encodedID: reference.encodedID) == reference)
        #expect(EntityPresentationReference(encodedID: "sensor.kitchen_temperature") == nil)
    }

    @Test func availabilityAndActiveStateAreSurfaceNeutral() {
        let unavailable = resolve(domain: .light, state: "unavailable")
        let transitioning = resolve(domain: .cover, state: "opening")
        let locked = resolve(domain: .lock, state: "locked")

        #expect(unavailable.availability == .unavailable)
        #expect(unavailable.semanticState == .unavailable)
        #expect(transitioning.semanticState == .transitioning)
        #expect(locked.isActive)
    }

    @Test func sensorFormattingUsesHomeAssistantDisplayPrecisionAndUnitRules() {
        let presentation = EntityPresentationResolver.resolve(EntityPresentationInput(
            entityID: "sensor.temperature",
            domain: .sensor,
            state: "72.346",
            displayName: "Temperature",
            deviceClass: "temperature",
            stateClass: "measurement",
            unit: "F",
            numericValue: 72.346,
            displayPrecision: 2,
            icon: .sfSymbol("thermometer", provenance: .homesteadSemanticMapping)
        ))

        #expect(presentation.valueText == "72.35°F")
        #expect(presentation.affordances.contains(.history))
        #expect(presentation.affordances.contains(.numericReading))
    }

    @Test func eligibilitySeparatesReadingChartGaugeAndControl() {
        let input = EntityPresentationInput(
            entityID: "sensor.humidity",
            domain: .sensor,
            state: "45",
            displayName: "Humidity",
            deviceClass: "humidity",
            stateClass: "measurement",
            unit: "%",
            numericValue: 45,
            icon: .sfSymbol("humidity", provenance: .homesteadSemanticMapping),
            hasGaugeSpecification: true
        )

        #expect(EntityPresentationResolver.eligibility(of: .sensorReading, for: input).isSelectable)
        #expect(EntityPresentationResolver.eligibility(of: .chart, for: input).isSelectable)
        #expect(EntityPresentationResolver.eligibility(of: .circularGauge, for: input).isSelectable)
        #expect(!EntityPresentationResolver.eligibility(of: .control, for: input).isSelectable)
    }

    private func resolve(domain: EntityDomain, state: String) -> EntitySemanticPresentation {
        EntityPresentationResolver.resolve(EntityPresentationInput(
            entityID: "\(domain.rawValue).fixture",
            domain: domain,
            state: state,
            displayName: "Fixture",
            icon: .sfSymbol("circle", provenance: .homesteadSemanticMapping)
        ))
    }
}
