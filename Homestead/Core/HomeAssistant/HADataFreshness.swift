import Foundation

enum HADataFreshness: Equatable {
    case empty
    case cached(Date?)
    case refreshing
    case live(Date)
    case stale(String?)

    var isUsable: Bool {
        switch self {
        case .cached, .refreshing, .live, .stale:
            true
        case .empty:
            false
        }
    }
}
