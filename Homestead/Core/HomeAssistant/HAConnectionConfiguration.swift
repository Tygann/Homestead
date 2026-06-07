import Foundation

nonisolated struct HAConnectionConfiguration: Equatable, Sendable {
    var baseURLString: String
    var accessToken: String
    var serverIdentityBaseURLString: String?
    var authenticationBaseURLString: String?

    init(
        baseURLString: String,
        accessToken: String,
        serverIdentityBaseURLString: String? = nil,
        authenticationBaseURLString: String? = nil
    ) {
        self.baseURLString = baseURLString
        self.accessToken = accessToken
        self.serverIdentityBaseURLString = serverIdentityBaseURLString
        self.authenticationBaseURLString = authenticationBaseURLString
    }

    nonisolated var dataSourceID: String {
        HAStateCache.cacheScopeIdentifier(for: self)
    }

    nonisolated var dataSourceBaseURLString: String {
        if let serverIdentityBaseURLString,
           !serverIdentityBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return serverIdentityBaseURLString
        }

        return baseURLString
    }

    nonisolated var tokenRefreshBaseURLString: String {
        if let authenticationBaseURLString,
           !authenticationBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return authenticationBaseURLString
        }

        return dataSourceBaseURLString
    }

    nonisolated func routed(to activeBaseURLString: String) -> HAConnectionConfiguration {
        HAConnectionConfiguration(
            baseURLString: activeBaseURLString,
            accessToken: accessToken,
            serverIdentityBaseURLString: dataSourceBaseURLString,
            authenticationBaseURLString: tokenRefreshBaseURLString
        )
    }
}
