import SwiftUI
import Charts

// MARK: - Dashboard View

struct DashboardView: View {
    @State private var healthScore: HealthScore?
    @State private var weeklyScores: [HealthScore] = []
    @State private var isLoading = false
    @State private var selectedTimeframe: TimeframeFilter = .week
    
    @EnvironmentObject var authService: AuthenticationService
    
    enum TimeframeFilter {
        case week
        case month
        case all
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
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
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
                    
                    if isLoading {
                        ProgressView()
                            .tint(.cyan)
                    } else if let score = healthScore {
                        VStack(spacing: 20) {
                            // Main Score Card
                            HealthScoreCardView(score: score)
                            
                            // Trend Chart
                            if !weeklyScores.isEmpty {
                                HealthTrendChartView(scores: weeklyScores)
                            }
                            
                            // Insights
                            HealthInsightsView(score: score)
                            
                            // Stats Grid
                            HealthStatsGridView(score: score)
                            
                            // Keyboard Settings
                            NavigationLink(destination: KeyboardSettingsView()) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("Keyboard Settings")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(.cyan)
                                .cornerRadius(8)
                            }
                            .padding(16)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadDashboardData()
        }
    }
    
    private func loadDashboardData() {
        isLoading = true
        
        Task {
            do {
                guard let userId = authService.currentUser?.id else {
                    throw AppError.authenticationFailed("No current user")
                }
                
                let supabase = SupabaseService()
                let scores = try await supabase.fetchWeeklyScores(userId: userId)
                
                await MainActor.run {
                    self.weeklyScores = scores
                    self.healthScore = scores.first ?? createMockScore()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.healthScore = createMockScore()
                    self.isLoading = false
                }
            }
        }
    }
    
    private func createMockScore() -> HealthScore {
        HealthScore(
            id: UUID(),
            userId: authService.currentUser?.id ?? UUID(),
            score: Double.random(in: 65...85),
            positiveWeight: Double.random(in: 40...80),
            negativeWeight: Double.random(in: 10...30),
            validationMarkers: Int.random(in: 5...15),
            conflictMarkers: Int.random(in: 2...8),
            timestamp: Date(),
            weeklyAverage: Double.random(in: 70...80)
        )
    }
}

// MARK: - Health Score Card

struct HealthScoreCardView: View {
    let score: HealthScore
    
    var scoreColor: Color {
        if score.score >= 75 {
            return .green
        } else if score.score >= 50 {
            return .yellow
        } else {
            return .red
        }
    }
    
    var scoreLabel: String {
        if score.score >= 75 {
            return "Thriving"
        } else if score.score >= 50 {
            return "Growing"
        } else {
            return "Needs Care"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: score.score / 100)
                    .stroke(scoreColor, lineWidth: 8)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 8) {
                    Text(String(format: "%.0f", score.score))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(scoreColor)
                    
                    Text("/ 100")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.gray)
                }
            }
            
            Text(scoreLabel)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(scoreColor)
            
            Text("Based on your recent interactions")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.gray)
        }
        .padding(24)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(16)
    }
}

// MARK: - Trend Chart

struct HealthTrendChartView: View {
    let scores: [HealthScore]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Trend")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            Chart(scores.sorted { $0.timestamp < $1.timestamp }, id: \.id) { item in
                LineMark(
                    x: .value("Date", item.timestamp),
                    y: .value("Score", item.score)
                )
                .foregroundStyle(.cyan)
                
                PointMark(
                    x: .value("Date", item.timestamp),
                    y: .value("Score", item.score)
                )
                .foregroundStyle(.cyan)
            }
            .frame(height: 200)
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Insights

struct HealthInsightsView: View {
    let score: HealthScore
    
    var insights: [String] {
        var result: [String] = []
        
        if score.validationMarkers > 10 {
            result.append("✓ You're showing great validation skills")
        }
        
        if score.conflictMarkers < 5 {
            result.append("✓ Conflict markers are minimal this week")
        }
        
        if score.positiveWeight > score.negativeWeight {
            result.append("✓ Overall sentiment is positive and constructive")
        }
        
        if result.isEmpty {
            result.append("💡 Keep building empathy in your interactions")
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(insights, id: \.self) { insight in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 8, height: 8)
                        
                        Text(insight)
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Stats Grid

struct HealthStatsGridView: View {
    let score: HealthScore
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCardView(
                    title: "Validation",
                    value: String(score.validationMarkers),
                    icon: "hand.thumbsup.fill",
                    color: .green
                )
                
                StatCardView(
                    title: "Conflict",
                    value: String(score.conflictMarkers),
                    icon: "exclamationmark.circle.fill",
                    color: .red
                )
            }
            
            HStack(spacing: 12) {
                StatCardView(
                    title: "Positive",
                    value: String(format: "%.0f", score.positiveWeight),
                    icon: "heart.fill",
                    color: .cyan
                )
                
                StatCardView(
                    title: "Negative",
                    value: String(format: "%.0f", score.negativeWeight),
                    icon: "xmark.circle.fill",
                    color: .orange
                )
            }
        }
        .padding(16)
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Keyboard Settings

struct KeyboardSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var keyboardEnabled = true
    @State private var analyticsEnabled = true
    
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
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.cyan)
                    }
                    
                    Text("Keyboard Settings")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingToggleView(
                            title: "Enable Keyboard",
                            description: "Allow RelateOS keyboard to be used",
                            isOn: $keyboardEnabled
                        )
                        
                        SettingToggleView(
                            title: "Analytics",
                            description: "Help improve RelateOS with anonymous usage data",
                            isOn: $analyticsEnabled
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("RelateOS Keyboard • Version 1.0.0")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(16)
                }
                
                Spacer()
            }
        }
    }
}

struct SettingToggleView: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.cyan)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AuthenticationService())
}
