# RelateOS iOS Setup & Build Guide

## Project Structure Overview

```
relateOS/
├── lib/                           # Flutter main app
│   ├── main.dart                 # Entry point
│   ├── config/                   # Configuration
│   │   ├── supabase_config.dart
│   │   └── theme.dart
│   ├── core/
│   │   └── platform/
│   │       └── keyboard_bridge_service.dart  # Platform channel interface
│   └── features/
│       ├── auth/                 # Authentication
│       │   ├── data/models/
│       │   │   └── user_model.dart
│       │   └── presentation/pages/
│       │       └── splash_page.dart
│       └── health_scoring/       # Health scoring engine
│           ├── domain/
│           │   └── health_scoring_engine.dart
│           └── data/models/
│               └── analysis_log_model.dart
├── ios/
│   ├── Runner/
│   │   └── KeyboardBridgeHandler.swift  # Platform channel bridge
│   └── KeyboardExtension/
│       └── KeyboardViewController.swift  # Keyboard UI extension
├── workers/                       # Cloudflare Workers
│   └── ai-proxy/
│       ├── src/
│       │   └── index.ts          # AI routing & PII scrubbing
│       └── wrangler.toml         # Wrangler config
└── pubspec.yaml                  # Flutter dependencies
```

## Prerequisites

- **macOS** (for iOS development)
- **Xcode 15+** with iOS deployment target ≥ 13.0
- **Flutter 3.24.0+** on stable channel
- **CocoaPods** for iOS package management
- **Supabase CLI** for database setup
- **Wrangler CLI** for Cloudflare Workers deployment

## Step 1: Environment Setup

### 1.1 Install Flutter (if not already installed)

```bash
# Check Flutter version
flutter --version

# If not >= 3.24.0, upgrade
flutter upgrade

# Switch to stable channel
flutter channel stable
flutter upgrade
```

### 1.2 Set up iOS development environment

```bash
# Check iOS deployment target
CocoaPods --version

# Install CocoaPods if needed
sudo gem install cocoapods
```

### 1.3 Verify Xcode installation

```bash
cd ios
pod setup
pod repo update
```

## Step 2: Configure Supabase

### 2.1 Create Supabase project

1. Go to https://supabase.com
2. Create a new project in Hong Kong region (if available)
3. Copy the project URL and anon key

### 2.2 Update supabase_config.dart

Edit `lib/config/supabase_config.dart`:

```dart
const String supabaseUrl = 'https://your-project.supabase.co';
const String supabaseAnonKey = 'your-anon-key';
```

### 2.3 Set up database schema

Run the following SQL in Supabase SQL Editor:

```sql
-- Create users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMPTZ DEFAULT now(),
  preferred_language VARCHAR(10) CHECK (preferred_language IN ('en', 'zh-HK', 'zh-CN')),
  subscription_tier VARCHAR(20) DEFAULT 'free',
  onboarding_completed BOOLEAN DEFAULT false,
  consent_keyboard_granted TIMESTAMPTZ,
  baseline_weights JSONB
);

-- Create analysis_logs table
CREATE TABLE analysis_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  health_score_snapshot FLOAT CHECK (health_score_snapshot >= 0 AND health_score_snapshot <= 1),
  primary_emotion_detected VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT now(),
  raw_text_hash VARCHAR(64),
  direct_statement_count INT DEFAULT 0,
  emotional_need_score FLOAT DEFAULT 0.5
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE analysis_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can only access their own data"
  ON users FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can only modify their own data"
  ON users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Analysis logs accessible only by owner"
  ON analysis_logs FOR SELECT USING (auth.uid() = user_id);
```

## Step 3: Configure Cloudflare Workers

### 3.1 Install Wrangler

```bash
npm install -g wrangler
```

### 3.2 Set up Workers project

```bash
cd workers/ai-proxy
wrangler login
```

### 3.3 Create KV Namespace for rate limiting

```bash
wrangler kv:namespace create "RATE_LIMIT_STORE"
wrangler kv:namespace create "RATE_LIMIT_STORE" --preview
```

### 3.4 Update wrangler.toml

Replace the namespace IDs and add your Gemini API key as a secret:

```bash
wrangler secret put GEMINI_API_KEY
# Paste your Google Gemini API key when prompted
```

## Step 4: Build & Run iOS App

### 4.1 Get Flutter dependencies

```bash
flutter pub get
```

### 4.2 Generate code (json_serializable)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4.3 Open in Xcode

```bash
open ios/Runner.xcworkspace
```

### 4.4 Add keyboard extension target in Xcode

1. In Xcode: File → New → Target
2. Select "App Clips" (or filter for "Keyboard")
3. Choose "Custom Keyboard Extension"
4. Name it: `KeyboardExtension`
5. Bundle identifier: `com.relateos.keyboard`
6. Replace `KeyboardViewController.swift` with the one from this repo

### 4.5 Configure App Groups

**In Runner target:**
1. Go to Signing & Capabilities
2. Add "+ Capability" → App Groups
3. Add group: `group.com.relateos.keyboard`

**In KeyboardExtension target:**
1. Go to Signing & Capabilities
2. Add "+ Capability" → App Groups
3. Add group: `group.com.relateos.keyboard`

### 4.6 Add keyboard permissions to Info.plist

Add to `ios/Runner/Info.plist`:

```xml
<key>NSInputMethodsExplicitlyAllowed</key>
<array>
  <string>com.relateos.keyboard</string>
</array>
```

### 4.7 Run the app

```bash
flutter run -v
```

Or from Xcode: Product → Run

## Step 5: Deploy Cloudflare Workers

```bash
cd workers/ai-proxy
wrangler publish
```

After deployment, update your Flutter app to use the correct endpoint:

Edit `lib/core/platform/keyboard_bridge_service.dart` and update the Worker URL in the actual implementation.

## Step 6: Test Keyboard Extension

1. Run the app on simulator or device
2. Grant keyboard permissions in onboarding
3. Open any text field in a compatible app (WhatsApp, WeChat, etc.)
4. Keyboard should appear with RelateOS suggestions

## Performance Checklist

- [ ] Keyboard render TTI ≤ 300ms
- [ ] End-to-end AI roundtrip ≤ 1200ms on 4G
- [ ] App cold start ≤ 1.8s
- [ ] Keyboard extension < 40MB compiled

## Next Steps

### Frontend Features to Implement

1. **Authentication Flow**
   - Apple Sign-In
   - Google Sign-In
   - Email/password auth

2. **Onboarding**
   - Language selection
   - 5-question baseline quiz
   - Keyboard permission consent modal

3. **Dashboard**
   - Display health score (7-day rolling)
   - Show recent analysis
   - Usage statistics

4. **Wisdom Circle**
   - Anonymous post creation
   - PII redaction via Cloudflare Edge Function
   - Upvote/visibility decay
   - Moderation UI

### Backend/Infrastructure

1. Deploy Cloudflare Worker with Gemini integration
2. Set up Supabase Edge Functions for Wisdom Circle moderation
3. Configure Durable Objects for real-time analytics
4. Set up monitoring & error tracking

## Deployment

### Production iOS Build

```bash
# Build for distribution
flutter build ipa --release --no-codesign

# Or use Xcode:
# Product → Archive
```

### Production Cloudflare Workers

```bash
wrangler publish --env production
```

## Troubleshooting

### Keyboard not appearing?

1. Verify App Groups are configured correctly
2. Check that the keyboard extension is added to embed binaries
3. Restart the app and grant keyboard permissions

### Platform channel errors?

1. Ensure method names match in Swift and Dart
2. Check channel name matches: `com.relateos/keyboard_bridge`
3. Verify arguments are properly serialized

### Supabase connection issues?

1. Verify URL and anon key are correct
2. Check RLS policies are enabled
3. Ensure auth is initialized before queries

## Support & Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Supabase Docs](https://supabase.com/docs)
- [Cloudflare Workers](https://developers.cloudflare.com/workers/)
- [iOS Keyboard Extension](https://developer.apple.com/documentation/uikit/keyboards_and_input/creating_a_custom_keyboard)
