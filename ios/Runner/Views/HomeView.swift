import SwiftUI

// MARK: - App Root View

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

// MARK: - Main Tab Navigation

struct MainTabView: View {
    @State private var selectedTab: TabSelection = .dashboard
    
    enum TabSelection {
        case dashboard
        case wisdomCircle
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
                    .tag(TabSelection.wisdomCircle)
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

// MARK: - Settings View

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
                    // Header
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
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferences")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            SettingsRowView(
                                icon: "globe",
                                title: "Language",
                                value: languageDisplay()
                            )
                            
                            SettingsRowView(
                                icon: "bell.fill",
                                title: "Notifications",
                                value: "Enabled"
                            )
                            
                            SettingsRowView(
                                icon: "moon.fill",
                                title: "Dark Mode",
                                value: "Always On"
                            )
                        }
                        .padding(16)
                    }
                    
                    // Keyboard Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keyboard")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            NavigationLink(destination: KeyboardSettingsView()) {
                                SettingsRowView(
                                    icon: "keyboard.fill",
                                    title: "Keyboard Settings",
                                    value: "Manage"
                                )
                            }
                            
                            SettingsRowView(
                                icon: "info.circle.fill",
                                title: "Keyboard Version",
                                value: "1.0.0"
                            )
                        }
                        .padding(16)
                    }
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            SettingsRowView(
                                icon: "doc.text.fill",
                                title: "Privacy Policy",
                                value: ""
                            )
                            
                            SettingsRowView(
                                icon: "checkmark.seal.fill",
                                title: "Terms of Service",
                                value: ""
                            )
                        }
                        .padding(16)
                    }
                    
                    // Sign Out Button
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
    
    private func languageDisplay() -> String {
        switch authService.currentUser?.language {
        case .english:
            return "English"
        case .cantonese:
            return "粤語"
        case .mandarin:
            return "中文"
        case .none:
            return "English"
        }
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.cyan)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if !value.isEmpty && value != "Manage" {
                Text(value)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.gray)
            } else if value == "Manage" {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Updated NativeHomeView

struct NativeHomeView: View {
    @StateObject private var authService = AuthenticationService()
    
    var body: some View {
        AppRootView()
            .environmentObject(authService)
    }
}

// MARK: - Updated NativeSplashView

struct NativeSplashView: View {
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
                        .scaleEffect(1.05)
                        .animation(
                            Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: UUID()
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
    }
}

// MARK: - Preview

#Preview {
    AppRootView()
}
