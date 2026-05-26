import Foundation

struct HAConnectionConfiguration: Equatable, Sendable {
    var baseURLString: String
    var accessToken: String

    var dataSourceID: String {
        HAStateCache.cacheScopeIdentifier(for: self)
    }
}
