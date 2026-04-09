import Foundation

// MARK: - Supabase Service (Swift 6 Actor)

@globalActor actor SupabaseActor {
    static let shared = SupabaseActor()
}

@SupabaseActor
final class SupabaseService {
    
    private let baseURL = URL(string: AppConfiguration.supabaseURL)!
    private let anonKey = AppConfiguration.supabaseAnonKey
    private let session = URLSession.shared
    
    // MARK: - User Management
    
    func createUser(_ user: User) async throws {
        let endpoint = baseURL.appendingPathComponent("rest/v1/users")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(user)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw AppError.supabaseError("Failed to create user")
        }
    }
    
    func fetchUser(_ id: UUID) async throws -> User {
        let endpoint = baseURL.appendingPathComponent("rest/v1/users")
            .appending(queryItems: [URLQueryItem(name: "id", value: id.uuidString)])
        
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let (data, _) = try await session.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let users = try decoder.decode([User].self, from: data)
        
        guard let user = users.first else {
            throw AppError.supabaseError("User not found")
        }
        
        return user
    }
    
    // MARK: - Health Score Operations
    
    func saveHealthScore(_ score: HealthScore) async throws {
        let endpoint = baseURL.appendingPathComponent("rest/v1/health_scores")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(score)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw AppError.supabaseError("Failed to save health score")
        }
    }
    
    func fetchWeeklyScores(userId: UUID) async throws -> [HealthScore] {
        let endpoint = baseURL.appendingPathComponent("rest/v1/health_scores")
            .appending(queryItems: [
                URLQueryItem(name: "user_id", value: userId.uuidString),
                URLQueryItem(name: "order", value: "timestamp.desc"),
                URLQueryItem(name: "limit", value: "7")
            ])
        
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let (data, _) = try await session.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let scores = try decoder.decode([HealthScore].self, from: data)
        
        return scores
    }
    
    // MARK: - Wisdom Circle Posts
    
    func createPost(_ post: WisdomPost) async throws {
        let endpoint = baseURL.appendingPathComponent("rest/v1/wisdom_posts")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(post)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw AppError.supabaseError("Failed to create post")
        }
    }
    
    func fetchWisdomPosts(limit: Int = 20, offset: Int = 0) async throws -> [WisdomPost] {
        let endpoint = baseURL.appendingPathComponent("rest/v1/wisdom_posts")
            .appending(queryItems: [
                URLQueryItem(name: "order", value: "upvotes.desc,created_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ])
        
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let (data, _) = try await session.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let posts = try decoder.decode([WisdomPost].self, from: data)
        
        return posts
    }
    
    func upvotePost(_ postId: UUID) async throws {
        let endpoint = baseURL.appendingPathComponent("rest/v1/wisdom_post_upvotes")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let payload = ["post_id": postId.uuidString]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw AppError.supabaseError("Failed to upvote post")
        }
    }
    
    // MARK: - Utility
    
    func testConnection() async throws {
        let endpoint = baseURL.appendingPathComponent("rest/v1/")
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode < 400 else {
            throw AppError.networkError("Supabase connection failed")
        }
    }
}
