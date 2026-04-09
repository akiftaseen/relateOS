# Technical Architecture and Implementation Specification for RelateOS

## iOS-First Relationship Intelligence Keyboard

The development of a context-aware relationship intelligence keyboard demands a sophisticated synthesis of advanced natural language processing, stringent privacy architectures, and rigorous resource optimization.

RelateOS aims to operate directly at the point of user input, dynamically analyzing conversational sentiment, mitigating conflict escalation, and offering real-time communication coaching.

Because the deployment target is an iOS Custom Keyboard Extension, the application must execute its core responsibilities within an exceptionally hostile computational sandbox. The operating system imposes strict memory limits, restricts direct hardware access, and actively monitors extension lifecycles to preserve host app performance.

Consequently, the architectural foundation of RelateOS cannot rely on traditional mobile development paradigms. It requires meticulous orchestration of native rendering frameworks, highly optimized edge computing, and specialized large language models capable of processing nuanced, multilingual interactions.

This specification evaluates the initially proposed technology stack against highly optimized native and cross-platform alternatives. It provides implementation blueprints for:

- Integrating the iOS 26 Liquid Glass design system.
- Operating within iOS keyboard extension memory constraints.
- Securely redacting PII at the network edge.
- Processing a mathematical relationship health model.
- Optimizing model routing for Cantonese code-switching and low-latency interaction.

---

## 1. Architectural Paradigm and Technology Stack Evaluation

### 1.1 Frontend Framework Selection: Cross-Platform vs Native

The deployment target for RelateOS is an iOS Custom Keyboard Extension governed by `UIInputViewController`. This environment is subject to aggressive memory policing by iOS Jetsam.

Using Flutter for the keyboard UI introduces major systemic risk:

- Flutter spins up its own C++ engine and rendering pipeline (Skia/Impeller).
- Startup memory overhead often exceeds 20-30 MB before app-specific logic loads.
- Third-party keyboard memory limits historically fall around 40-60 MB on many devices.
- Exceeding limits causes silent termination and fallback to the system keyboard.

Even with higher limits on newer devices, baseline ecosystem compatibility demands the lower historical memory target.

Native Swift + SwiftUI is a better fit:

- Reuses system frameworks already resident in memory.
- Much lower marginal memory for UI rendering.
- iOS 26 Liquid Glass is deeply integrated into native SwiftUI rendering.
- Avoids expensive custom shader recreation required in cross-platform engines.

**Decision:** The keyboard extension should be implemented natively in Swift 6 + SwiftUI, bridged through `UIHostingController` inside `UIInputViewController`.

If future Android parity is required, use Kotlin Multiplatform for shared business logic only, while preserving a native SwiftUI presentation layer on iOS.

### 1.2 Backend Infrastructure: Supabase + Cloudflare

Supabase and Cloudflare are complementary when responsibilities are split correctly.

Supabase (system of record):

- PostgreSQL relational data
- Authentication
- User profile/configuration
- Subscription and longitudinal analytics

Cloudflare Workers (keyboard real-time proxy):

- Ultra-low-latency edge execution (V8 isolate model)
- Decryption/sanitization pipeline
- Prompt routing
- Caching via Cloudflare KV

**Decision:**

- Use Supabase for container app data and account state.
- Use Cloudflare Workers exclusively for keyboard extension request path.

### 1.3 Language Model Routing and Multilingual Optimization

Gemini 2.5 Pro is strong for deep reasoning and long context, but real-time Cantonese code-switching often benefits from specialized models.

For low-latency multilingual relationship coaching:

- `DeepSeek-V3` / `Qwen-3` for real-time edge inference
- `Gemini 2.5 Pro` for deep asynchronous historical analysis
- `Apple Foundation Models` for instant on-device lightweight tasks

#### Inference Tiering

| Inference Tier | Model | Primary Rationale |
|---|---|---|
| Tier 1: Local Inference | Apple Foundation Models | On-device, zero cloud latency/cost, strongest privacy for lightweight tasks |
| Tier 2: Real-Time Edge | DeepSeek-V3 / Qwen-3 | Fast code-switching and culturally nuanced conversational coaching |
| Tier 3: Deep Context | Gemini 2.5 Pro | Long-history analysis and complex multi-step reasoning |

---

## 2. iOS Keyboard Extension Constraints and Lifecycle

### 2.1 Jetsam Memory Ceiling and Sandbox Limits

Keyboard extensions run in a separate process and are aggressively monitored by Jetsam.

Operational constraints:

- Typical memory ceiling often in the ~40-60 MB range on many devices.
- Exceeding memory triggers `EXC_CRASH (SIGQUIT)` and immediate termination.

Engineering requirements:

- Keep UI and state decoupled.
- Avoid retain cycles (`[weak self]`/`unowned` in closures/tasks).
- Lazy-load heavy resources after initial keyboard render.
- Prioritize first-paint responsiveness before analysis/network work.

### 2.2 Swift 6 Strict Concurrency and Actor Isolation

Real-time typing introduces overlapping asynchronous events. Shared mutable state without isolation leads to race conditions and crashes.

Use Swift 6 actor-based state management for analysis buffers and token streams.

Benefits:

- Compile-time data race protection.
- Serialized mutable state access.
- Deterministic text/analysis pipeline under fast typing.

### 2.3 Inter-Process Communication: App Groups + Keychain Sharing

Keyboard extension and container app must share limited state securely.

- App Groups (`UserDefaults(suiteName:)`) for non-sensitive shared preferences.
- Keychain Access Groups for sensitive tokens/keys.

Never store sensitive auth/session material in plain App Group storage.

---

## 3. iOS 26 Liquid Glass Design System Integration

### 3.1 Optical Principles and Layer Hierarchy

Liquid Glass introduces lensing/refraction behaviors and fluid interaction morphing.

Design rule:

- Use Liquid Glass for overlay/functional layers (suggestions, coaching bubbles, warnings).
- Do not apply it to foundational content planes in ways that reduce readability.

### 3.2 SwiftUI Implementation Mechanics

Apply through `.glassEffect(_:in:)` at the end of the modifier chain.

```swift
Text(suggestion.deEscalationText)
    .font(.subheadline)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .glassEffect(.regular.tint(.blue).interactive(), in: .capsule)
```

Variant guidance:

| Variant | Use Case | Transparency | Adaptivity |
|---|---|---|---|
| `.regular` | Standard toolbars/controls | Medium | Fully adaptive |
| `.clear` | Floating controls over vivid backgrounds | High | Limited; may need dimming support |
| `.identity` | Conditional disable/toggle states | Opaque/none | N/A |

### 3.3 Morphing and `GlassEffectContainer`

Use `GlassEffectContainer` to enable shared background sampling and union-style morphing behavior between adjacent glass elements.

For animated transitions between states:

- Shared `@Namespace`
- `.glassEffectID(_:in:)`
- `withAnimation` around hierarchy changes

### 3.4 Accessibility and Degradation

System accessibility settings can override rendering:

- Reduce Transparency -> more opaque fallback materials.
- Increase Contrast -> stronger borders and separation.

Ensure color/tint selections maintain contrast targets (e.g., 4.5:1 where applicable).

---

## 4. Data Security, Edge Cryptography, and PII Redaction

RelateOS processes highly sensitive interpersonal text and must enforce privacy-by-design.

### 4.1 Device-Side Encryption

Before network transit:

- Encrypt with AES-256-GCM using CryptoKit.
- Use key material from shared Keychain access group.
- Send Base64 payload containing nonce + ciphertext + tag over TLS 1.3.

### 4.2 Edge Decryption + RECAP Redaction Framework

At Cloudflare Worker:

- Decrypt via Web Crypto API.
- Perform structured multi-phase redaction.
- Process in ephemeral memory during request lifecycle.

#### RECAP Pipeline

| Phase | Technology | Target Entities | Performance |
|---|---|---|---|
| Phase 1: Deterministic Elimination | Optimized Regex | IDs, cards, email, phone | ~2-5 ms, very high precision |
| Phase 2: Contextual Disambiguation | Lightweight NER (GLiNER) | Names, places, colloquial references | ~5-15 ms, high recall |
| Phase 3: Semantic Token Substitution | Direct replacement | Structured placeholders preserving grammar | Negligible overhead |

Tokenization strategy should preserve semantics for downstream LLM reasoning while removing direct identifiers.

---

## 5. Relationship Health Model (`H_score`)

RelateOS computes an ambient relationship health score over rolling conversational windows.

### 5.1 Cultural-Linguistic Calibration

Model logic is informed by RCISS-like positive/negative interaction dynamics, adapted for Cantonese communication realities:

- Face-saving and harmony signaling are highly meaningful.
- Passive-aggressive markers can indicate escalation despite neutral literal wording.
- Validation/repair signals should increase stability score.

### 5.2 Mathematical Formulation

$$
H_{score} = \alpha \sum_{t=1}^{n}(P_t - N_t) + \beta\left(\frac{V_t}{C_t + 1}\right)
$$

Where:

- $P_t$: positive sentiment at turn $t$
- $N_t$: negative sentiment at turn $t$
- $V_t$: validation/face-saving markers
- $C_t$: conflict/escalation markers
- $\alpha$: sentiment weight coefficient
- $\beta$: resolution efficacy coefficient

`C_t + 1` avoids divide-by-zero in conflict-free windows.

### 5.3 Swift 6 Actor Implementation Example

```swift
struct InteractionToken: Sendable {
    let positiveWeight: Double
    let negativeWeight: Double
    let isFaceSaving: Bool
    let isConflict: Bool
}

actor HealthScoreProcessor {
    private var conversationalTokens: [InteractionToken] = []

    // Tunable coefficients based on user calibration
    private let alpha: Double = 1.2
    private let beta: Double = 0.8

    func append(token: InteractionToken) {
        conversationalTokens.append(token)
    }

    func calculateHScore() -> Double {
        let baseSentiment = conversationalTokens.reduce(0.0) { accumulated, token in
            accumulated + (token.positiveWeight - token.negativeWeight)
        }

        let validationCount = conversationalTokens.filter { $0.isFaceSaving }.count
        let conflictCount = conversationalTokens.filter { $0.isConflict }.count

        let resolutionRatio = Double(validationCount) / Double(conflictCount + 1)

        return (alpha * baseSentiment) + (beta * resolutionRatio)
    }
}
```

When the score crosses configured negative thresholds, RelateOS can trigger de-escalation coaching overlays with culturally appropriate phrasing.

---

## 6. Final Implementation Direction

To operate successfully at the intersection of AI, cultural psychology, and iOS extension constraints, RelateOS should adopt the following architecture:

- Native keyboard UI in Swift 6 + SwiftUI (`UIHostingController` bridge).
- Strict extension memory budgeting and lifecycle discipline.
- Actor-isolated analysis state and concurrency model.
- App Groups + Keychain Access Groups for secure inter-process sharing.
- Device-side AES-GCM encryption and edge-side RECAP redaction.
- Tiered model routing:
  - On-device Apple Foundation Models for lightweight instant tasks.
  - DeepSeek-V3/Qwen-3 for real-time Cantonese code-switch coaching.
  - Gemini 2.5 Pro for deep asynchronous historical intelligence.

This architecture preserves responsiveness, privacy, and linguistic fidelity while remaining viable inside keyboard extension constraints.
