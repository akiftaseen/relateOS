import Foundation

// MARK: - Application State Models

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let displayName: String
    let authProvider: AuthProvider
    let createdAt: Date
    let language: LanguagePreference
    let onboardingComplete: Bool
    
    enum AuthProvider: String, Codable {
        case apple
        case google
        case email
    }
}

enum LanguagePreference: String, Codable {
    case english = "en"
    case cantonese = "zh-HK"
    case mandarin = "zh-CN"
}

struct HealthScore: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let score: Double // 0.0 to 100.0
    let positiveWeight: Double
    let negativeWeight: Double
    let validationMarkers: Int
    let conflictMarkers: Int
    let timestamp: Date
    let weeklyAverage: Double?
}

struct InteractionToken: Codable, Sendable {
    let text: String
    let timestamp: Date
    let sentiment: SentimentType
    let emotionalWeight: Double
    let faceSavingIndicator: Bool
    
    enum SentimentType: String, Codable, Sendable {
        case positive
        case neutral
        case negative
    }
}

struct WisdomPost: Codable, Identifiable {
    let id: UUID
    let anonymousHandle: String
    let content: String
    let redactedContent: String
    let upvotes: Int
    let replies: Int
    let createdAt: Date
    let category: PostCategory
    
    enum PostCategory: String, Codable {
        case advice
        case experience
        case question
        case reflection
    }
}

struct AppConfiguration {
    static let appGroup = "group.com.relateos.keyboard"
    static let keyboardBundleID = "com.akiftaseen.relateos.keyboard"
    static let supabaseURL = "https://your-supabase-url.supabase.co"
    static let supabaseAnonKey = "your-supabase-anon-key"
    static let cloudflareWorkerURL = "https://your-worker.your-domain.com"
}

enum AppError: LocalizedError {
    case authenticationFailed(String)
    case networkError(String)
    case validationError(String)
    case supabaseError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .supabaseError(let message):
            return "Database error: \(message)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
