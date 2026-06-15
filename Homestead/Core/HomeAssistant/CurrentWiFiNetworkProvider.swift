import Foundation

#if canImport(NetworkExtension)
import NetworkExtension
#endif

protocol CurrentWiFiNetworkProviding: Sendable {
    func currentSSID() async -> String?
}

struct SystemCurrentWiFiNetworkProvider: CurrentWiFiNetworkProviding {
    func currentSSID() async -> String? {
        #if canImport(NetworkExtension)
        await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                let ssid = network?.ssid.trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: ssid?.isEmpty == false ? ssid : nil)
            }
        }
        #else
        nil
        #endif
    }
}
