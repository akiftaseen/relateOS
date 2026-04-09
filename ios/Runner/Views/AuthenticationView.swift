import SwiftUI
import AuthenticationServices

// MARK: - Splash Screen

struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Gradient background
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
                
                // Logo
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

// MARK: - Authentication View

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
            // Background
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
                // Header
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
                    // Email Field
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    
                    // Password Field
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
                
                // Sign In / Sign Up Button
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
                
                Divider()
                    .padding(.horizontal, 16)
                
                // Apple Sign-In
                SignInWithAppleButton(
                    onRequest: { _ in },
                    onCompletion: handleAppleSignIn
                )
                .frame(height: 48)
                .cornerRadius(8)
                .padding(16)
                
                // Toggle Sign Up / Sign In
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
                
                Text("Your keyboard data is encrypted end-to-end and never shared.")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(16)
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
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        isLoading = true
        
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                print("Apple Sign-In successful with user: \(credential.user)")
                signInSuccessful = true
            }
        case .failure(let error):
            errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationService())
}
