import Foundation

/// Runtime configuration for the Volcengine Ark Responses API.
///
/// Production builds should call a LingXiu-owned HTTPS proxy, which keeps the
/// long-lived Ark credential on the server. Direct bearer authentication is
/// retained only for local development and simulator verification.
struct ArkAIConfiguration: Sendable, Equatable {
    static let endpoint = URL(string: "https://ark.cn-beijing.volces.com/api/v3/responses")!
    static let model = "doubao-seed-evolving"

    enum Transport: Sendable, Equatable {
        case directArk
        case serverProxy
    }

    let apiKey: String?
    let proxyToken: String?
    let pinnedCertificateSHA256: String?
    let endpointURL: URL
    let modelID: String
    let transport: Transport

    init(
        apiKey: String? = nil,
        proxyToken: String? = nil,
        pinnedCertificateSHA256: String? = nil,
        endpointURL: URL = ArkAIConfiguration.endpoint,
        modelID: String = ArkAIConfiguration.model,
        transport: Transport = .directArk
    ) {
        self.apiKey = Self.normalized(apiKey)
        self.proxyToken = Self.normalized(proxyToken)
        self.pinnedCertificateSHA256 = PinnedCertificateURLSessionDelegate.normalizedFingerprint(
            pinnedCertificateSHA256
        )
        self.endpointURL = endpointURL
        self.modelID = modelID
        self.transport = transport
    }

    static var current: ArkAIConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let bundledProxy = Bundle.main.object(forInfoDictionaryKey: "LingXiuAIEndpoint") as? String
        let bundledProxyToken = Bundle.main.object(forInfoDictionaryKey: "LingXiuProxyToken") as? String
        let bundledCertificatePin = Bundle.main.object(
            forInfoDictionaryKey: "LingXiuPinnedCertificateSHA256"
        ) as? String
        let proxyValue = environment["LINGXIU_AI_ENDPOINT"] ?? bundledProxy
        if let proxyURL = normalizedProxyURL(proxyValue) {
            return ArkAIConfiguration(
                proxyToken: environment["LINGXIU_PROXY_TOKEN"] ?? bundledProxyToken,
                pinnedCertificateSHA256: environment["LINGXIU_PINNED_CERTIFICATE_SHA256"]
                    ?? bundledCertificatePin,
                endpointURL: proxyURL,
                modelID: environment["LINGXIU_AI_MODEL"] ?? Self.model,
                transport: .serverProxy
            )
        }

        let environmentKey = environment["ARK_API_KEY"] ?? environment["VOLCENGINE_API_KEY"]
        return ArkAIConfiguration(
            apiKey: environmentKey,
            modelID: environment["LINGXIU_AI_MODEL"] ?? Self.model
        )
    }

    var isConfigured: Bool {
        switch transport {
        case .directArk:
            apiKey != nil
        case .serverProxy:
            true
        }
    }

    var usesServerProxy: Bool {
        transport == .serverProxy
    }

    private static func normalized(_ key: String?) -> String? {
        guard let key else { return nil }
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("<"), !value.hasSuffix(">") else { return nil }
        return value
    }

    private static func normalizedProxyURL(_ value: String?) -> URL? {
        guard let value else { return nil }
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              !candidate.contains("$("),
              let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              let host = url.host,
              scheme == "https" || (scheme == "http" && ["127.0.0.1", "localhost"].contains(host)) else {
            return nil
        }
        return url
    }
}

struct ArkAnalysisPayload: Sendable {
    let result: AnalysisResult
    let replies: [ReplyOption]
}

enum ArkAIError: LocalizedError {
    case notConfigured
    case invalidResponse
    case server(statusCode: Int, providerCode: String?)
    case emptyModelOutput
    case certificateValidationFailed
    case networkUnavailable
    case requestTimedOut
    case networkRequestFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "尚未配置火山方舟 API Key"
        case .invalidResponse:
            "火山方舟返回的数据格式无法识别"
        case let .server(statusCode, providerCode):
            switch providerCode {
            case "ModelNotOpen":
                "目标模型尚未在火山方舟控制台开通"
            case "AuthenticationError", "InvalidAuthentication", "Unauthorized":
                "火山方舟 API 鉴权失败"
            default:
                "云端模型请求失败（HTTP \(statusCode)）"
            }
        case .emptyModelOutput:
            "火山方舟没有返回分析内容"
        case .certificateValidationFailed:
            "安全连接验证失败，请更新灵嗅或联系开发者"
        case .networkUnavailable:
            "当前网络不可用，请检查网络连接后重试"
        case .requestTimedOut:
            "云端 AI 响应超时，请稍后重试"
        case .networkRequestFailed:
            "暂时无法连接云端 AI，请稍后重试"
        }
    }
}

/// Native URLSession client for Ark's Responses API. It is intentionally a
/// small value type so it can be injected into `AppStore` and unit-tested
/// without changing the rest of the SwiftUI product.
struct ArkAIService: Sendable {
    private static let requestTimeout: TimeInterval = 120
    private static let resourceTimeout: TimeInterval = 135

    let configuration: ArkAIConfiguration

    init(configuration: ArkAIConfiguration = .current) {
        self.configuration = configuration
    }

    var isConfigured: Bool { configuration.isConfigured }

    var usesServerProxy: Bool { configuration.usesServerProxy }

    func analyze(
        draft: AnalysisDraft,
        roleCard: ChatRoleCard?,
        identityCard: IdentityCard?,
        fallbackKind: AnalysisKind
    ) async throws -> ArkAnalysisPayload {
        guard configuration.isConfigured else {
            throw ArkAIError.notConfigured
        }

        let prompt = makePrompt(draft: draft, roleCard: roleCard, identityCard: identityCard)
        var content: [[String: Any]] = [[
            "type": "input_text",
            "text": prompt
        ]]

        for imageData in draft.imageData {
            // PhotosPicker and the camera already provide image bytes. A data
            // URL keeps the request self-contained and avoids uploading a
            // private image to a second storage service.
            content.append([
                "type": "input_image",
                "image_url": "data:\(Self.imageMIMEType(for: imageData));base64,\(imageData.base64EncodedString())"
            ])
        }

        let body: [String: Any] = [
            "model": configuration.modelID,
            "input": [[
                "role": "user",
                "content": content
            ]],
            // Ark stores Responses by default. LingXiu handles private chat
            // content, so opt out explicitly for every request.
            "store": false,
            "max_output_tokens": 4_096
        ]

        var request = URLRequest(url: configuration.endpointURL)
        request.httpMethod = "POST"
        // Evolving may spend close to a minute producing a structured answer.
        // Keep the client deadline above the proxy deadlines so a server-side
        // error reaches the UI instead of being misreported as a local timeout.
        request.timeoutInterval = Self.requestTimeout
        if let apiKey = configuration.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if configuration.usesServerProxy, let proxyToken = configuration.proxyToken {
            request.setValue(proxyToken, forHTTPHeaderField: "X-LingXiu-Proxy-Token")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await makeURLSession().data(for: request)
        } catch let error as URLError {
            throw Self.networkError(for: error.code)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ArkAIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            // Only retain the provider's machine-readable code. Error messages
            // may echo request metadata and must not become a conversation-data
            // or secret channel in logs and UI.
            throw ArkAIError.server(
                statusCode: httpResponse.statusCode,
                providerCode: Self.providerErrorCode(from: data)
            )
        }

        let outputText = try Self.extractOutputText(from: data)
        guard let structuredData = Self.firstJSONObject(in: outputText),
              let structured = try? JSONDecoder().decode(ArkStructuredResponse.self, from: structuredData),
              !structured.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !structured.replies.isEmpty else {
            throw ArkAIError.invalidResponse
        }

        let result = AnalysisResult(
            kind: fallbackKind,
            summary: structured.summary,
            possibleMeanings: structured.possibleMeanings,
            suggestions: structured.suggestions,
            roleContext: roleCard?.contextSummary,
            identityContext: identityCard?.contextSummary
        )
        let replies = structured.replies.prefix(3).map { reply in
            ReplyOption(label: reply.label, text: reply.text, rationale: reply.rationale)
        }
        return ArkAnalysisPayload(result: result, replies: replies)
    }

    private func makeURLSession() -> URLSession {
        guard configuration.usesServerProxy,
              let host = configuration.endpointURL.host,
              let certificatePin = configuration.pinnedCertificateSHA256 else {
            return .shared
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = Self.requestTimeout
        sessionConfiguration.timeoutIntervalForResource = Self.resourceTimeout
        let delegate = PinnedCertificateURLSessionDelegate(
            expectedHost: host,
            pinnedCertificateSHA256: certificatePin
        )
        return URLSession(
            configuration: sessionConfiguration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    static func networkError(for code: URLError.Code) -> ArkAIError {
        switch code {
        case .serverCertificateUntrusted,
             .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid,
             .secureConnectionFailed,
             .clientCertificateRejected,
             .clientCertificateRequired:
            .certificateValidationFailed
        case .notConnectedToInternet,
             .networkConnectionLost,
             .dataNotAllowed,
             .internationalRoamingOff,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed:
            .networkUnavailable
        case .timedOut:
            .requestTimedOut
        default:
            .networkRequestFailed
        }
    }

    private func makePrompt(
        draft: AnalysisDraft,
        roleCard: ChatRoleCard?,
        identityCard: IdentityCard?
    ) -> String {
        var context: [String] = [
            "你是“灵嗅”，一款帮助用户进行中国式沟通分析的助手。",
            "请基于用户提供的聊天内容和图片，区分事实、可能性与建议，不要对他人心理作确定性判断。"
        ]
        if let roleCard {
            context.append("沟通对象角色卡：\(roleCard.contextSummary)")
        }
        if let identityCard {
            context.append("用户身份卡：\(identityCard.contextSummary)")
        }
        if let quickTopic = draft.quickTopic {
            context.append("沟通主题：\(quickTopic.rawValue)")
        }
        if let optimizationQuote = draft.optimizationQuote,
           !optimizationQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            context.append("待优化的回复：\(optimizationQuote)")
            context.append("优化方向：\(draft.conversationText)")
        } else {
            context.append("用户输入：\(draft.conversationText)")
        }

        context.append(
            "只返回合法 JSON，不要 Markdown 代码围栏。格式：" +
            "{\"summary\":\"一句判断\",\"possibleMeanings\":[\"可能性1\",\"可能性2\",\"可能性3\"]," +
            "\"suggestions\":[\"建议1\",\"建议2\",\"建议3\"]," +
            "\"replies\":[{\"label\":\"选项名\",\"text\":\"可直接发送的回复\",\"rationale\":\"适用说明\"}]}。" +
            "请提供 3 个 replies。"
        )
        return context.joined(separator: "\n")
    }

    private struct ArkStructuredResponse: Decodable {
        let summary: String
        let possibleMeanings: [String]
        let suggestions: [String]
        let replies: [ArkReply]
    }

    private struct ArkReply: Decodable {
        let label: String
        let text: String
        let rationale: String
    }

    static func extractOutputText(from data: Data) throws -> String {
        if let response = try? JSONDecoder().decode(ArkResponseEnvelope.self, from: data) {
            if let outputText = response.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !outputText.isEmpty {
                return outputText
            }

            let messageText = response.output?
                .filter { $0.type == "message" }
                .flatMap { $0.content ?? [] }
                .first { $0.type == "output_text" }?
                .text?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let messageText, !messageText.isEmpty {
                return messageText
            }
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            throw ArkAIError.invalidResponse
        }

        var values: [String] = []
        func collect(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                if let text = dictionary["text"] as? String, !text.isEmpty {
                    values.append(text)
                }
                // Some Responses API gateways expose the convenience field
                // `output_text` instead of nesting the text under content.
                if let outputText = dictionary["output_text"] as? String,
                   !outputText.isEmpty {
                    values.append(outputText)
                }
                for child in dictionary.values { collect(child) }
            } else if let array = value as? [Any] {
                for child in array { collect(child) }
            }
        }
        collect(object)
        guard let text = values.last?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw ArkAIError.emptyModelOutput
        }
        return text
    }

    static func firstJSONObject(in text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start <= end else { return nil }
        return String(text[start...end]).data(using: .utf8)
    }

    private static func providerErrorCode(from data: Data) -> String? {
        guard let response = try? JSONDecoder().decode(ArkErrorEnvelope.self, from: data) else {
            return nil
        }
        return response.error?.code
    }

    private static func imageMIMEType(for data: Data) -> String {
        let prefix = [UInt8](data.prefix(12))
        if prefix.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }
        if prefix.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "image/gif"
        }
        if prefix.count >= 12,
           Array(prefix[0..<4]) == [0x52, 0x49, 0x46, 0x46],
           Array(prefix[8..<12]) == [0x57, 0x45, 0x42, 0x50] {
            return "image/webp"
        }
        return "image/jpeg"
    }

    private struct ArkResponseEnvelope: Decodable {
        let outputText: String?
        let output: [ArkOutputItem]?

        enum CodingKeys: String, CodingKey {
            case outputText = "output_text"
            case output
        }
    }

    private struct ArkOutputItem: Decodable {
        let type: String?
        let content: [ArkOutputContent]?
    }

    private struct ArkOutputContent: Decodable {
        let type: String?
        let text: String?
    }

    private struct ArkErrorEnvelope: Decodable {
        let error: ArkProviderError?
    }

    private struct ArkProviderError: Decodable {
        let code: String?
    }
}
