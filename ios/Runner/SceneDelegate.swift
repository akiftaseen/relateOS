import UIKit
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

private struct CapturedConversationMessage: Codable, Identifiable {
    let id: String
    let text: String
    let isOutgoing: Bool
    let timestamp: Date
    let detectedLanguage: String?
}

enum WisdomPostCategory: String, Codable, CaseIterable {
    case advice
    case experience
    case question
    case reflection
}

struct WisdomPost: Codable, Identifiable {
    let id: UUID
    let anonymousHandle: String
    let content: String
    let redactedContent: String
    let upvotes: Int
    let replies: Int
    let createdAt: Date
    let category: WisdomPostCategory

    private enum CodingKeys: String, CodingKey {
        case id
        case anonymousHandle = "anonymous_handle"
        case content
        case redactedContent = "redacted_content"
        case upvotes
        case replies
        case createdAt = "created_at"
        case category
    }
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

// MARK: - ========== APP BACKEND ==========

enum AppRuntimeConfig {
    static var localOnlyMode: Bool {
        Bundle.main.object(forInfoDictionaryKey: "RELATEOS_LOCAL_TEST_MODE") as? Bool ?? false
    }
}

enum AppBackendConfig {
    static var workerURL: String {
        Bundle.main.object(forInfoDictionaryKey: "RELATEOS_WORKER_URL") as? String ?? "https://relateos-ai-proxy.relateos.workers.dev"
    }

    static var wisdomPostsURL: URL? {
        guard !AppRuntimeConfig.localOnlyMode else { return nil }
        return URL(string: "\(workerURL)/api/v1/wisdom/posts")
    }
}

func wisdomCircleMockPosts() -> [WisdomPost] {
    [
        WisdomPost(
            id: UUID(),
            anonymousHandle: "Seeker7",
            content: "How do you handle disagreements when emotions are high?",
            redactedContent: "How do you handle disagreements when emotions are high?",
            upvotes: 24,
            replies: 8,
            createdAt: Date().addingTimeInterval(-3600),
            category: .question
        ),
        WisdomPost(
            id: UUID(),
            anonymousHandle: "Listener42",
            content: "Learning to listen before reacting changed everything for me.",
            redactedContent: "Learning to listen before reacting changed everything for me.",
            upvotes: 156,
            replies: 23,
            createdAt: Date().addingTimeInterval(-7200),
            category: .advice
        ),
        WisdomPost(
            id: UUID(),
            anonymousHandle: "Wanderer19",
            content: "After years of small misunderstandings, we finally talked honestly.",
            redactedContent: "After years of small misunderstandings, we finally talked honestly.",
            upvotes: 89,
            replies: 12,
            createdAt: Date().addingTimeInterval(-86400),
            category: .experience
        )
    ]
}

// MARK: - ========== SUPABASE LAYER ==========

enum NativeSupabaseConfig {
    static var url: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }

    static var publishableKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String ?? ""
    }

    static var isConfigured: Bool {
        !AppRuntimeConfig.localOnlyMode
            && !url.isEmpty
            && !publishableKey.isEmpty
            && !url.hasPrefix("YOUR_")
            && !publishableKey.hasPrefix("YOUR_")
    }
}

private struct SupabaseAuthEnvelope: Decodable {
    struct Session: Decodable {
        let accessToken: String

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }

    struct AuthUser: Decodable {
        let id: String
        let email: String?
        let createdAt: Date?

        private enum CodingKeys: String, CodingKey {
            case id
            case email
            case createdAt = "created_at"
        }
    }

    let accessToken: String?
    let session: Session?
    let user: AuthUser?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case session
        case user
    }
}

private struct SupabaseUserRow: Decodable {
    let id: String
    let email: String
    let displayName: String?
    let createdAt: Date?
    let languagePreference: String?
    let onboardingCompleted: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case createdAt = "created_at"
        case languagePreference = "language_preference"
        case onboardingCompleted = "onboarding_completed"
    }
}

actor NativeSupabaseService {
    private let appGroup = "group.com.relateos.keyboard"
    private let sessionTokenKey = "supabase_access_token"
    private let cachedUserKey = "native_cached_user"

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    private var accessToken: String? {
        sharedDefaults.string(forKey: sessionTokenKey)
    }

    func getCachedUser() -> User? {
        guard let data = sharedDefaults.data(forKey: cachedUserKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    func cacheUser(_ user: User) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        sharedDefaults.set(data, forKey: cachedUserKey)
    }

    func clearSession() {
        sharedDefaults.removeObject(forKey: sessionTokenKey)
        sharedDefaults.removeObject(forKey: cachedUserKey)
    }

    func signUp(email: String, password: String) async throws -> User {
        let envelope = try await callAuth(
            path: "signup",
            body: ["email": email, "password": password]
        )
        let token = envelope.session?.accessToken ?? envelope.accessToken
        if let token, !token.isEmpty {
            sharedDefaults.set(token, forKey: sessionTokenKey)
        }

        let userId = envelope.user?.id
        let fallbackUser = mappedFallbackUser(email: email, createdAt: envelope.user?.createdAt)

        guard let userId else {
            cacheUser(fallbackUser)
            return fallbackUser
        }

        try? await upsertUser(userId: userId, email: email, language: .english)
        if let profile = try? await fetchUserData(userId: userId), let mapped = mapUser(from: profile) {
            cacheUser(mapped)
            return mapped
        }

        cacheUser(fallbackUser)
        return fallbackUser
    }

    func signIn(email: String, password: String) async throws -> User {
        let envelope = try await callAuth(
            path: "token?grant_type=password",
            body: ["email": email, "password": password]
        )
        let token = envelope.session?.accessToken ?? envelope.accessToken
        if let token, !token.isEmpty {
            sharedDefaults.set(token, forKey: sessionTokenKey)
        }

        let userId = envelope.user?.id
        if let userId, let profile = try? await fetchUserData(userId: userId), let mapped = mapUser(from: profile) {
            cacheUser(mapped)
            return mapped
        }

        let fallback = mappedFallbackUser(email: email, createdAt: envelope.user?.createdAt)
        cacheUser(fallback)
        return fallback
    }

    func completeOnboarding(userId: String, language: LanguagePreference) async throws {
        guard let token = accessToken, !token.isEmpty else { return }
        let payload: [String: Any] = [
            "onboarding_completed": true,
            "language_preference": language.rawValue
        ]
        _ = try await restRequest(
            path: "users?id=eq.\(userId)",
            method: "PATCH",
            token: token,
            body: payload,
            prefer: "return=minimal"
        )
    }

    private func callAuth(path: String, body: [String: Any]) async throws -> SupabaseAuthEnvelope {
        guard NativeSupabaseConfig.isConfigured else {
            throw AppError.networkError("Supabase is not configured")
        }
        guard let url = URL(string: "\(NativeSupabaseConfig.url)/auth/v1/\(path)") else {
            throw AppError.networkError("Invalid Supabase URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(NativeSupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("No response from Supabase")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Auth request failed"
            throw AppError.authenticationFailed(message)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SupabaseAuthEnvelope.self, from: data)
    }

    private func upsertUser(userId: String, email: String, language: LanguagePreference) async throws {
        guard let token = accessToken, !token.isEmpty else { return }
        let payload: [String: Any] = [
            "id": userId,
            "email": email,
            "display_name": email.split(separator: "@").first.map(String.init) ?? "User",
            "language_preference": language.rawValue,
            "onboarding_completed": false
        ]
        _ = try await restRequest(
            path: "users?on_conflict=id",
            method: "POST",
            token: token,
            body: payload,
            prefer: "resolution=merge-duplicates,return=representation"
        )
    }

    private func fetchUserData(userId: String) async throws -> SupabaseUserRow {
        guard let token = accessToken, !token.isEmpty else {
            throw AppError.authenticationFailed("Missing access token")
        }
        let data = try await restRequest(
            path: "users?id=eq.\(userId)&select=*&limit=1",
            method: "GET",
            token: token,
            body: nil,
            prefer: "return=representation"
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let users = try decoder.decode([SupabaseUserRow].self, from: data)
        guard let user = users.first else {
            throw AppError.networkError("User profile not found")
        }
        return user
    }

    private func restRequest(
        path: String,
        method: String,
        token: String,
        body: [String: Any]?,
        prefer: String
    ) async throws -> Data {
        guard NativeSupabaseConfig.isConfigured else {
            throw AppError.networkError("Supabase is not configured")
        }
        guard let url = URL(string: "\(NativeSupabaseConfig.url)/rest/v1/\(path)") else {
            throw AppError.networkError("Invalid Supabase URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(NativeSupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(prefer, forHTTPHeaderField: "Prefer")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Supabase request failed"
            throw AppError.networkError(message)
        }
        return data
    }

    private func mapUser(from row: SupabaseUserRow) -> User? {
        guard let uuid = UUID(uuidString: row.id) else { return nil }
        let language = LanguagePreference(rawValue: row.languagePreference ?? "") ?? .english
        return User(
            id: uuid,
            email: row.email,
            displayName: row.displayName ?? row.email.split(separator: "@").first.map(String.init) ?? "User",
            createdAt: row.createdAt ?? Date(),
            language: language,
            onboardingComplete: row.onboardingCompleted ?? false
        )
    }

    private func mappedFallbackUser(email: String, createdAt: Date?) -> User {
        User(
            id: UUID(),
            email: email,
            displayName: email.split(separator: "@").first.map(String.init) ?? "User",
            createdAt: createdAt ?? Date(),
            language: .english,
            onboardingComplete: false
        )
    }
}

// MARK: - ========== AUTHENTICATION ==========

@MainActor
final class AuthenticationService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    private let supabaseService = NativeSupabaseService()
    private let localUserKey = "relateos_local_user"
    private let localDefaults = UserDefaults.standard
    
    init() {
        checkAuthStatus()
    }
    
    func signUpWithEmail(_ email: String, password: String) async throws -> User {
        guard isValidEmail(email) else {
            throw AppError.validationError("Invalid email format")
        }
        guard !password.isEmpty else {
            throw AppError.validationError("Password is required")
        }

        let newUser: User
        if NativeSupabaseConfig.isConfigured {
            newUser = try await supabaseService.signUp(email: email, password: password)
        } else {
            newUser = User(
                id: UUID(),
                email: email,
                displayName: email.split(separator: "@").first.map(String.init) ?? "User",
                createdAt: Date(),
                language: .english,
                onboardingComplete: false
            )
        }
        
        currentUser = newUser
        isAuthenticated = true
        cacheLocalUserIfNeeded(newUser)
        return newUser
    }
    
    func signInWithEmail(_ email: String, password: String) async throws -> User {
        guard isValidEmail(email) else {
            throw AppError.validationError("Invalid email format")
        }
        guard !password.isEmpty else {
            throw AppError.validationError("Password is required")
        }
        
        let user: User
        if NativeSupabaseConfig.isConfigured {
            user = try await supabaseService.signIn(email: email, password: password)
        } else {
            user = User(
                id: UUID(),
                email: email,
                displayName: email.split(separator: "@").first.map(String.init) ?? "User",
                createdAt: Date(),
                language: .english,
                onboardingComplete: false
            )
        }
        
        currentUser = user
        isAuthenticated = true
        cacheLocalUserIfNeeded(user)
        return user
    }

    func completeOnboarding(language: LanguagePreference) async {
        guard let user = currentUser else { return }

        if NativeSupabaseConfig.isConfigured {
            try? await supabaseService.completeOnboarding(
                userId: user.id.uuidString,
                language: language
            )
        }

        currentUser = User(
            id: user.id,
            email: user.email,
            displayName: user.displayName,
            createdAt: user.createdAt,
            language: language,
            onboardingComplete: true
        )
        if let updated = currentUser {
            cacheLocalUserIfNeeded(updated)
        }
    }
    
    func signOut() async throws {
        await supabaseService.clearSession()
        localDefaults.removeObject(forKey: localUserKey)
        currentUser = nil
        isAuthenticated = false
    }
    
    private func checkAuthStatus() {
        if AppRuntimeConfig.localOnlyMode {
            if let cached = localCachedUser() {
                currentUser = cached
                isAuthenticated = true
            }
            return
        }

        Task { @MainActor in
            if let cached = await supabaseService.getCachedUser() {
                currentUser = cached
                isAuthenticated = true
            }
        }
    }

    private func cacheLocalUserIfNeeded(_ user: User) {
        guard AppRuntimeConfig.localOnlyMode else { return }
        guard let data = try? JSONEncoder().encode(user) else { return }
        localDefaults.set(data, forKey: localUserKey)
    }

    private func localCachedUser() -> User? {
        guard let data = localDefaults.data(forKey: localUserKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

// MARK: - ========== SCENE DELEGATE ==========

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: NativeRootView())
        self.window = window
        window.makeKeyAndVisible()
    }
}

private struct NativeRootView: View {
    @State private var showHome = false

    var body: some View {
        Group {
            if showHome {
                AppRootView()
            } else {
                SplashView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showHome)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                showHome = true
            }
        }
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

                    if AppRuntimeConfig.localOnlyMode {
                        Text("Local test mode enabled: auth and community run on-device")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
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
                
                HStack(spacing: 4) {
                    Text(showSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(.gray)
                    
                    Button(action: { showSignUp.toggle() }) {
                        Text(showSignUp ? "Sign In" : "Sign Up")
                            .foregroundColor(.cyan)
                            .fontWeight(.semibold)
                    }
                }
                .font(.system(size: 14))
                .padding(.top, 16)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func handleAuth() {
        isLoading = true
        Task { @MainActor in
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

                        VStack(spacing: 12) {
                            languageButton(.english, label: "English")
                            languageButton(.cantonese, label: "Cantonese")
                            languageButton(.mandarin, label: "Mandarin")
                        }
                        .padding(.horizontal, 24)

                        Spacer()
                    }
                    .tag(0)
                    
                    VStack {
                        Text("All Set!").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding()
                        Spacer()
                    }
                    .tag(1)
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
                    
                    Button(currentStep == 1 ? "Done" : "Next") {
                        if currentStep < 1 {
                            currentStep += 1
                        } else {
                            Task { @MainActor in
                                await authService.completeOnboarding(language: selectedLanguage)
                            }
                        }
                    }
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

    private func languageButton(_ language: LanguagePreference, label: String) -> some View {
        Button(action: { selectedLanguage = language }) {
            HStack {
                Text(label)
                    .foregroundColor(.white)
                Spacer()
                if selectedLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.cyan)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
    }
}

struct DashboardView: View {
    @State private var score = 72.0
    @State private var recentMessages: [CapturedConversationMessage] = []
    private let refreshTimer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()
    
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

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Live Keyboard Capture")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Text("Best effort")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.14))
                            .clipShape(Capsule())
                    }

                    Text("Shows text available from keyboard context. Some apps may limit incoming history visibility.")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.gray)

                    if recentMessages.isEmpty {
                        Text("No captured messages yet. Type in a chat app with the RelateOS keyboard enabled.")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.white.opacity(0.72))
                            .padding(.vertical, 6)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(recentMessages) { message in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(message.isOutgoing ? "You" : "Other")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(message.isOutgoing ? .cyan : .white.opacity(0.85))
                                            .frame(width: 42, alignment: .leading)

                                        Text(message.text)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .lineLimit(3)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .cornerRadius(14)
                .padding(.horizontal, 16)

                
                Spacer()
            }
        }
        .onAppear {
            refreshCapturedMessages()
        }
        .onReceive(refreshTimer) { _ in
            refreshCapturedMessages()
        }
    }

    private func refreshCapturedMessages() {
        guard let defaults = UserDefaults(suiteName: "group.com.relateos.keyboard"),
              let data = defaults.data(forKey: "message_history") else {
            recentMessages = []
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = (try? decoder.decode([CapturedConversationMessage].self, from: data)) ?? []
        recentMessages = Array(decoded.suffix(8))
    }
}

struct WisdomCircleView: View {
    @State private var posts: [WisdomPost] = []
    @State private var selectedCategory: WisdomPostCategory? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var feedStatus = "Connecting to community feed"

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
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wisdom Circle")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Anonymous community reflections")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                HStack(spacing: 10) {
                    Label(feedStatus, systemImage: isLoading ? "arrow.triangle.2.circlepath" : "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(Capsule())

                    Text("\(filteredPosts.count) posts")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.82))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())

                    Spacer()
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        ForEach(WisdomPostCategory.allCases, id: \.self) { category in
                            categoryChip(title: category.rawValue.capitalized, isSelected: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView().tint(.cyan)
                        Text("Loading live posts")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 16)
                    Spacer()
                } else if filteredPosts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 40))
                            .foregroundColor(.cyan.opacity(0.85))

                        Text("No posts yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Be the first to share something useful, honest, or reflective.")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 16)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPosts) { post in
                                WisdomPostCardView(post: post) { postId in
                                    Task { await upvote(postId: postId) }
                                }
                            }
                        }
                        .padding(16)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateWisdomPostView { content, category in
                Task { await submitPost(content: content, category: category) }
            }
        }
        .task {
            await loadPosts()
        }
        .onChange(of: selectedCategory) { _ in }
    }

    private var filteredPosts: [WisdomPost] {
        guard let selectedCategory else { return posts }
        return posts.filter { $0.category == selectedCategory }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.cyan : Color.white.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private func loadPosts() async {
        isLoading = true
        errorMessage = nil
        feedStatus = "Connecting to community feed"

        if AppRuntimeConfig.localOnlyMode {
            posts = wisdomCircleMockPosts()
            feedStatus = "Local test mode"
            isLoading = false
            return
        }

        do {
            let service = WisdomCircleService()
            let loadedPosts = try await service.fetchPosts()
            posts = loadedPosts
            feedStatus = "Live feed connected"
        } catch {
            posts = wisdomCircleMockPosts()
            errorMessage = "Showing local Wisdom Circle sample data"
            feedStatus = "Local sample data"
        }

        isLoading = false
    }

    private func submitPost(content: String, category: WisdomPostCategory) async {
        do {
            let service = WisdomCircleService()
            let post = try await service.createPost(content: content, category: category)
            posts.insert(post, at: 0)
        } catch {
            errorMessage = "Could not submit post right now"
        }
    }

    private func upvote(postId: UUID) async {
        do {
            let service = WisdomCircleService()
            try await service.upvotePost(id: postId)
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index] = WisdomPost(
                    id: posts[index].id,
                    anonymousHandle: posts[index].anonymousHandle,
                    content: posts[index].content,
                    redactedContent: posts[index].redactedContent,
                    upvotes: posts[index].upvotes + 1,
                    replies: posts[index].replies,
                    createdAt: posts[index].createdAt,
                    category: posts[index].category
                )
            }
        } catch {
            errorMessage = "Could not upvote right now"
        }
    }

}

private struct WisdomPostCardView: View {
    let post: WisdomPost
    let onUpvote: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.cyan.opacity(0.25))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(post.anonymousHandle.prefix(1)))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.cyan)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.anonymousHandle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(post.category.rawValue.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }

            Text(post.redactedContent)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white)
                .lineLimit(4)

            HStack(spacing: 18) {
                Button(action: { onUpvote(post.id) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.thumbsup")
                        Text("\(post.upvotes)")
                    }
                    .foregroundColor(.cyan)
                }

                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                    Text("\(post.replies)")
                }
                .foregroundColor(.gray)

                Spacer()
            }
            .font(.system(size: 12, weight: .semibold))
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }
}

private struct CreateWisdomPostView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var category: WisdomPostCategory = .advice
    @State private var isSubmitting = false

    let onSubmit: (String, WisdomPostCategory) -> Void

    var body: some View {
        NavigationView {
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

                VStack(spacing: 16) {
                    Picker("Category", selection: $category) {
                        ForEach(WisdomPostCategory.allCases, id: \.self) { category in
                            Text(category.rawValue.capitalized).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    TextEditor(text: $content)
                        .padding(12)
                        .frame(minHeight: 180)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView().tint(.black)
                        } else {
                            Text("Share with Community")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.cyan)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        onSubmit(content, category)
        isSubmitting = false
        dismiss()
    }
}

private actor WisdomCircleService {
    private struct WisdomPostResponse: Decodable {
        let id: String
        let anonymousHandle: String
        let content: String
        let redactedContent: String
        let upvotes: Int
        let replies: Int
        let createdAt: Date
        let category: WisdomPostCategory

        private enum CodingKeys: String, CodingKey {
            case id
            case anonymousHandle = "anonymous_handle"
            case content
            case redactedContent = "redacted_content"
            case upvotes
            case replies
            case createdAt = "created_at"
            case category
        }
    }

    private func request(path: String, method: String, body: [String: Any]? = nil) async throws -> URLRequest {
        guard let baseURL = AppBackendConfig.wisdomPostsURL else {
            throw AppError.networkError("Wisdom Circle backend is not configured")
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    func fetchPosts(limit: Int = 20) async throws -> [WisdomPost] {
        guard !AppRuntimeConfig.localOnlyMode else {
            return wisdomCircleMockPosts()
        }

        guard let baseURL = AppBackendConfig.wisdomPostsURL else {
            return wisdomCircleMockPosts()
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return wisdomCircleMockPosts()
        }
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components.url else {
            return wisdomCircleMockPosts()
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return wisdomCircleMockPosts()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let rows = try? decoder.decode([WisdomPostResponse].self, from: data) {
            return rows.compactMap { row in
                guard let uuid = UUID(uuidString: row.id) else { return nil }
                return WisdomPost(
                    id: uuid,
                    anonymousHandle: row.anonymousHandle,
                    content: row.content,
                    redactedContent: row.redactedContent,
                    upvotes: row.upvotes,
                    replies: row.replies,
                    createdAt: row.createdAt,
                    category: row.category
                )
            }
        }

        return wisdomCircleMockPosts()
    }

    func createPost(content: String, category: WisdomPostCategory) async throws -> WisdomPost {
        let redacted = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !AppRuntimeConfig.localOnlyMode else {
            return WisdomPost(
                id: UUID(),
                anonymousHandle: Self.generateHandle(),
                content: content,
                redactedContent: redacted,
                upvotes: 0,
                replies: 0,
                createdAt: Date(),
                category: category
            )
        }

        let request = try await request(path: "", method: "POST", body: [
            "anonymous_handle": Self.generateHandle(),
            "content": content,
            "redacted_content": redacted,
            "category": category.rawValue,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.networkError("Failed to create wisdom post")
        }

          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .iso8601
          if let row = try? decoder.decode(WisdomPostResponse.self, from: data),
              let uuid = UUID(uuidString: row.id) {
            return WisdomPost(
                id: uuid,
                anonymousHandle: row.anonymousHandle,
                content: row.content,
                redactedContent: row.redactedContent,
                upvotes: row.upvotes,
                replies: row.replies,
                createdAt: row.createdAt,
                category: row.category
            )
        }

        return WisdomPost(
            id: UUID(),
            anonymousHandle: Self.generateHandle(),
            content: content,
            redactedContent: redacted,
            upvotes: 0,
            replies: 0,
            createdAt: Date(),
            category: category
        )
    }

    func upvotePost(id: UUID) async throws {
        guard !AppRuntimeConfig.localOnlyMode else { return }

        guard let baseURL = AppBackendConfig.wisdomPostsURL else {
            return
        }

        var url = baseURL
        url.appendPathComponent(id.uuidString)
        url.appendPathComponent("upvote")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.networkError("Failed to upvote wisdom post")
        }
    }

    private static func generateHandle() -> String {
        let adjectives = ["Wise", "Calm", "Brave", "Kind", "Steady"]
        let nouns = ["Sage", "Seeker", "Guide", "Listener", "Compass"]
        return "\(adjectives.randomElement() ?? "Wise")\(nouns.randomElement() ?? "Sage")\(Int.random(in: 10...99))"
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
                Task { @MainActor in
                    try? await authService.signOut()
                }
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
                WisdomCircleView().tag(1).tabItem { Label("Community", systemImage: "bubble.right.fill") }
                SettingsView().tag(2).tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .tint(.cyan)
        }
    }
}

struct AppRootView: View {
    @ObservedObject private var authService = AuthenticationService()
    
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
