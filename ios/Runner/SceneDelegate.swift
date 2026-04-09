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

// MARK: - ========== SUPABASE LAYER ==========

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
    }
    
    func signOut() async throws {
        await supabaseService.clearSession()
        currentUser = nil
        isAuthenticated = false
    }
    
    private func checkAuthStatus() {
        Task { @MainActor in
            if let cached = await supabaseService.getCachedUser() {
                currentUser = cached
                isAuthenticated = true
            }
        }
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
