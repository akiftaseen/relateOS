import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Authentication Service (Swift 6 Actor)

@globalActor actor AuthenticationActor {
    static let shared = AuthenticationActor()
}

@AuthenticationActor
final class AuthenticationService: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var authError: AppError?
    
    private var currentNonce: String?
    
    override init() {
        super.init()
        checkAuthStatus()
    }
    
    // MARK: - Apple Sign-In
    
    nonisolated func startAppleSignIn() async throws -> User {
        let nonce = nonceForAppleSignIn()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate()
        controller.delegate = delegate
        controller.performRequests()
        
        // This would be handled via delegate callbacks in real implementation
        throw AppError.authenticationFailed("Apple Sign-In delegate callback required")
    }
    
    // MARK: - Google Sign-In
    
    nonisolated func startGoogleSignIn() async throws -> User {
        // Google Sign-In would require GoogleSignIn SDK
        throw AppError.authenticationFailed("Google Sign-In not yet implemented")
    }
    
    // MARK: - Email Authentication
    
    func signUpWithEmail(_ email: String, password: String) async throws -> User {
        guard isValidEmail(email) else {
            throw AppError.validationError("Invalid email format")
        }
        guard password.count >= 8 else {
            throw AppError.validationError("Password must be at least 8 characters")
        }
        
        // Call Supabase to create user
        let newUser = User(
            id: UUID(),
            email: email,
            displayName: email.split(separator: "@").first.map(String.init) ?? "User",
            authProvider: .email,
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
        
        // Call Supabase to authenticate
        let user = User(
            id: UUID(),
            email: email,
            displayName: email.split(separator: "@").first.map(String.init) ?? "User",
            authProvider: .email,
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
    
    // MARK: - Private Helpers
    
    private func checkAuthStatus() {
        // Check if user is already authenticated (load from Keychain/UserDefaults)
        if let savedUser = loadUserFromKeychain() {
            self.currentUser = savedUser
            self.isAuthenticated = true
        }
    }
    
    private func loadUserFromKeychain() -> User? {
        // TODO: Implement Keychain loading
        return nil
    }
    
    private func saveUserToKeychain(_ user: User) {
        // TODO: Implement Keychain saving
    }
    
    private func nonceForAppleSignIn() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        let nonce = Data(buffer).base64EncodedString()
        self.currentNonce = nonce
        return nonce
    }
    
    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return Data(digest).base64EncodedString()
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

// MARK: - Apple Sign-In Delegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            print("Apple Sign-In successful: \(credential.user)")
            // Handle successful sign-in
        }
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        print("Apple Sign-In error: \(error)")
    }
}

// MARK: - AppGroup Shared State

@globalActor actor AppGroupState {
    static let shared = AppGroupState()
    
    private let sharedDefaults = UserDefaults(suiteName: AppConfiguration.appGroup)
    
    func saveUser(_ user: User) throws {
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(user)
        sharedDefaults?.set(encoded, forKey: "current_user")
    }
    
    func loadUser() -> User? {
        guard let data = sharedDefaults?.data(forKey: "current_user") else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(User.self, from: data)
    }
}
