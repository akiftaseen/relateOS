import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - ========== APP MODELS ==========

enum LanguagePreference: String, Codable {
    case english = "en"
    case cantonese = "zh-HK"
    case mandarin = "zh-CN"
}

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let displayName: String
    let createdAt: Date
    let language: LanguagePreference
    let onboardingComplete: Bool
}

enum AppError: LocalizedError {
    case authenticationFailed(String)
    case networkError(String)
    case validationError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - ========== AUTHENTICATION ==========

@globalActor actor AuthenticationActor {
    static let shared = AuthenticationActor()
}

@AuthenticationActor
final class AuthenticationService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    init() {
        checkAuthStatus()
    }
    
    func signUpWithEmail(_ email: String, password: String) async throws -> User {
        guard isValidEmail(email) else {
            throw AppError.validationError("Invalid email format")
        }
        
        let newUser = User(
            id: UUID(),
            email: email,
            displayName: email.split(separator: "@").first.map(String.init) ?? "User",
            createdAt: Date(),
            language: .english,
            onboardingComplete: false
        )
        
        self.currentUser = newUser
        self.isAuthenticated = true
        return newUser
    }
    
    func signInWithEmail(_ email: String, password: String) async throws -> User {
        guard isValidEmail(email) else {
            throw AppError.validationError("Invalid email format")
        }
        
        let user = User(
            id: UUID(),
            email: email,
            displayName: email.split(separator: "@").first.map(String.init) ?? "User",
            createdAt: Date(),
            language: .english,
            onboardingComplete: false
        )
        
        self.currentUser = user
        self.isAuthenticated = true
        return user
    }
    
    func signOut() async throws {
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    private func checkAuthStatus() {
        // Check Keychain or UserDefaults
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

// MARK: - ========== VIEWS ==========

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.09, green: 0.13, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.cyan)
                    
                    Text("RelateOS")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Relationship Intelligence Keyboard")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct AuthenticationView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var showSignUp = false
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.09, green: 0.13, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.cyan)
                    
                    Text("RelateOS")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(showSignUp ? "Create Account" : "Welcome Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.top, 32)
                
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    
                    SecureField("Password", text: $password)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                .padding(16)
                
                Button(action: handleAuth) {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text(showSignUp ? "Create Account" : "Sign In")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.cyan)
                .foregroundColor(.black)
                .cornerRadius(8)
                .padding(16)
            }
            .padding()
        }
    }
    
    private func handleAuth() {
        isLoading = true
        Task {
            do {
                if showSignUp {
                    _ = try await authService.signUpWithEmail(email, password: password)
                } else {
                    _ = try await authService.signInWithEmail(email, password: password)
                }
            } catch {
                print("Auth error: \(error)")
            }
            isLoading = false
        }
    }
}

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var selectedLanguage: LanguagePreference = .english
    @State private var consentGiven = false
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.09, green: 0.13, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                ProgressView(value: Double(currentStep) / 2.0).tint(.cyan).padding()
                
                TabView(selection: $currentStep) {
                    VStack {
                        Text("Choose Language").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding()
                        Spacer()
                    }
                    .tag(0)
                    
                    VStack {
                        Text("Confirm Privacy").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding()
                        Spacer()
                    }
                    .tag(1)
                    
                    VStack {
                        Text("All Set!").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding()
                        Spacer()
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                HStack {
                    if currentStep > 0 {
                        Button("Back") { currentStep -= 1 }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(currentStep == 2 ? "Done" : "Next") { if currentStep < 2 { currentStep += 1 } }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.cyan)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                .padding(16)
            }
        }
    }
}

struct DashboardView: View {
    @State private var score = 72.0
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.09, green: 0.13, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Text("Relationship Health").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding()
                
                ZStack {
                    Circle().fill(Color.white.opacity(0.05)).frame(width: 180, height: 180)
                    Circle().trim(from: 0, to: score / 100).stroke(Color.cyan, lineWidth: 8).frame(width: 180, height: 180).rotationEffect(.degrees(-90))
                    VStack {
                        Text("\(Int(score))").font(.system(size: 48, weight: .bold)).foregroundColor(.cyan)
                        Text("/ 100").font(.system(size: 14)).foregroundColor(.gray)
                    }
                }
                .padding(24)
                
                Spacer()
            }
        }
    }
}

struct WisdomCircleView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.09, green: 0.13, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Text("Wisdom Circle").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding()
                Spacer()
                Text("Coming Soon").font(.system(size: 16)).foregroundColor(.gray)
                Spacer()
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showSignOut = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.09, green: 0.13, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Text("Settings").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding()
                
                if let user = authService.currentUser {
                    Text(user.displayName).foregroundColor(.white).padding()
                    Text(user.email).foregroundColor(.gray).padding()
                }
                
                Spacer()
                
                Button("Sign Out") { showSignOut = true }
                    .padding(12)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                    .padding()
            }
        }
        .alert("Sign Out?", isPresented: $showSignOut) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task { try? await authService.signOut() }
            }
        } message: {
            Text("Are you sure?")
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.09, green: 0.13, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                DashboardView().tag(0).tabItem { Label("Health", systemImage: "heart.fill") }
                WisdomCircleView().tag(1).tabItem { Label("community", systemImage: "bubble.right.fill") }
                SettingsView().tag(2).tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .tint(.cyan)
        }
    }
}

struct AppRootView: View {
    @StateObject private var authService = AuthenticationService()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if authService.currentUser?.onboardingComplete == true {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            } else {
                AuthenticationView()
            }
        }
        .environmentObject(authService)
    }
}

// MARK: - ========== BRIDGE HELPER ==========

final class KeyboardBridgeHandlerCore {

    private static let appGroup = "group.com.relateos.keyboard"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func saveCachedMessages(_ messages: [String]) {
        sharedDefaults?.set(messages, forKey: "cached_messages")
    }

    static func getCachedMessages() -> [String] {
        sharedDefaults?.array(forKey: "cached_messages") as? [String] ?? []
    }

    static func appendAnalysisLog(userId: String, healthScore: Double, emotion: String) {
        var logs = sharedDefaults?.array(forKey: "analysis_logs") as? [[String: Any]] ?? []
        logs.append([
            "user_id": userId,
            "health_score_snapshot": healthScore,
            "primary_emotion_detected": emotion,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ])
        sharedDefaults?.set(logs, forKey: "analysis_logs")
    }

    static func latestHealthSummary() -> (average7d: Double, latest: Double, count: Int) {
        let average = sharedDefaults?.double(forKey: "health_delta_7d_average") ?? 0
        let latest = sharedDefaults?.double(forKey: "health_delta_7d_latest") ?? 0
        let count = sharedDefaults?.integer(forKey: "health_delta_7d_count") ?? 0
        return (average, latest, count)
    }
}

// MARK: - Native Supabase Config

enum NativeSupabaseConfig {
    static var url: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }

    static var publishableKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String ?? ""
    }

    static var isConfigured: Bool {
        !url.isEmpty && !publishableKey.isEmpty && !url.hasPrefix("YOUR_") && !publishableKey.hasPrefix("YOUR_")
    }
}

// MARK: - Native Auth Service (REST)

final class NativeAuthService {
    private let appGroup = "group.com.relateos.keyboard"

    private var accessToken: String? {
        UserDefaults(suiteName: appGroup)?.string(forKey: "supabase_access_token")
    }

    private func configuredRequest(path: String, method: String = "GET") throws -> URLRequest {
        guard NativeSupabaseConfig.isConfigured else { throw NativeAuthError.missingConfiguration }
        guard let url = URL(string: "\(NativeSupabaseConfig.url)/rest/v1/\(path)") else {
            throw NativeAuthError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(NativeSupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")

        guard let token = accessToken, !token.isEmpty else {
            throw NativeAuthError.missingAccessToken
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    func fetchUserData(userId: String) async throws -> NativeUserModel {
        var request = try configuredRequest(path: "users?id=eq.\(userId)&select=*&limit=1")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NativeAuthError.requestFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let users = try decoder.decode([NativeUserModel].self, from: data)
        guard let user = users.first else { throw NativeAuthError.invalidResponse }
        return user
    }

    func completeOnboarding(userId: String) async throws {
        try await patchUser(userId: userId, body: ["onboarding_completed": true])
    }

    func saveBaselineWeights(userId: String, weights: NativeBaselineWeights) async throws {
        let payload: [String: Any] = [
            "baseline_weights": [
                "w1": weights.w1,
                "w2": weights.w2,
                "w3": weights.w3,
                "quiz_percentile": weights.quizPercentile
            ]
        ]
        try await patchUser(userId: userId, body: payload)
    }

    func logKeyboardConsent(userId: String) async throws {
        try await patchUser(
            userId: userId,
            body: ["consent_keyboard_granted": ISO8601DateFormatter().string(from: Date())]
        )
    }

    private func patchUser(userId: String, body: [String: Any]) async throws {
        var request = try configuredRequest(path: "users?id=eq.\(userId)", method: "PATCH")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NativeAuthError.requestFailed
        }
    }
}
