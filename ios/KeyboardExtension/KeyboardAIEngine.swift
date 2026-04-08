// KeyboardAIEngine.swift
// RelateOS — On-keyboard AI engine: encrypt → Cloudflare → Gemini 2.5 Pro

import Foundation
import UIKit
import CryptoKit

// MARK: - AI Result Models

struct AIAnalysisResult {
    let suggestions: [SuggestionModel]
    let subtextExplanation: String?
    let detectedEmotion: String?
    let healthDelta: Float?
}

// MARK: - AI Engine

final class KeyboardAIEngine {

    private let proxyURL = URL(string: "https://relateos-ai-proxy.relateos.workers.dev/analyze-intent")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.httpAdditionalHeaders = ["Content-Type": "application/json"]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Analyze

    func analyze(draft: String, context: [Message]) async throws -> AIAnalysisResult {
        let payload = buildPayload(draft: draft, context: context)
        let encrypted = try encryptPayload(payload)

        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.httpBody = encrypted.data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(encrypted.nonceHex, forHTTPHeaderField: "X-Nonce")
        request.setValue(authToken(), forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIError.serverError
        }

        let decrypted = try decryptResponse(data, nonceHex: http.value(forHTTPHeaderField: "X-Response-Nonce"))
        return try parseResult(decrypted)
    }

    // MARK: - Payload Construction

    private func buildPayload(draft: String, context: [Message]) -> [String: Any] {
        let messages = context.prefix(20).map { msg -> [String: String] in
            ["role": msg.isOutgoing ? "user" : "other",
             "text": msg.text,
             "lang": msg.detectedLanguage ?? "auto"]
        }

        return [
            "draft": draft,
            "messages": messages,
            "locale": Locale.current.identifier,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
    }

    // MARK: - Encryption (AES-256-GCM)

    private struct EncryptedPayload {
        let data: Data
        let nonceHex: String
    }

    private func encryptPayload(_ payload: [String: Any]) throws -> EncryptedPayload {
        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        // Derive key from stored JWT (AppGroup keychain)
        let keyData = deriveEncryptionKey()
        let symmetricKey = SymmetricKey(data: keyData)

        let nonce = try AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(jsonData, using: symmetricKey, nonce: nonce)

        guard let combined = sealedBox.combined else {
            throw AIError.encryptionFailed
        }

        let nonceHex = nonce.withUnsafeBytes { Data($0).map { String(format: "%02x", $0) }.joined() }

        return EncryptedPayload(data: combined, nonceHex: nonceHex)
    }

    private func decryptResponse(_ data: Data, nonceHex: String?) throws -> Data {
        guard let nonceHex = nonceHex,
              let nonceData = Data(hexString: nonceHex),
              nonceData.count == 12 else {
            // Fallback: assume unencrypted JSON in dev mode
            return data
        }

        let keyData = deriveEncryptionKey()
        let symmetricKey = SymmetricKey(data: keyData)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    private func deriveEncryptionKey() -> Data {
        // In production: retrieve JWT from AppGroup Keychain, SHA-256 hash as key
        let sharedDefaults = UserDefaults(suiteName: "group.com.relateos.keyboard")
        let jwt = sharedDefaults?.string(forKey: "supabase_access_token") ?? "development_fallback_key_32bytes!!"
        let keyData = Data(jwt.utf8)
        let hashed = SHA256.hash(data: keyData)
        return Data(hashed)
    }

    private func authToken() -> String {
        let sharedDefaults = UserDefaults(suiteName: "group.com.relateos.keyboard")
        let token = sharedDefaults?.string(forKey: "supabase_access_token") ?? ""
        return "Bearer \(token)"
    }

    // MARK: - Response Parsing

    private func parseResult(_ data: Data) throws -> AIAnalysisResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.invalidResponse
        }

        // Parse suggestions array
        var suggestions: [SuggestionModel] = []
        if let rawSuggestions = json["suggestions"] as? [[String: Any]] {
            for (i, raw) in rawSuggestions.prefix(3).enumerated() {
                guard let text = raw["text"] as? String else { continue }
                let toneRaw = raw["tone"] as? String ?? "gentle"
                let tone = SuggestionTone(rawValue: toneRaw) ?? .gentle
                let confidence = raw["confidence"] as? Float ?? 0.8

                let truncated = String(text.prefix(40))
                suggestions.append(SuggestionModel(
                    text: truncated,
                    tone: tone,
                    confidence: confidence,
                    id: "suggestion_\(i)_\(Date().timeIntervalSince1970)"
                ))
            }
        }

        let subtext = json["subtext_explanation"] as? String
        let emotion = json["detected_emotion"] as? String
        let healthDelta = json["health_delta"] as? Float

        return AIAnalysisResult(
            suggestions: suggestions,
            subtextExplanation: subtext,
            detectedEmotion: emotion,
            healthDelta: healthDelta
        )
    }

    // MARK: - Errors

    enum AIError: Error {
        case encryptionFailed
        case serverError
        case invalidResponse
        case timeout
    }
}

// MARK: - Message Model

struct Message: Codable {
    let id: String
    let text: String
    let isOutgoing: Bool
    let timestamp: Date
    let detectedLanguage: String?
}

// MARK: - Message Capture Manager

final class MessageCaptureManager {

    private let sharedDefaults = UserDefaults(suiteName: "group.com.relateos.keyboard")
    private let maxStoredMessages = 20

    // MARK: - Read

    func readMessageHistory() -> [Message] {
        guard let data = sharedDefaults?.data(forKey: "message_history") else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Message].self, from: data)) ?? []
    }

    // MARK: - Write (called from main app via AppGroup)

    func writeMessageHistory(_ messages: [Message]) {
        let capped = Array(messages.suffix(maxStoredMessages))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(capped) {
            sharedDefaults?.set(data, forKey: "message_history")
        }
    }

    // MARK: - Logging

    func logSuggestionSelected(suggestion: SuggestionModel, context: String) {
        var log = readSelectionLog()
        log.append([
            "suggestion_id": suggestion.id,
            "tone": suggestion.tone.rawValue,
            "context_length": String(context.count),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        // Keep last 100 selections
        let capped = Array(log.suffix(100))
        if let data = try? JSONSerialization.data(withJSONObject: capped) {
            sharedDefaults?.set(data, forKey: "suggestion_selection_log")
        }
    }

    private func readSelectionLog() -> [[String: String]] {
        guard let data = sharedDefaults?.data(forKey: "suggestion_selection_log"),
              let log = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return []
        }
        return log
    }
}

// MARK: - Haptic Engine

final class HapticEngine {

    static let shared = HapticEngine()
    private init() {}

    private let keyFeedback = UIImpactFeedbackGenerator(style: .light)
    private let deleteFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let suggestionFeedback = UINotificationFeedbackGenerator()

    func keyTap() {
        keyFeedback.impactOccurred(intensity: 0.6)
    }

    func deleteBackward() {
        deleteFeedback.impactOccurred(intensity: 0.7)
    }

    func suggestionAccepted() {
        suggestionFeedback.notificationOccurred(.success)
    }
}

// MARK: - Data Extension

extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let start = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let end   = hexString.index(start, offsetBy: 2)
            guard let byte = UInt8(hexString[start..<end], radix: 16) else { return nil }
            data.append(byte)
        }
        self = data
    }
}
