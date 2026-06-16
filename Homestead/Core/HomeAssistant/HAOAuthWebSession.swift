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
                    continuation.resume(throwing: Self.authorizationError(from: error))
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
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ??
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first

        if let window = windowScene?.windows.first(where: \.isKeyWindow) ??
            windowScene?.windows.first {
            return window
        }

        if #available(iOS 26.0, *) {
            guard let windowScene else {
                preconditionFailure("Home Assistant sign-in requires an active window scene.")
            }

            return ASPresentationAnchor(windowScene: windowScene)
        } else {
            return ASPresentationAnchor()
        }
        #else
        ASPresentationAnchor()
        #endif
    }

    private static func authorizationError(from error: Error) -> Error {
        let nsError = error as NSError
        if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
           ASWebAuthenticationSessionError.Code(rawValue: nsError.code) == .canceledLogin {
            return HAOAuthError.signInCancelled
        }

        return error
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
