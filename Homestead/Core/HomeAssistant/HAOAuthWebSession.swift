import Foundation

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

#if canImport(UIKit)
import UIKit
#endif

@MainActor
protocol HAOAuthAuthorizing {
    func authorize(authorizationURL: URL, callbackScheme: String) async throws -> URL
}

#if canImport(AuthenticationServices)
@MainActor
final class HAWebAuthenticationSession: NSObject, HAOAuthAuthorizing, ASWebAuthenticationPresentationContextProviding {
    private var activeSession: ASWebAuthenticationSession?

    func authorize(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.activeSession = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: HAOAuthError.missingAuthorizationCode)
                    return
                }

                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session

            if !session.start() {
                activeSession = nil
                continuation.resume(throwing: HAWebSocketError.transportFailure("Unable to start Home Assistant sign-in."))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        ASPresentationAnchor()
        #endif
    }
}
#else
@MainActor
final class HAWebAuthenticationSession: HAOAuthAuthorizing {
    func authorize(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        throw HAWebSocketError.transportFailure("Home Assistant sign-in is not available on this platform.")
    }
}
#endif
