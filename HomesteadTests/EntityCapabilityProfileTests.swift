import XCTest
@testable import Homestead

final class EntityCapabilityProfileTests: XCTestCase {
    func testReferenceDomainsUseDistinctFamiliesAndRoutes() {
        let sensor = EntityCapabilityRegistry.profile(for: .sensor)
        let cover = EntityCapabilityRegistry.profile(for: .cover)
        let climate = EntityCapabilityRegistry.profile(for: .climate)
        let weather = EntityCapabilityRegistry.profile(for: .weather)

        XCTAssertEqual(sensor.family, .metric)
        XCTAssertEqual(sensor.detailRoute, .sensor)
        XCTAssertEqual(sensor.heroKind, .metric)
        XCTAssertTrue(sensor.supports(.showHistory))

        XCTAssertEqual(cover.family, .positionalSecurity)
        XCTAssertEqual(cover.detailRoute, .cover)
        XCTAssertTrue(cover.supports(.setPosition))

        XCTAssertEqual(climate.family, .environmental)
        XCTAssertEqual(climate.detailRoute, .climate)
        XCTAssertTrue(climate.supports(.setTemperature))

        XCTAssertEqual(weather.family, .informationContent)
        XCTAssertEqual(weather.detailRoute, .weather)
        XCTAssertEqual(weather.heroKind, .environment)
    }

    func testEveryDomainHasACompleteProfile() {
        for domain in EntityDomain.allCases {
            let profile = EntityCapabilityRegistry.profile(for: domain)

            XCTAssertEqual(profile.domain, domain)
            XCTAssertFalse(profile.categoryTitle.isEmpty)
        }
    }

    func testDashboardDetailKindsAdaptFromNeutralRoutes() {
        XCTAssertEqual(DashboardEntityDomainRegistry.capability(for: .light).detailKind, .light)
        XCTAssertEqual(DashboardEntityDomainRegistry.capability(for: .automation).detailKind, .toggle)
        XCTAssertEqual(DashboardEntityDomainRegistry.capability(for: .person).detailKind, .entity)
    }

    func testHistoryUsesPreferredBoundedDomainAndReportsPartialCoverage() {
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 86_400)
        )
        let series = HAHistoryChartSeries(
            entityID: "sensor.battery",
            displayName: "Battery",
            unit: "%",
            range: .day,
            samples: [
                HAHistorySample(occurredAt: Date(timeIntervalSince1970: 10_000), value: 85),
                HAHistorySample(occurredAt: Date(timeIntervalSince1970: 86_000), value: 72)
            ],
            requestedInterval: interval
        )

        XCTAssertEqual(series.valueDomain(preferredRange: 0...100), 0...100)
        XCTAssertNotNil(series.coverageNotice)
    }
}
