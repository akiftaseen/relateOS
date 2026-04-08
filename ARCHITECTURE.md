# RelateOS Architecture & Design

## High-Level Overview

RelateOS follows a hybrid architecture to overcome iOS keyboard extension memory constraints (< 50 MB) while maintaining sub-second latency for AI suggestions.

```
User Types Messages on Any App
         ↓
    iOS/Android Keyboard Extension
         ↓
    Platform Channel Bridge
         ↓
    Main Flutter App (Background Isolate)
         ↓
    Encrypt Payload (AES-256-GCM)
         ↓
    Cloudflare Workers Proxy
    ├─ Rate Limiting (60 req/min per user)
    ├─ PII Redaction (NER + rules)
    └─ Forward to Google Gemini 2.5 Pro
         ↓
    Decrypt Response
         ↓
    Display Suggestions in Keyboard
         ↓
    Log Analysis & Update Health Score
```

## 1. iOS Architecture

### 1.1 Keyboard Extension (< 40 MB limit)

**Why a Custom Keyboard?**
- System-level access to any text field (WhatsApp, WeChat, IG, Telegram, Signal, Messages)
- Can't achieve with standard UITextView interception
- Runs in separate sandbox with memory limit

**UIInputViewController Implementation:**
```swift
override func textDidChange(_ textInput: UITextInput?) {
    // 1. Capture last 20 messages via textDocumentProxy
    // 2. Send to main app via platform channel (non-blocking)
    // 3. Display mock suggestions while waiting
}
```

**Key Constraints:**
- Memory: < 50 MB total
- Binary size: < 40 MB compiled
- Latency: Show placeholder suggestions immediately, replace with AI results when ready
- Network: Must use platform channel to reach main app (keyboard sandbox restriction)

### 1.2 App Groups & Shared Storage

Both keyboard extension and main app need to:
1. Share authentication state
2. Exchange keyboard capture data
3. Store rate limit info

**Implementation:**
```swift
// Shared UserDefaults
UserDefaults(suiteName: "group.com.relateos.keyboard")

// Shared Keychain items via SecItem API
kSecAttrAccessGroup: "group.com.relateos.keyboard"
```

### 1.3 Platform Channel Bridge

**Purpose:** Connect UIKit (keyboard) to Dart (main app)

**Method Channel:** `com.relateos/keyboard_bridge`

**Methods:**
- `analyzeIntent` - Send capture to main app
- `saveAnalysisLog` - Store result
- `getCachedMessages` - Retrieve previous context

## 2. Main Flutter App Architecture

### 2.1 Initialization Flow

```
main.dart
  ↓
Initialize Supabase
  ↓
Create Riverpod ProviderScope
  ↓
Show SplashPage
  ↓
Check Auth Status
  ├─ Authenticated → Dashboard
  └─ Unauthenticated → OnboardingFlow
```

### 2.2 State Management (flutter_riverpod)

**Provider Architecture:**
```dart
// Global singletons
final authServiceProvider = Provider(...)
final keyboardBridgeProvider = Provider(...)

// Stream providers for reactive data
final authStateProvider = StreamProvider(...)
final currentUserProvider = StateNotifierProvider(...)

// Feature-specific providers
final healthScoringProvider = StateNotifierProvider(...)
final analysisLogsProvider = FutureProvider(...)
```

### 2.3 Async Handling

**Background Isolate for keyboard requests:**
```dart
// In main app (not keyboard)
Future<void> _handleKeyboardRequest() async {
  // This runs in background, doesn't block UI
  final result = await geminiAPI.analyze(messages);
  // Send back to keyboard via platform channel
}
```

## 3. Backend Services

### 3.1 Supabase PostgreSQL Schema

**users table:**
- Stores only de-identified metrics
- Baseline weights from quiz (w1, w2, w3)
- Consent timestamps
- No raw chat data ever stored

**analysis_logs table:**
- One row per keyboard use
- Stores: health_score, emotion, timestamp
- raw_text_hash: SHA-256 of redacted text (never raw)
- Rolling 7-day window for score calculation

### 3.2 Supabase Row-Level Security (RLS)

```sql
-- Users can only read/write their own records
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_isolation" ON users
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
```

### 3.3 Authentication Flow

```
User chooses Apple/Google/Email Sign-In
  ↓
Supabase Auth (handles OAuth redirects)
  ↓
Create/Link User Record
  ↓
Store JWT in secure_storage
  ↓
Use JWT for all subsequent requests
```

## 4. AI Pipeline (Critical Path)

### 4.1 Latency Budget

Total: **≤ 1200 ms** on 4G

```
Keyboard capture:      ~50 ms
Platform channel:      ~20 ms
Encryption:            ~30 ms
Network request:       ~400 ms (4G latency)
Cloudflare proxy:      ~100 ms (PII redaction + rate limit)
Gemini inference:      ~400 ms (API call)
Response handling:     ~50 ms
Decryption:            ~30 ms
UI update:             ~100 ms
─────────────────
Total:                 ~1180 ms ✓
```

### 4.2 Cloudflare Workers Proxy

**Why proxy instead of direct Gemini call?**

1. **Rate Limiting**: Enforce 60 requests/min per user at edge
2. **PII Redaction**: Scrub before API call (cost + safety)
3. **Encryption**: Handles E2E encryption/decryption
4. **Geographic Distribution**: Global edge near users

**PII Redaction Rules:**
```typescript
- HKID pattern (X123456(A)) → [REDACTED_ID]
- Email addresses → [REDACTED_EMAIL]
- Phone numbers (HK format) → [REDACTED_PHONE]
- MTR stations → [Commercial District], [Location], etc.
- Street addresses → [Location]
- Names → Auto-detect via NER, replace → [PERSON]
```

### 4.3 Gemini System Prompt

```
You are RelateOS, a Hong Kong relationship coach. Analyze the 
following chat in context of Cantonese/English code-switching 
and face-saving culture. Never translate slang literally. 
Output only JSON with keys: subtext_explanation, suggestions 
(array of 3 objects with tone and text <=40 chars), 
health_delta (0-1), detected_emotion.
```

**Important:** Never allow the model to:
- Provide relationship advice (only decode intent)
- Generate new suggestions without explicit request
- Output anything except JSON

## 5. Health Scoring Engine

### 5.1 Rolling 7-Day Window

- Fetched at 2 AM daily (or on-demand)
- Aggregates all analysis_logs from past 7 days
- Calculates single health score [0, 1]

### 5.2 Formula Components

**Direct Communication (w1 = 0.4):**
- Count of explicit statements vs passive ones
- Example: "I'd like to talk" vs "ok la"

**Emotional Needs (w2 = 0.35):**
- NLP sentiment scoring per message
- Keywords mapped to emotional needs
- Cantonese keywords: 明白 (understand), 體諒 (empathy)
- English keywords: appreciate, care, support

**Face-Saving Patterns (w3 = 0.25, negative factor):**
- Cantonese: 唔使理我, 隨便啦, 無所謂, ok la
- Indicates conflict avoidance (lowers score)
- Formula subtracts this term

### 5.3 Baseline Adjustment

User completes 5-question quiz on onboarding:
1. "How direct do you prefer communication?" (1-5)
2. "How important is avoiding conflict?" (1-5)
3. "How often do you express emotions?" (1-5)
4. "How much do you value harmony?" (1-5)
5. "How explicit should advice be?" (1-5)

Quiz score → percentile → ±10% weight adjustment

## 6. Wisdom Circle (Community Forum)

### 6.1 PII Redaction at Edge

**Deno Edge Function (Cloudflare):**
```typescript
// Every post creation triggers:
1. Extract text/image
2. Run NER model
3. Replace detected entities
4. Store redacted version
```

### 6.2 Anonymity Guarantee

- No user ID attached to posts
- Posts linked to random session token
- IP logging disabled
- Upvotes via Cloudflare Workers (no user tracking)

### 6.3 Moderation

**Automatic:**
- Run Gemini toxicity classifier
- If confidence > 0.7 → auto-flag for review
- Deploy content moderation model

## 7. Security & Compliance

### 7.1 End-to-End Encryption

**Algorithm:** AES-256-GCM

**Key Derivation:**
```
Derived Key = HKDF(
  salt=Supabase JWT,
  input_key_material=device_secret,
  info="com.relateos.keyboard",
  length=32
)
```

### 7.2 Data Minimization

```
✓ Raw text: Never stored
✓ Hash: SHA-256 of redacted text only
✓ Metadata: Emotion + health score only
✓ Retention: 90-day auto-delete
✓ Consent: Explicitly logged with timestamp
✓ Revocation: Delete all data within 72 hours
```

### 7.3 Privacy Infrastructure

- TLS 1.3 for all network calls
- Certificate pinning optional (v1.2)
- Secure Enclave for encryption keys (v1.2)
- Privacy Dashboard (v1.1)

## 8. Performance Optimization

### 8.1 Keyboard Initial Load

**Goal:** ≤ 300 ms TTI

```swift
// Use lightweight UI framework
// Pre-render 3 suggestion buttons
// Load suggestions asynchronously
// Show spinner while fetching
```

### 8.2 App Cold Start

**Goal:** ≤ 1.8 s

```dart
// Lazy-load features
// Split bundles with FVM
// Cache user data locally
// Parallel initialization
```

### 8.3 Caching Strategy

**Local:**
- User metadata (1 hour TTL)
- Last 20 messages (in-memory, app group)
- Keyboard theme (permanent)

**Remote:**
- Health scores (24 hour batch)
- User settings (1 hour)
- Wisdom Circle posts (hourly feed)

## 9. Testing Strategy

### Unit Tests
```bash
flutter test lib/features/health_scoring/
```

### Integration Tests
- Platform channel communication
- Supabase queries with RLS
- Gemini API mocking

### Performance Tests
- Keyboard TTI measurement
- Memory profiling
- Network latency simulation

## 10. Deployment Pipeline

### Pre-Deployment Checklist

1. **iOS:**
   - [ ] Keyboard < 40 MB
   - [ ] App + Keyboard < 100 MB total
   - [ ] Keyboard TTI < 300 ms
   - [ ] Memory peak < 50 MB

2. **Cloudflare:**
   - [ ] Rate limiter active
   - [ ] PII redaction tests pass
   - [ ] Latency < 400 ms

3. **Database:**
   - [ ] RLS policies enabled
   - [ ] Backups configured
   - [ ] Indexes optimized

### Deployment Stages

1. **Internal Testing** (Week 1-2)
2. **Beta Testers** (Week 3-6)
3. **Product Hunt Launch** (Week 7-8)
4. **General Availability** (Week 9-10)

---

**Next Architecture Phases:**
- v1.1: Android + Push notifications
- v1.2: Voice transcription, Couples dashboard
- v2.0: Real-time multiplayer scoring

---

**Last Updated:** April 8, 2026
