// KeyboardAIEngine.swift
// RelateOS — On-keyboard AI engine: encrypt → Cloudflare → Gemini 2.5 Pro

import Foundation
import UIKit
import CryptoKit

// MARK: - Local Health Scoring

struct InteractionToken: Sendable {
    let positiveWeight: Double
    let negativeWeight: Double
    let isFaceSaving: Bool
    let isConflict: Bool
}

actor HealthScoreProcessor {
    private var conversationalTokens: [InteractionToken] = []

    private let alpha: Double = 1.2
    private let beta: Double = 0.8
    private let maxTokenWindow = 200

    private let positiveMarkers = [
        "thanks", "thank you", "appreciate", "sorry", "understand", "agree", "love",
        "多謝", "唔該", "明白", "對唔住", "辛苦", "我會改", "我聽到"
    ]

    private let negativeMarkers = [
        "whatever", "shut up", "hate", "annoying", "useless", "leave me alone",
        "算啦", "隨便", "你厲害", "有點意思", "唔想講", "煩", "冇用"
    ]

    private let faceSavingMarkers = [
        "let's", "maybe", "can we", "i feel", "i hear you",
        "不如", "可唔可以", "慢慢", "我明白", "俾個面", "我聽到"
    ]

    private let conflictMarkers = [
        "always", "never", "you're wrong", "your fault",
        "成日", "永遠", "都係你", "你錯", "算吧", "離婚"
    ]

    func append(text: String) {
        let token = tokenize(text: text)
        conversationalTokens.append(token)
        if conversationalTokens.count > maxTokenWindow {
            conversationalTokens.removeFirst(conversationalTokens.count - maxTokenWindow)
        }
    }

    func calculateHScore() -> Double {
        let baseSentiment = conversationalTokens.reduce(0.0) { accumulated, token in
            accumulated + (token.positiveWeight - token.negativeWeight)
        }

        let validationCount = conversationalTokens.filter { $0.isFaceSaving }.count
        let conflictCount = conversationalTokens.filter { $0.isConflict }.count
        let resolutionRatio = Double(validationCount) / Double(conflictCount + 1)

        return (alpha * baseSentiment) + (beta * resolutionRatio)
    }

    func latestDelta() -> Float {
        let raw = calculateHScore()
        let bounded = tanh(raw / 6.0)
        return Float(bounded)
    }

    private func tokenize(text: String) -> InteractionToken {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return InteractionToken(positiveWeight: 0, negativeWeight: 0, isFaceSaving: false, isConflict: false)
        }

        let positiveMatches = positiveMarkers.filter { normalized.contains($0) }.count
        let negativeMatches = negativeMarkers.filter { normalized.contains($0) }.count
        let faceSaving = faceSavingMarkers.contains { normalized.contains($0) }
        let conflict = conflictMarkers.contains { normalized.contains($0) }

        let positiveWeight = Double(positiveMatches) * 0.9 + (faceSaving ? 0.4 : 0)
        let negativeWeight = Double(negativeMatches) * 1.0 + (conflict ? 0.5 : 0)

        return InteractionToken(
            positiveWeight: positiveWeight,
            negativeWeight: negativeWeight,
            isFaceSaving: faceSaving,
            isConflict: conflict
        )
    }
}

// MARK: - AI Result Models

struct AIAnalysisResult {
    let suggestions: [SuggestionModel]
    let subtextExplanation: String?
    let detectedEmotion: String?
    let healthDelta: Float?
}

// MARK: - AI Engine

actor KeyboardAIEngine {

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
        let healthDelta: Float?
        if let value = json["health_delta"] as? Float {
            healthDelta = value
        } else if let value = json["health_delta"] as? Double {
            healthDelta = Float(value)
        } else if let value = json["health_delta"] as? NSNumber {
            healthDelta = value.floatValue
        } else {
            healthDelta = nil
        }

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

struct HealthTrendSample: Codable {
    let delta: Float
    let timestamp: Date
}

// MARK: - Message Capture Manager

final class MessageCaptureManager {

    private let sharedDefaults = UserDefaults(suiteName: "group.com.relateos.keyboard")
    private let maxStoredMessages = 20
    private let healthSamplesKey = "health_delta_samples"
    private let maxStoredHealthSamples = 500

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

    // MARK: - Health Trend Samples

    func appendHealthSample(delta: Float, at timestamp: Date = Date()) {
        var samples = readHealthSamples(days: 14)
        samples.append(HealthTrendSample(delta: delta, timestamp: timestamp))

        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        samples = samples.filter { $0.timestamp >= cutoff }

        if samples.count > maxStoredHealthSamples {
            samples = Array(samples.suffix(maxStoredHealthSamples))
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(samples) {
            sharedDefaults?.set(data, forKey: healthSamplesKey)
        }
    }

    func readHealthSamples(days: Int = 7) -> [HealthTrendSample] {
        guard let data = sharedDefaults?.data(forKey: healthSamplesKey) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let allSamples = try? decoder.decode([HealthTrendSample].self, from: data) else { return [] }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return allSamples.filter { $0.timestamp >= cutoff }
    }

    func sevenDayTrendSummary() -> (average: Float, latest: Float, count: Int) {
        let samples = readHealthSamples(days: 7)
        guard !samples.isEmpty else { return (0, 0, 0) }

        let sum = samples.reduce(Float(0)) { partial, sample in
            partial + sample.delta
        }
        let average = sum / Float(samples.count)
        let latest = samples.last?.delta ?? 0
        return (average, latest, samples.count)
    }
}

// MARK: - Haptic Engine

@MainActor
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
