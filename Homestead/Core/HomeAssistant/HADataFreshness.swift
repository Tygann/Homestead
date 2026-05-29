import Foundation

enum HADataFreshness: Equatable {
    case empty
    case cached(Date?)
    case refreshing(lastUpdated: Date? = nil)
    case live(Date)
    case stale(String?, lastUpdated: Date? = nil)

    var isUsable: Bool {
        switch self {
        case .cached, .refreshing, .live, .stale:
            true
        case .empty:
            false
        }
    }

    var lastKnownUpdateDate: Date? {
        switch self {
        case .cached(let date):
            date
        case .live(let date):
            date
        case .stale(_, let lastUpdated):
            lastUpdated
        case .refreshing(let lastUpdated):
            lastUpdated
        case .empty:
            nil
        }
    }
}
