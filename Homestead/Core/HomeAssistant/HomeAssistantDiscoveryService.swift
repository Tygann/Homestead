import Foundation
import Observation
@preconcurrency import Network

nonisolated struct HomeAssistantDiscoveredInstance: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let uuid: String?
    let signInURL: String
    let internalURL: String?
    let externalURL: String?
    let version: String?
}

enum HomeAssistantDiscoveryState: Equatable {
    case idle
    case browsing
    case failed(String)
}

@MainActor
@Observable
final class HomeAssistantDiscoveryService {
    private(set) var state: HomeAssistantDiscoveryState = .idle
    private(set) var instances: [HomeAssistantDiscoveredInstance] = []

    @ObservationIgnored private var browser: NWBrowser?

    func start() {
        stop(clearResults: true)
        state = .browsing

        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: "_home-assistant._tcp", domain: "local."),
            using: .tcp
        )
        browser.stateUpdateHandler = { [weak self] newState in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch newState {
                case .failed(let error), .waiting(let error):
                    self.state = .failed(error.localizedDescription)
                case .cancelled:
                    if self.state == .browsing { self.state = .idle }
                default:
                    break
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let mapped = results.compactMap(Self.instance(from:))
            MainActor.assumeIsolated {
                self?.instances = Self.deduplicated(mapped)
            }
        }
        self.browser = browser
        browser.start(queue: .main)
    }

    func stop(clearResults: Bool = false) {
        browser?.cancel()
        browser = nil
        if clearResults { instances = [] }
        if state == .browsing { state = .idle }
    }

    nonisolated static func instance(
        serviceName: String,
        txt: [String: String]
    ) -> HomeAssistantDiscoveredInstance? {
        let internalURL = value("internal_url", in: txt)
        let externalURL = value("external_url", in: txt)
        let baseURL = value("base_url", in: txt)
        guard let signInURL = externalURL ?? baseURL ?? internalURL else { return nil }

        let uuid = value("uuid", in: txt)
        let id = uuid?.lowercased() ?? normalized(signInURL)
        return HomeAssistantDiscoveredInstance(
            id: id,
            name: value("location_name", in: txt) ?? serviceName,
            uuid: uuid,
            signInURL: signInURL,
            internalURL: internalURL ?? baseURL,
            externalURL: externalURL,
            version: value("version", in: txt)
        )
    }

    nonisolated private static func instance(from result: NWBrowser.Result) -> HomeAssistantDiscoveredInstance? {
        guard case .service(let name, _, _, _) = result.endpoint,
              case .bonjour(let record) = result.metadata else { return nil }
        let txt = record.dictionary
        return instance(serviceName: name, txt: txt)
    }

    nonisolated private static func deduplicated(
        _ instances: [HomeAssistantDiscoveredInstance]
    ) -> [HomeAssistantDiscoveredInstance] {
        var seen = Set<String>()
        return instances
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .filter { seen.insert($0.id).inserted }
    }

    nonisolated private static func value(_ key: String, in txt: [String: String]) -> String? {
        txt.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    nonisolated private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).lowercased()
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
