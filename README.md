# RelateOS

**Context-aware relationship intelligence platform for the Hong Kong market**

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-Confidential-red)

## 📋 Overview

RelateOS is a system-level relationship assistant that decodes multilingual communication nuances and actively mitigates "face-saving" conflict escalation in high-context Asian relationships.

### Core Features

- **Zero-Friction Keyboard Extension** - Contextual AI suggestions while typing
- **Health Score Engine** - 7-day rolling relationship health metrics
- **Wisdom Circle** - Anonymous community forum with AI-powered moderation
- **Multi-language Support** - Cantonese, Mandarin, English with code-switching awareness
- **Privacy-First Architecture** - End-to-end encryption, no message persistence

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    iOS/Android Main App                      │
│                      (Flutter 3.24+)                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Auth → Dashboard → Health Score → Wisdom Circle      │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────┬──────────────────────────────────┬────────────┘
               │                                  │
        Platform Channel              (Background Isolate)
               │                                  │
┌──────────────┴──────────────┐  ┌────────────────┴────────────┐
│  Keyboard Extension (Swift)  │  │   Health Scoring Engine    │
│  - UIInputViewController     │  │   - 7-day rolling window   │
│  - 20-message cache          │  │   - Emotional mapping      │
│  - Suggestion bubbles        │  │   - Face-saving detection  │
└──────────────┬───────────────┘  └────────────┬───────────────┘
               │                               │
               └───────────────┬───────────────┘
                               │
                        App Groups/Keychain
                               │
        ┌──────────────────────┴──────────────────────┐
        │                                             │
┌───────┴────────────────────────────┐   ┌──────────┴─────────────┐
│   Cloudflare Workers Proxy          │   │  Supabase Backend      │
│   (PII Redaction, Rate Limiting)    │   │  (PostgreSQL 15)       │
│                                     │   │                        │
│   ↓                                 │   │  - Users               │
│   Google Gemini 2.5 Pro             │   │  - Analysis Logs       │
│   (AI Intent Analysis)              │   │  - Wisdom Posts        │
└─────────────────────────────────────┘   └────────────────────────┘
```

## 📁 Project Structure

```
relateOS/
├── lib/                          # Flutter main app (45 KB max initial)
│   ├── main.dart
│   ├── config/
│   │   ├── supabase_config.dart
│   │   └── theme.dart
│   ├── core/
│   │   ├── platform/
│   │   │   └── keyboard_bridge_service.dart
│   │   ├── models/
│   │   └── utils/
│   ├── features/
│   │   ├── auth/                 # Epic 0: Onboarding & Auth
│   │   ├── keyboard/             # Epic 1: Keyboard Extension
│   │   ├── health_scoring/       # Epic 2: Scoring Engine
│   │   └── wisdom_circle/        # Epic 3: Community Forum
│   ├── providers/                # Riverpod state management
│   └── shared/                   # Common widgets
├── ios/
│   ├── Runner/                   # Main iOS app
│   │   ├── GeneratedPluginRegistrant.swift
│   │   ├── KeyboardBridgeHandler.swift
│   │   └── Runner.xcworkspace
│   └── KeyboardExtension/        # Keyboard target (< 40 MB)
│       ├── KeyboardViewController.swift
│       └── Info.plist
├── workers/                      # Cloudflare Workers
│   └── ai-proxy/
│       ├── src/index.ts
│       ├── wrangler.toml
│       └── package.json
├── pubspec.yaml
├── SETUP.md                      # Detailed setup instructions
├── ARCHITECTURE.md               # Deep dive technical docs
└── README.md                     # This file
```

## 🚀 Quick Start

### Prerequisites

- **macOS 13+** with Xcode 15+
- **Flutter 3.24+**
- **Supabase account** (free tier OK)
- **Cloudflare account** (free tier OK)
- **Google Gemini API key**

### 1. Clone and Install

```bash
cd /Users/akiftaseen/Documents/relateOS
flutter pub get
```

### 2. Configure Supabase

1. Create free project at supabase.com
2. Copy credentials
3. Update `lib/config/supabase_config.dart`:

```dart
const String supabaseUrl = 'https://your-project.supabase.co';
const String supabaseAnonKey = 'your-anon-key';
```

4. Run SQL schema setup from `SETUP.md`

### 3. Configure Cloudflare Workers

```bash
cd workers/ai-proxy
wrangler login
wrangler secret put GEMINI_API_KEY
wrangler publish
```

### 4. Run iOS App

```bash
flutter run  # For simulator
# or
flutter run -d <device-id>  # For device
```

See [SETUP.md](SETUP.md) for detailed step-by-step instructions.

## 📊 Data Models

### users table
```sql
id: UUID (PK)
created_at: TIMESTAMPTZ
preferred_language: VARCHAR(10) -- en, zh-HK, zh-CN
subscription_tier: VARCHAR(20) -- free, pro, enterprise
onboarding_completed: BOOLEAN
consent_keyboard_granted: TIMESTAMPTZ
baseline_weights: JSONB -- {w1, w2, w3, quiz_percentile}
```

### analysis_logs table
```sql
id: UUID (PK)
user_id: UUID (FK → users)
health_score_snapshot: FLOAT -- [0, 1]
primary_emotion_detected: VARCHAR(50)
created_at: TIMESTAMPTZ
raw_text_hash: VARCHAR(64) -- SHA-256 (never raw text)
direct_statement_count: INT
emotional_need_score: FLOAT
```

## 🧮 Health Score Formula

$$H_{score} = \left(w_1 \cdot \frac{C_{direct}}{C_{total}}\right) + \left(w_2 \cdot \sum_{i=1}^{n} M_i\right) - \left(w_3 \cdot \frac{R_{escalation}}{T_{interactions}}\right)$$

Where:
- **$w_1 = 0.4$** - Direct communication weight
- **$w_2 = 0.35$** - Emotional needs weight
- **$w_3 = 0.25$** - Face-saving keyword weight
- Adjusted ±10% based on 5-question baseline quiz
- Running window: **last 7 days**
- Update frequency: **every 24 hours**

## 🔐 Security

- **End-to-End Encryption**: AES-256-GCM per message
- **No Message Persistence**: Raw text never saved, only SHA-256 hash
- **PII Redaction**: Automatic on Cloudflare edge (names, phone, HKID, addresses)
- **Row-Level Security**: Supabase RLS policies enforce user data isolation
- **Rate Limiting**: 60 requests/minute per user via Cloudflare
- **Consent Logging**: Keyboard access logged with timestamp

## ⚡ Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Keyboard TTI | ≤ 300 ms | Time to first suggestion |
| AI Roundtrip | ≤ 1200 ms | 4G latency budget |
| App Cold Start | ≤ 1.8 s | First frame time |
| Keyboard Size | < 40 MB | iOS extension limit |
| Memory (Keyboard) | < 50 MB | iOS constraint |

## 🌐 Supported Languages

- **Cantonese** (zh-HK) - Primary market
- **English** (en) - Business use
- **Mandarin Chinese** (zh-CN) - Secondary market
- **Code-switching aware** - Detects Cantonese/English mixing

## 🛠️ Tech Stack

### Frontend
- **Flutter 3.24+** - Cross-platform main app
- **flutter_riverpod** - State management
- **supabase_flutter** - Backend as a service
- **flutter_secure_storage** - Encrypted local storage

### iOS Native
- **Swift 6.0** - Keyboard extension
- **UIKit** - Keyboard UI (UIInputViewController)
- **App Groups** - Inter-app communication
- **Keychain** - Secure credential storage

### Backend
- **Supabase (PostgreSQL 15)** - Database & Auth
- **Cloudflare Workers** - Edge computing
- **Google Gemini 2.5 Pro** - AI analysis

### DevOps
- **Xcode** - iOS development
- **CocoaPods** - iOS dependency management
- **Wrangler** - Cloudflare deployment

## 🔄 API Contracts

### POST /api/v1/analyze-intent

**Request:**
```json
{
  "user_id": "uuid",
  "context_messages": ["msg1", "msg2", ...],
  "target_language": "zh-HK",
  "current_draft": "optional string"
}
```

**Response:**
```json
{
  "subtext_explanation": "string",
  "suggestions": [
    {"tone": "empathetic", "text": "I hear you"},
    {"tone": "supportive", "text": "Take time"},
    {"tone": "direct", "text": "Let's talk"}
  ],
  "health_delta": 0.15,
  "latency_ms": 423,
  "detected_emotion": "concerned"
}
```

## 📝 Development Status

### Epic 0: Onboarding & Authentication ✅ (Foundation)
- [x] Project structure
- [x] Supabase config
- [ ] Apple Sign-In integration
- [ ] Google Sign-In integration
- [ ] Baseline 5-question quiz

### Epic 1: Keyboard Extension ⏳ (In Progress)
- [x] UIInputViewController scaffold
- [x] Platform channel bridge
- [ ] Real-time suggestion rendering
- [ ] Latency optimization (< 300ms TTI)
- [ ] Memory profiling (< 50MB)

### Epic 2: Health Scoring ✅ (Core Engine)
- [x] Scoring formula implementation
- [x] Face-saving keyword detection
- [x] Emotional needs mapping
- [ ] 7-day rollup cron job
- [ ] Dashboard visualization

### Epic 3: Wisdom Circle ⏳ (Community)
- [ ] Anonymous posting UI
- [ ] Cloudflare Edge Function for PII redaction
- [ ] Upvote decay algorithm
- [ ] AI moderation (toxicity > 0.7)

## 🔗 Important Endpoints

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Supabase | `https://your-project.supabase.co` | Database & Auth |
| Cloudflare Workers | `https://relateos-ai-proxy.relateos.workers.dev` | AI routing |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/models/...` | NLP analysis |

## 📚 Documentation

- **[SETUP.md](SETUP.md)** - Step-by-step build and deployment guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Deep technical design document
- **[PRD.txt](PRD.txt)** - Original product requirements

## 🐛 Known Issues

- [ ] Keyboard latency > 300ms on older devices
- [ ] Android support deferred to v1.1
- [ ] Real-time push notifications deferred to v1.1

## 🚀 Roadmap

### MVP (Weeks 1-10) ✅
- iOS keyboard extension
- solo-mode relationship health scoring
- Wisdom Circle (anonymous forum)

### v1.1 (Future)
- Android InputMethodService
- Real-time push notifications
- Refined AI model tuning

### v1.2 (Future)
- Voice note transcription
- Shared couples dashboard
- Multi-user relationship linking

## 👤 Author

Built for Akif (Hong Kong market) — Confidential

## 📄 License

Confidential - All rights reserved

---

**Last Updated**: April 8, 2026 | **Version**: 0.1.0-MVP
