import Foundation

// MARK: - Config

struct LLMConfig {
    let provider: LLMProvider
    let apiKey: String
    let model: String
    let baseURL: String  // used by Ollama / LM Studio
}

// MARK: - Service

actor LLMService {
    private let session: URLSession
    private let healthCheckSession: URLSession

    init(session: URLSession = NetworkSessionFactory.makeEphemeralSession()) {
        self.session = session
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        self.healthCheckSession = URLSession(configuration: configuration)
    }

    func complete(
        prompt: String,
        systemPrompt: String,
        config: LLMConfig
    ) async throws -> String {
        switch config.provider {
        case .claude:
            return try await claudeComplete(prompt: prompt, systemPrompt: systemPrompt, config: config)
        case .openAI, .openRouter, .ollama, .lmStudio:
            return try await openAIComplete(prompt: prompt, systemPrompt: systemPrompt, config: config)
        }
    }

    func translateDescription(
        _ description: String,
        from sourceLocale: String,
        to targetLocale: String,
        config: LLMConfig
    ) async throws -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard DescriptionLocale.shouldTranslate(sourceLocale: sourceLocale, targetLocale: targetLocale) else {
            return trimmed
        }

        let prompt = """
        Translate the following skill description from \(sourceLocale) to \(targetLocale).
        Return only the translated description as plain text.
        Preserve product names, skill names, command names, code identifiers, and technical terms when they should stay unchanged.

        Description:
        \(trimmed)
        """
        let systemPrompt = "You are a precise technical translator for coding tool descriptions. Return only the translated sentence or paragraph with no quotes, labels, notes, or extra commentary."

        let response = if config.provider == .ollama {
            try await ollamaNativeComplete(
                prompt: "/no_think\n\(prompt)",
                systemPrompt: systemPrompt,
                config: config
            )
        } else {
            try await complete(
                prompt: prompt,
                systemPrompt: systemPrompt,
                config: config
            )
        }
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Ollama native

    private struct OllamaChatRequest: Encodable {
        let model: String
        let messages: [OllamaChatMessage]
        let stream: Bool
        let think: Bool
        let options: OllamaOptions
    }

    private struct OllamaChatMessage: Encodable, Decodable {
        let role: String
        let content: String
    }

    private struct OllamaOptions: Encodable {
        let numCtx: Int
        let numPredict: Int
        let temperature: Double

        enum CodingKeys: String, CodingKey {
            case numCtx = "num_ctx"
            case numPredict = "num_predict"
            case temperature
        }
    }

    private struct OllamaChatResponse: Decodable {
        let message: OllamaChatMessage?
        let response: String?

        var text: String {
            message?.content ?? response ?? ""
        }
    }

    private func ollamaNativeComplete(prompt: String, systemPrompt: String, config: LLMConfig) async throws -> String {
        let base = Self.rawBaseURL(for: .ollama, configuredBaseURL: config.baseURL)
        guard var components = URLComponents(string: base) else {
            throw LLMError.invalidResponse
        }
        components.path = "/api/chat"
        guard let url = components.url else {
            throw LLMError.invalidResponse
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = Self.chatCompletionsTimeout(for: config) ?? 180
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONEncoder().encode(OllamaChatRequest(
            model: config.model,
            messages: [
                OllamaChatMessage(role: "system", content: systemPrompt),
                OllamaChatMessage(role: "user", content: prompt)
            ],
            stream: false,
            think: false,
            options: OllamaOptions(
                numCtx: 2048,
                numPredict: 256,
                temperature: 0
            )
        ))
        let (data, response) = try await session.data(for: req)
        try checkHTTP(response, data)
        return try JSONDecoder().decode(OllamaChatResponse.self, from: data).text
    }

    func isServiceReachable(config: LLMConfig) async -> Bool {
        guard let probeURL = Self.healthCheckURL(for: config) else {
            return true
        }

        var request = URLRequest(url: probeURL)
        request.httpMethod = "GET"

        do {
            let (_, response) = try await healthCheckSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<500).contains(http.statusCode)
        } catch {
            return false
        }
    }

    func isLocalModelAvailable(config: LLMConfig) async -> Bool {
        guard config.provider == .ollama || config.provider == .lmStudio else {
            return true
        }
        guard let probeURL = Self.healthCheckURL(for: config) else {
            return false
        }

        var request = URLRequest(url: probeURL)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await healthCheckSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return false
            }
            return Self.response(data: data, containsModel: config.model, provider: config.provider)
        } catch {
            return false
        }
    }

    // MARK: - Anthropic

    private struct AnthropicRequest: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [AnthropicMessage]
        enum CodingKeys: String, CodingKey {
            case model, system, messages
            case maxTokens = "max_tokens"
        }
    }
    private struct AnthropicMessage: Encodable {
        let role: String
        let content: String
    }
    private struct AnthropicResponse: Decodable {
        let content: [ContentBlock]
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
        var text: String { content.compactMap(\.text).joined() }
    }

    private func claudeComplete(prompt: String, systemPrompt: String, config: LLMConfig) async throws -> String {
        guard !config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw LLMError.noApiKey
        }
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONEncoder().encode(AnthropicRequest(
            model: config.model,
            maxTokens: 2048,
            system: systemPrompt,
            messages: [AnthropicMessage(role: "user", content: prompt)]
        ))
        let (data, response) = try await session.data(for: req)
        try checkHTTP(response, data)
        return try JSONDecoder().decode(AnthropicResponse.self, from: data).text
    }

    // MARK: - OpenAI-compatible (OpenRouter / Ollama / LM Studio)

    private struct OAIRequest: Encodable {
        let model: String
        let messages: [OAIMessage]
    }
    private struct OAIMessage: Encodable {
        let role: String
        let content: String
    }
    private struct OAIResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let message: OAIMessage
        }
        struct OAIMessage: Decodable {
            let content: String
        }
        var text: String { choices.first?.message.content ?? "" }
    }

    private func openAIComplete(prompt: String, systemPrompt: String, config: LLMConfig) async throws -> String {
        if config.provider.requiresApiKey,
           config.apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            throw LLMError.noApiKey
        }
        let url = try Self.resolveChatCompletionsURL(for: config)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let timeout = Self.chatCompletionsTimeout(for: config) {
            req.timeoutInterval = timeout
        }
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        if !config.apiKey.isEmpty {
            req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(OAIRequest(
            model: config.model,
            messages: [
                OAIMessage(role: "system", content: systemPrompt),
                OAIMessage(role: "user", content: prompt)
            ]
        ))
        let (data, response) = try await session.data(for: req)
        try checkHTTP(response, data)
        return try JSONDecoder().decode(OAIResponse.self, from: data).text
    }

    // MARK: - Helpers

    private static func resolveChatCompletionsURL(for config: LLMConfig) throws -> URL {
        let rawBase = rawBaseURL(for: config.provider, configuredBaseURL: config.baseURL)
        guard var components = URLComponents(string: rawBase) else {
            throw LLMError.invalidResponse
        }

        let normalizedPath = normalizedChatCompletionsPath(
            provider: config.provider,
            existingPath: components.path
        )
        components.path = normalizedPath

        guard let url = components.url else {
            throw LLMError.invalidResponse
        }
        return url
    }

    private static func rawBaseURL(for provider: LLMProvider, configuredBaseURL: String) -> String {
        let raw = configuredBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        switch provider {
        case .openAI:
            return raw.isEmpty ? "https://api.openai.com/v1" : raw
        case .openRouter:
            return raw.isEmpty ? "https://openrouter.ai/api/v1" : raw
        case .ollama, .lmStudio:
            let base = raw.isEmpty ? provider.defaultBaseURL : raw
            return normalizedLoopbackBaseURL(base)
        case .claude:
            return raw
        }
    }

    private static func normalizedLoopbackBaseURL(_ raw: String) -> String {
        guard var components = URLComponents(string: raw) else {
            return raw
        }
        if components.host?.lowercased() == "localhost" {
            components.host = "127.0.0.1"
        }
        return components.string ?? raw
    }

    private static func normalizedChatCompletionsPath(provider: LLMProvider, existingPath: String) -> String {
        let trimmed = existingPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if trimmed.hasSuffix("chat/completions") {
            return "/" + trimmed
        }

        switch provider {
        case .openAI, .openRouter:
            if trimmed.isEmpty {
                return "/v1/chat/completions"
            }
            if trimmed == "v1" {
                return "/v1/chat/completions"
            }
            return "/" + trimmed + "/chat/completions"
        case .ollama, .lmStudio:
            if trimmed.isEmpty {
                return "/v1/chat/completions"
            }
            if trimmed == "v1" {
                return "/v1/chat/completions"
            }
            return "/" + trimmed + "/v1/chat/completions"
        case .claude:
            return existingPath
        }
    }

    private static func healthCheckURL(for config: LLMConfig) -> URL? {
        let base = rawBaseURL(for: config.provider, configuredBaseURL: config.baseURL)
        guard var components = URLComponents(string: base) else {
            return nil
        }

        switch config.provider {
        case .ollama:
            components.path = "/api/tags"
        case .lmStudio:
            components.path = "/v1/models"
        case .claude, .openAI, .openRouter:
            return nil
        }

        return components.url
    }

    private static func chatCompletionsTimeout(for config: LLMConfig) -> TimeInterval? {
        switch config.provider {
        case .ollama, .lmStudio:
            return 180
        case .claude, .openAI, .openRouter:
            return nil
        }
    }

    private static func response(data: Data, containsModel model: String, provider: LLMProvider) -> Bool {
        let normalizedModel = normalizeModelName(model)
        guard !normalizedModel.isEmpty else { return false }
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }

        switch provider {
        case .ollama:
            let models = object["models"] as? [[String: Any]] ?? []
            return models.contains { entry in
                let name = normalizeModelName(entry["name"] as? String ?? "")
                return name == normalizedModel || name.hasPrefix(normalizedModel + ":")
            }
        case .lmStudio:
            let models = object["data"] as? [[String: Any]] ?? []
            return models.contains { entry in
                normalizeModelName(entry["id"] as? String ?? "") == normalizedModel
            }
        case .claude, .openAI, .openRouter:
            return true
        }
    }

    private static func normalizeModelName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func checkHTTP(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            throw LLMError.httpError(http.statusCode, body)
        }
    }

}

extension LLMService {
    static func debugResolvedChatCompletionsURL(for config: LLMConfig) throws -> URL {
        try resolveChatCompletionsURL(for: config)
    }

    static func debugChatCompletionsTimeout(for config: LLMConfig) -> TimeInterval? {
        chatCompletionsTimeout(for: config)
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case noApiKey
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "No API key configured. Open Settings (⌘,) to add your key."
        case .invalidResponse:
            return "Invalid response received from the API."
        case .httpError(let code, let body):
            return "API request failed (\(code)): \(body.prefix(300))"
        }
    }
}
