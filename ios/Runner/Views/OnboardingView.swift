import SwiftUI

// MARK: - Onboarding Flow

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
                // Progress Indicator
                ProgressView(value: Double(currentStep) / 3.0)
                    .tint(.cyan)
                    .padding()
                
                TabView(selection: $currentStep) {
                    LanguageSelectionView(selectedLanguage: $selectedLanguage)
                        .tag(0)
                    
                    BaselineQuizView(answers: $quizAnswers)
                        .tag(1)
                    
                    ConsentModalView(consentGiven: $consentGiven)
                        .tag(2)
                    
                    OnboardingCompleteView()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                
                // Navigation Buttons
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
                    
                    Button(action: handleNext) {
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
    
    private func handleNext() {
        if currentStep < 3 {
            currentStep += 1
        } else {
            // Complete onboarding
            completeOnboarding()
        }
    }
    
    private func completeOnboarding() {
        // Update user's language preference and mark onboarding as complete
        if var user = authService.currentUser {
            user = User(
                id: user.id,
                email: user.email,
                displayName: user.displayName,
                authProvider: user.authProvider,
                createdAt: user.createdAt,
                language: selectedLanguage,
                onboardingComplete: true
            )
            // Save to Supabase and AppGroup
        }
    }
}

// MARK: - Language Selection

struct LanguageSelectionView: View {
    @Binding var selectedLanguage: LanguagePreference
    
    var body: some View {
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
                LanguageOption(
                    title: "English",
                    subtitle: "English",
                    isSelected: selectedLanguage == .english,
                    action: { selectedLanguage = .english }
                )
                
                LanguageOption(
                    title: "粤語",
                    subtitle: "Cantonese (Hong Kong)",
                    isSelected: selectedLanguage == .cantonese,
                    action: { selectedLanguage = .cantonese }
                )
                
                LanguageOption(
                    title: "中文",
                    subtitle: "Mandarin Chinese",
                    isSelected: selectedLanguage == .mandarin,
                    action: { selectedLanguage = .mandarin }
                )
            }
            .padding(16)
            
            Spacer()
        }
        .padding()
    }
}

struct LanguageOption: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .cyan : .gray)
            }
            .padding(16)
            .background(Color.white.opacity(isSelected ? 0.1 : 0.05))
            .cornerRadius(8)
        }
    }
}

// MARK: - Baseline Quiz

struct BaselineQuizView: View {
    @Binding var answers: [Int]
    
    let questions = [
        "How satisfied are you with your current relationship?",
        "How often do you have meaningful conversations?",
        "How do you handle conflicts?",
        "How important is emotional connection to you?",
        "How would you describe communication with your partner?"
    ]
    
    var body: some View {
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
                    ForEach(0..<questions.count, id: \.self) { index in
                        QuizQuestion(
                            question: questions[index],
                            selectedAnswer: $answers[index],
                            questionIndex: index
                        )
                    }
                }
                .padding(16)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct QuizQuestion: View {
    let question: String
    @Binding var selectedAnswer: Int
    let questionIndex: Int
    
    let options = [
        "Very Low",
        "Low",
        "Neutral",
        "High",
        "Very High"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                ForEach(0..<options.count, id: \.self) { index in
                    Button(action: { selectedAnswer = index }) {
                        HStack {
                            Text(options[index])
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(selectedAnswer == index ? .black : .white)
                            
                            Spacer()
                            
                            Image(systemName: selectedAnswer == index ? "checkmark.circle.fill" : "circle")
                        }
                        .padding(12)
                        .background(selectedAnswer == index ? Color.cyan : Color.white.opacity(0.05))
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

// MARK: - Consent Modal

struct ConsentModalView: View {
    @Binding var consentGiven: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Privacy & Permissions")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your privacy is our priority")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.gray)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ConsentSection(
                        icon: "lock.fill",
                        title: "End-to-End Encryption",
                        description: "All keyboard interactions are encrypted before leaving your device"
                    )
                    
                    ConsentSection(
                        icon: "eye.slash.fill",
                        title: "PII Redaction",
                        description: "Sensitive personal information is automatically removed from analysis"
                    )
                    
                    ConsentSection(
                        icon: "handshake.fill",
                        title: "App Group Sharing",
                        description: "We use App Groups to securely share data between the keyboard and main app"
                    )
                    
                    ConsentSection(
                        icon: "analytics.fill",
                        title: "Anonymous Analytics",
                        description: "Your usage patterns help us improve, but are never shared with third parties"
                    )
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
    }
}

struct ConsentSection: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
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

// MARK: - Onboarding Complete

struct OnboardingCompleteView: View {
    var body: some View {
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
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationService())
}
