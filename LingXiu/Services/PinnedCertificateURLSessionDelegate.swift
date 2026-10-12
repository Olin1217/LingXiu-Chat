import CryptoKit
import Foundation
import Security

/// Trusts the temporary LingXiu API certificate only when both the destination
/// host and the complete leaf-certificate SHA-256 digest match. The server
/// presents a private development CA after the leaf; that CA is scoped to this
/// one challenge and never added to the device trust store.
final class PinnedCertificateURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let expectedHost: String
    private let pinnedCertificateSHA256: String
    private let trustedDevelopmentCA: SecCertificate?

    #if DEBUG
    private static let debugLock = NSLock()
    nonisolated(unsafe) private static var latestDebugMessageStorage = "not started"
    static var latestDebugMessage: String {
        debugLock.withLock { latestDebugMessageStorage }
    }
    #endif

    init(
        expectedHost: String,
        pinnedCertificateSHA256: String,
        trustedDevelopmentCAData: Data? = PinnedCertificateURLSessionDelegate.bundledDevelopmentCAData()
    ) {
        self.expectedHost = expectedHost
        self.pinnedCertificateSHA256 = pinnedCertificateSHA256
        self.trustedDevelopmentCA = trustedDevelopmentCAData.flatMap {
            SecCertificateCreateWithData(nil, $0 as CFData)
        }
        super.init()
    }

    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == expectedHost,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let certificate = certificateChain.first else {
            debugLog("certificate chain unavailable")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        debugLog("received certificate chain count: \(certificateChain.count)")

        let certificateData = SecCertificateCopyData(certificate) as Data
        let digest = SHA256.hash(data: certificateData)
            .map { String(format: "%02x", $0) }
            .joined()

        guard digest == pinnedCertificateSHA256 else {
            debugLog("leaf certificate pin mismatch")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        debugLog("leaf certificate pin matched")

        // The digest match proves this is the explicitly configured leaf. Use
        // the bundled public development CA as the only anchor rather than
        // relying on CFNetwork to retain an untrusted root from the presented
        // chain. Security still validates the IP SAN, validity period and
        // server-auth usage for every connection.
        guard let trustedDevelopmentCA else {
            debugLog("bundled development CA unavailable")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let policyStatus = SecTrustSetPolicies(
            serverTrust,
            SecPolicyCreateSSL(true, expectedHost as CFString)
        )
        let networkStatus = SecTrustSetNetworkFetchAllowed(serverTrust, false)
        let anchorStatus = SecTrustSetAnchorCertificates(
            serverTrust,
            [trustedDevelopmentCA] as CFArray
        )
        let anchorOnlyStatus = SecTrustSetAnchorCertificatesOnly(serverTrust, true)
        var trustError: CFError?
        let isTrusted = SecTrustEvaluateWithError(serverTrust, &trustError)
        let trustErrorDescription = trustError?.localizedDescription ?? "none"
        debugLog(
            "custom trust policy=\(policyStatus), network=\(networkStatus), " +
            "anchor=\(anchorStatus), anchorOnly=\(anchorOnlyStatus), trusted=\(isTrusted), " +
            "error=\(trustErrorDescription)"
        )
        guard policyStatus == errSecSuccess,
              networkStatus == errSecSuccess,
              anchorStatus == errSecSuccess,
              anchorOnlyStatus == errSecSuccess,
              isTrusted else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    static func normalizedFingerprint(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.lowercased().filter(\.isHexDigit)
        guard normalized.count == 64 else { return nil }
        return normalized
    }

    static func bundledDevelopmentCAData(
        bundle: Bundle = Bundle(for: PinnedCertificateURLSessionDelegate.self)
    ) -> Data? {
        guard let url = bundle.url(forResource: "LingXiuDevelopmentCA", withExtension: "pem"),
              let pem = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let base64 = pem
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") }
            .joined()
        return Data(base64Encoded: base64)
    }

    private nonisolated func debugLog(_ message: String) {
        #if DEBUG
        Self.debugLock.withLock {
            Self.latestDebugMessageStorage = message
        }
        print("LingXiuTLS: \(message)")
        #endif
    }
}
