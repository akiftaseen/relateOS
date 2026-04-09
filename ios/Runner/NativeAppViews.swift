import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - ========== APP STATE & MODELS ==========

enum LanguagePreference: String, Codable {
    case english = "en"
    case cantonese =  "zh-HK"
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

struct HealthScore: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let score: Double
    let positiveWeight: Double
    let negativeWeight: Double
    let validationMarkers: Int
    let conflictMarkers: Int
    let timestamp: Date
    let weeklyAverage: Double?
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

struct AppConfiguration {
    static let appGroup = "group.com.relateos.keyboard"
    static let supabaseURL = "https://your-supabase-url.supabase.co"
    static let supabaseAnonKey = "your-supabase-anon-key"
}

// MARK: - ========== AUTHENTICATION SERVICE ==========

@globalActor actor AuthenticationActor {
    static let shared = AuthenticationActor()
}

@AuthenticationActor
final class AuthenticationService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var authError: AppError?
    
    private var currentNonce: String?
    
    init() {
        checkAuthStatus()
    }
    
    nonisolated func startAppleSignIn() async throws -> User {
        throw AppError.authenticationFailed("Apple Sign-In requires delegate setup")
    }
    
    func signUpWithEmail(_ email: String, password: String) async throws -> User {
        guard isValidEmail(email) else {
            throw AppError.validationError("Invalid email format")
        }
        guard password.count >= 8 else {
            throw AppError.validationError("Password must be at least 8 characters")
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
        if let savedUser = loadUserFromKeychain() {
            self.currentUser = savedUser
            self.isAuthenticated = true
        }
    }
    
    private func loadUserFromKeychain() -> User? {
        return nil
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

// MARK: - ========== SPLASH & AUTH VIEWS ==========

struct SplashView: View {
    @State private var isAnimating = false
    
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
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Text("RelateOS")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Relationship Intelligence Keyboard")
                        .font(.system(size: 14, weight: .light, design: .default))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct AuthenticationView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var showSignUp = false
    @State private var errorMessage: String?
    @State private var signInSuccessful = false
    
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
                    
                    Text(showSignUp ? "Create Your Account" : "Welcome Back")
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
                        .textContentType(showSignUp ? .newPassword : .password)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
                .padding(16)
                
                Button(action: handleAuthAction) {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
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
                .disabled(isLoading || email.isEmpty || password.isEmpty)
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
    
    private func handleAuthAction() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if showSignUp {
                    let _ = try await authService.signUpWithEmail(email, password: password)
                } else {
                    let _ = try await authService.signInWithEmail(email, password: password)
                }
                signInSuccessful = true
            } catch let error as AppError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "An unexpected error occurred"
            }
            isLoading = false
        }
    }
}

// MARK: - ========== ONBOARDING ==========

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var selectedLanguage: LanguagePreference = .english
    @State private var quizAnswers: [Int] = Array(repeating: 0, count: 5)
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
                ProgressView(value: Double(currentStep) / 3.0)
                    .tint(.cyan)
                    .padding()
                
                TabView(selection: $currentStep) {
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("Choose Your Language")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Select the language you'd like to use")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.gray)
                        }
                        
                        VStack(spacing: 12) {
                            ForEach([LanguagePreference.english, .cantonese, .mandarin], id: \.self) { lang in
                                Button(action: { selectedLanguage = lang }) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(languageTitle(lang))
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                            
                                            Text(languageSubtitle(lang))
                                                .font(.system(size: 14, weight: .light))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: selectedLanguage == lang ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 24))
                                            .foregroundColor(selectedLanguage == lang ? .cyan : .gray)
                                    }
                                    .padding(16)
                                    .background(Color.white.opacity(selectedLanguage == lang ? 0.1 : 0.05))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(16)
                        
                        Spacer()
                    }
                    .padding()
                    .tag(0)
                    
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("Baseline Assessment")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Help us understand your relationship")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.gray)
                        }
                        
                        ScrollView {
                            VStack(spacing: 20) {
                                ForEach(0..<5, id: \.self) { i in
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Question \(i + 1)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        VStack(spacing: 8) {
                                            ForEach(0..<5, id: \.self) { j in
                                                Button(action: { quizAnswers[i] = j }) {
                                                    HStack {
                                                        Text(["Very Low", "Low", "Neutral", "High", "Very High"][j])
                                                            .font(.system(size: 14, weight: .regular))
                                                            .foregroundColor(quizAnswers[i] == j ? .black : .white)
                                                        
                                                        Spacer()
                                                        
                                                        Image(systemName: quizAnswers[i] == j ? "checkmark.circle.fill" : "circle")
                                                    }
                                                    .padding(12)
                                                    .background(quizAnswers[i] == j ? Color.cyan : Color.white.opacity(0.05))
                                                    .cornerRadius(6)
                                                }
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(16)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .tag(1)
                    
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Privacy & Consent")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Your privacy is our priority")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.gray)
                        }
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                consentItem("lock.fill", "End-to-End Encryption", "All data is encrypted before transfer")
                                consentItem("eye.slash.fill", "PII Redaction", "Personal information is automatically removed")
                                consentItem("handshake.fill", "App Group Sharing", "Secure communication between app and keyboard")
                            }
                            .padding(16)
                        }
                        
                        Button(action: { consentGiven = true }) {
                            Text("I Understand & Consent")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.cyan)
                                .foregroundColor(.black)
                                .cornerRadius(8)
                        }
                        .padding(16)
                    }
                    .padding()
                    .tag(2)
                    
                    VStack(spacing: 32) {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.cyan)
                            
                            Text("All Set!")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Your RelateOS keyboard is ready to go")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: { currentStep -= 1 }) {
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    Button(action: { if currentStep < 3 { currentStep += 1 } }) {
                        Text(currentStep == 3 ? "Start Using RelateOS" : "Next")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.cyan)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                    .disabled(currentStep == 2 && !consentGiven)
                }
                .padding(16)
            }
        }
    }
    
    private func languageTitle(_ lang: LanguagePreference) -> String {
        switch lang {
        case .english: return "English"
        case .cantonese: return "粤語"
        case .mandarin: return "中文"
        }
    }
    
    private func languageSubtitle(_ lang: LanguagePreference) -> String {
        switch lang {
        case .english: return "English"
        case .cantonese: return "Cantonese (Hong Kong)"
        case .mandarin: return "Mandarin Chinese"
        }
    }
    
    private func consentItem(_ icon: String, _ title: String, _ description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.cyan)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - ========== MAIN app VIEWS ==========

struct DashboardView: View {
    @State private var score = Double.random(in: 65...85)
    
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
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Relationship Health")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Your weekly overview")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 180, height: 180)
                            
                            Circle()
                                .trim(from: 0, to: score / 100)
                                .stroke(Color.cyan, lineWidth: 8)
                                .frame(width: 180, height: 180)
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 8) {
                                Text(String(format: "%.0f", score))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.cyan)
                                
                                Text("/ 100")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Text(score >= 75 ? "Thriving" : score >= 50 ? "Growing" : "Needs Care")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(score >= 75 ? .green : score >= 50 ? .yellow : .red)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(16)
                }
            }
        }
    }
}

struct WisdomCircleView: View {
    @State private var posts: [WisdomPost] = []
    
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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wisdom Circle")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Share & Learn from the Community")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cyan)
                }
                .padding(16)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Community posts coming soon")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showSignOutAlert = false
    
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
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color.cyan.opacity(0.2))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.cyan)
                            )
                        
                        VStack(spacing: 4) {
                            Text(authService.currentUser?.displayName ?? "User")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(authService.currentUser?.email ?? "")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(16)
                    
                    Button(action: { showSignOutAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Sign Out")
                            Spacer()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(16)
                    
                    Spacer()
                }
            }
        }
        .alert("Sign Out?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authService.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: TabSelection = .dashboard
    
    enum TabSelection {
        case dashboard
        case wisdom
        case settings
    }
    
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
                DashboardView()
                    .tag(TabSelection.dashboard)
                    .tabItem {
                        Label("Health", systemImage: "heart.fill")
                    }
                
                WisdomCircleView()
                    .tag(TabSelection.wisdom)
                    .tabItem {
                        Label("Community", systemImage: "bubble.right.fill")
                    }
                
                SettingsView()
                    .tag(TabSelection.settings)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
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
