import Foundation

// MARK: - Health Score Service (Swift 6 Actor)

@globalActor actor HealthScoreActor {
    static let shared = HealthScoreActor()
}

@HealthScoreActor
final class HealthScoreService {
    
    // MARK: - Configuration Constants
    
    private let alphaWeight: Double = 0.7      // Sentiment weight coefficient
    private let betaWeight: Double = 0.3       // Resolution efficacy coefficient
    
    // Cantonese face-saving and harmony markers
    private let faceSavingKeywords = [
        "唔使理我", "隨便啦", "ok la", "無所謂", "隨你", "你開心就好",
        "我體諒你", "我明白", "慢慢講", "冇緊要", "冇事", "算啦"
    ]
    
    // Conflict escalation markers
    private let conflictKeywords = [
        "點解", "為乜", "你係咁", "算你狠", "我夠鐘", "好啦好啦",
        "你就係", "我無辦法", "隨便"
    ]
    
    // MARK: - Health Score Calculation
    
    func calculateHealthScore(
        interactions: [InteractionToken],
        windowDays: Int = 7
    ) -> HealthScore {
        let userId = UUID() // Would come from current user
        let score = computeScore(from: interactions)
        
        return HealthScore(
            id: UUID(),
            userId: userId,
            score: score,
            positiveWeight: Double(interactions.filter { $0.sentiment == .positive }.count),
            negativeWeight: Double(interactions.filter { $0.sentiment == .negative }.count),
            validationMarkers: countValidationMarkers(in: interactions),
            conflictMarkers: countConflictMarkers(in: interactions),
            timestamp: Date(),
            weeklyAverage: nil
        )
    }
    
    /// Formula: H_score = α * Σ(P_t - N_t) + β * (V_t / (C_t + 1))
    /// Where:
    /// - P_t: positive sentiment at turn t
    /// - N_t: negative sentiment at turn t
    /// - V_t: validation/face-saving markers
    /// - C_t: conflict/escalation markers
    private func computeScore(from interactions: [InteractionToken]) -> Double {
        let positiveSum = interactions
            .filter { $0.sentiment == .positive }
            .map { $0.emotionalWeight }
            .reduce(0, +)
        
        let negativeSum = interactions
            .filter { $0.sentiment == .negative }
            .map { $0.emotionalWeight }
            .reduce(0, +)
        
        let validationCount = Double(countValidationMarkers(in: interactions))
        let conflictCount = Double(countConflictMarkers(in: interactions))
        
        let sentimentTerm = alphaWeight * (positiveSum - negativeSum)
        let resolutionTerm = betaWeight * (validationCount / (conflictCount + 1))
        
        let rawScore = sentimentTerm + resolutionTerm
        return max(0, min(100, (rawScore + 50) * 0.5)) // Normalize to 0-100
    }
    
    private func countValidationMarkers(in interactions: [InteractionToken]) -> Int {
        interactions.filter { $0.faceSavingIndicator }.count
    }
    
    private func countConflictMarkers(in interactions: [InteractionToken]) -> Int {
        interactions.filter { token in
            conflictKeywords.contains { keyword in
                token.text.lowercased().contains(keyword.lowercased())
            }
        }.count
    }
    
    // MARK: - Sentiment Analysis
    
    func analyzeSentiment(_ text: String) -> InteractionToken {
        let sentiment = determineSentiment(text)
        let emotionalWeight = calculateEmotionalWeight(for: text)
        let hasFaceSaving = checkForFaceSavingMarkers(in: text)
        
        return InteractionToken(
            text: text,
            timestamp: Date(),
            sentiment: sentiment,
            emotionalWeight: emotionalWeight,
            faceSavingIndicator: hasFaceSaving
        )
    }
    
    private func determineSentiment(_ text: String) -> InteractionToken.SentimentType {
        let positiveKeywords = [
            "好", "開心", "謝謝", "感謝", "愛", "beautiful", "happy",
            "thank", "love", "wonderful", "great", "excellent", "amazing"
        ]
        let negativeKeywords = [
            "唔好", "傷心", "討厭", "煩", "sad", "bad", "hate", "angry",
            "upset", "terrible", "awful", "disgusting"
        ]
        
        let lowercased = text.lowercased()
        let positiveMatches = positiveKeywords.filter { lowercased.contains($0) }.count
        let negativeMatches = negativeKeywords.filter { lowercased.contains($0) }.count
        
        if positiveMatches > negativeMatches {
            return .positive
        } else if negativeMatches > positiveMatches {
            return .negative
        } else {
            return .neutral
        }
    }
    
    private func calculateEmotionalWeight(for text: String) -> Double {
        let length = Double(text.count)
        let baseWeight: Double
        
        if length < 10 {
            baseWeight = 0.5
        } else if length < 50 {
            baseWeight = 0.7
        } else if length < 200 {
            baseWeight = 0.85
        } else {
            baseWeight = 1.0
        }
        
        // Boost for repeated punctuation (emotional intensity)
        let exclamationCount = Double(text.filter { $0 == "!" }.count)
        let questionCount = Double(text.filter { $0 == "?" }.count)
        let emotionalPunctuation = min((exclamationCount + questionCount) * 0.1, 0.3)
        
        return min(baseWeight + emotionalPunctuation, 1.0)
    }
    
    private func checkForFaceSavingMarkers(in text: String) -> Bool {
        faceSavingKeywords.contains { keyword in
            text.lowercased().contains(keyword.lowercased())
        }
    }
    
    // MARK: - Weekly Aggregation
    
    func calculateWeeklyAverage(_ scores: [HealthScore]) -> Double? {
        guard !scores.isEmpty else { return nil }
        return scores.map { $0.score }.reduce(0, +) / Double(scores.count)
    }
}

// MARK: - Health Score Processor (Message Capture from Keyboard)

@HealthScoreActor
final class HealthScoreProcessor {
    
    private let healthScoreService = HealthScoreService()
    private var messageBuffer: [InteractionToken] = []
    private let maxBufferSize = 20
    
    func appendMessage(_ text: String) {
        let token = healthScoreService.analyzeSentiment(text)
        messageBuffer.append(token)
        
        if messageBuffer.count > maxBufferSize {
            messageBuffer.removeFirst()
        }
    }
    
    func getProcessedScore() -> HealthScore {
        healthScoreService.calculateHealthScore(interactions: messageBuffer)
    }
    
    func clearBuffer() {
        messageBuffer.removeAll()
    }
}
