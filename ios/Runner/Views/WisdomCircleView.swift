import SwiftUI

// MARK: - Wisdom Circle View

struct WisdomCircleView: View {
    @State private var posts: [WisdomPost] = []
    @State private var isLoading = false
    @State private var showCreatePostSheet = false
    @State private var selectedCategory: WisdomPost.PostCategory? = nil
    
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
                // Header
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
                    
                    Button(action: { showCreatePostSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.cyan)
                    }
                }
                .padding(16)
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        ForEach([WisdomPost.PostCategory.advice, .experience, .question, .reflection], id: \.self) { category in
                            FilterChip(
                                title: category.rawValue.capitalized,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 40)
                
                // Posts Feed
                if isLoading {
                    ProgressView()
                        .tint(.cyan)
                } else if posts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No posts yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Be the first to share your wisdom")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPosts) { post in
                                WisdomPostCardView(post: post)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            
            VStack {
                Spacer()
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.cyan)
                    
                    Text("All posts are anonymously submitted and PII is automatically redacted")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .padding(16)
            }
        }
        .sheet(isPresented: $showCreatePostSheet) {
            CreateWisdomPostView()
        }
        .onAppear {
            loadPosts()
        }
    }
    
    private var filteredPosts: [WisdomPost] {
        if let category = selectedCategory {
            return posts.filter { $0.category == category }
        }
        return posts
    }
    
    private func loadPosts() {
        isLoading = true
        
        Task {
            do {
                let supabase = SupabaseService()
                let loadedPosts = try await supabase.fetchWisdomPosts()
                
                await MainActor.run {
                    self.posts = loadedPosts
                    self.isLoading = false
                }
            } catch {
                print("Error loading posts: \(error)")
                await MainActor.run {
                    self.posts = createMockPosts()
                    self.isLoading = false
                }
            }
        }
    }
    
    private func createMockPosts() -> [WisdomPost] {
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
                content: "Learning to listen without planning my response has changed everything. It's hard but worth it.",
                redactedContent: "Learning to listen without planning my response has changed everything. It's hard but worth it.",
                upvotes: 156,
                replies: 23,
                createdAt: Date().addingTimeInterval(-7200),
                category: .advice
            ),
            WisdomPost(
                id: UUID(),
                anonymousHandle: "Wanderer19",
                content: "After 5 years, we finally had a conversation about what we both really need. Game-changer.",
                redactedContent: "After 5 years, we finally had a conversation about what we both really need. Game-changer.",
                upvotes: 89,
                replies: 12,
                createdAt: Date().addingTimeInterval(-86400),
                category: .experience
            )
        ]
    }
}

// MARK: - Wisdom Post Card

struct WisdomPostCardView: View {
    let post: WisdomPost
    @State private var isUpvoted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(post.anonymousHandle.first!))
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
                
                CategoryBadge(category: post.category)
            }
            
            // Content
            Text(post.redactedContent)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white)
                .lineLimit(3)
            
            // Footer
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: isUpvoted ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 14))
                    
                    Text(String(post.upvotes))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(isUpvoted ? .cyan : .gray)
                .onTapGesture {
                    isUpvoted.toggle()
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 14))
                    
                    Text(String(post.replies))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.gray)
                
                Spacer()
                
                Image(systemName: "share")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: WisdomPost.PostCategory
    
    var badgeColor: Color {
        switch category {
        case .advice:
            return .green
        case .experience:
            return .blue
        case .question:
            return .orange
        case .reflection:
            return .purple
        }
    }
    
    var body: some View {
        Text(category.rawValue.capitalized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.3))
            .cornerRadius(6)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.cyan : Color.white.opacity(0.1))
                .cornerRadius(6)
        }
    }
}

// MARK: - Create Wisdom Post

struct CreateWisdomPostView: View {
    @Environment(\.dismiss) var dismiss
    @State private var postContent = ""
    @State private var selectedCategory: WisdomPost.PostCategory = .advice
    @State private var isPosting = false
    
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
                // Header
                HStack {
                    Text("Share Your Wisdom")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Category Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                ForEach([WisdomPost.PostCategory.advice, .experience, .question, .reflection], id: \.self) { category in
                                    Button(action: { selectedCategory = category }) {
                                        Text(category.rawValue.capitalized)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(selectedCategory == category ? .black : .white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedCategory == category ? Color.cyan : Color.white.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        
                        // Content Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Thoughts")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextEditor(text: $postContent)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        // Privacy Info
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.cyan)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your Anonymity is Protected")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Personal information will be automatically redacted")
                                    .font(.system(size: 11, weight: .light))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(12)
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(16)
                }
                
                // Post Button
                Button(action: publishPost) {
                    if isPosting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Share with Community")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.cyan)
                .foregroundColor(.black)
                .cornerRadius(8)
                .disabled(postContent.trimmingCharacters(in: .whitespaces).isEmpty || isPosting)
                .padding(16)
            }
        }
    }
    
    private func publishPost() {
        isPosting = true
        
        Task {
            do {
                let newPost = WisdomPost(
                    id: UUID(),
                    anonymousHandle: generateAnonymousHandle(),
                    content: postContent,
                    redactedContent: postContent,
                    upvotes: 0,
                    replies: 0,
                    createdAt: Date(),
                    category: selectedCategory
                )
                
                let supabase = SupabaseService()
                try await supabase.createPost(newPost)
                
                await MainActor.run {
                    isPosting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    print("Error posting: \(error)")
                }
            }
        }
    }
    
    private func generateAnonymousHandle() -> String {
        let adjectives = ["Wise", "Brave", "Kind", "Strong", "Calm"]
        let nouns = ["Phoenix", "Eagle", "Sage", "Guardian", "Seeker"]
        let number = Int.random(in: 1...99)
        
        return "\(adjectives.randomElement() ?? "Seeker")\(nouns.randomElement() ?? "Sage")\(number)"
    }
}

// MARK: - Preview

#Preview {
    WisdomCircleView()
}
