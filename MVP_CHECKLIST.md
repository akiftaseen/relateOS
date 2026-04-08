# RelateOS MVP Development Checklist

## Sprint Planning (Weeks 1-10)

### Week 1-2: Foundation & Auth ✓
- [x] Project structure created
- [x] Flutter + iOS setup
- [x] Supabase configuration
- [x] Platform channel bridge (Swift/Dart)
- [ ] Implement Apple Sign-In
- [ ] Implement Google Sign-In
- [ ] Test auth flow

### Week 3: Keyboard Extension MVP
- [ ] Build UIInputViewController UI (3 buttons + subtext)
- [ ] Implement text capture (last 20 messages)
- [ ] Platform channel communication
- [ ] Mock suggestion display
- [ ] Latency testing (target: < 300 ms TTI)
- [ ] Memory profiling (target: < 50 MB)

### Week 4: AI Pipeline
- [ ] Deploy Cloudflare Workers
- [ ] Implement PII redaction
- [ ] Rate limiting via KV store
- [ ] Google Gemini API integration
- [ ] Request/response encryption (AES-256-GCM)
- [ ] Latency optimization (target: ≤ 1200 ms)

### Week 5: Health Scoring Engine
- [ ] Implement scoring formula
- [ ] Add face-saving keyword detection
- [ ] Create emotional needs mapping
- [ ] Test with Cantonese/English samples
- [ ] 7-day rollup query
- [ ] Dashboard visualization

### Week 6: Onboarding Flow
- [ ] Language selection (zh-HK, en, zh-CN)
- [ ] 5-question baseline quiz
- [ ] Baseline weight calculation
- [ ] Keyboard permission consent modal
- [ ] Log consent timestamp
- [ ] Complete onboarding flow

### Week 7: Dashboard & Analytics
- [ ] Display current health score
- [ ] Show 7-day trend chart
- [ ] Display emotion distribution
- [ ] Show keyboard usage stats
- [ ] Analytics refresh via Riverpod
- [ ] Theme toggle (light/dark)

### Week 8: Wisdom Circle
- [ ] Post creation UI (text + optional screenshot)
- [ ] PII redaction via Cloudflare Edge Function
- [ ] Anonymous posting (no user tracking)
- [ ] Upvote feature with decay algorithm
- [ ] Feed pagination
- [ ] Moderation dashboard

### Week 9: Testing & Optimization
- [ ] Unit tests (health scoring, models)
- [ ] Integration tests (platform channels, Supabase)
- [ ] Performance profiling (memory, latency)
- [ ] Keyboard size measurement (verify < 40 MB)
- [ ] Cold start time (target: < 1.8 s)
- [ ] 4G network simulation testing

### Week 10: Deployment & QA
- [ ] TestFlight build
- [ ] Beta user recruitment
- [ ] Bug triage & fixes
- [ ] Final performance sweep
- [ ] App Store submission
- [ ] Release notes & marketing prep

## Detailed Task List

### Authentication
- [ ] Create Supabase project
- [ ] Add Apple Sign-In provider
- [ ] Add Google Sign-In provider
- [ ] Implement email verification
- [ ] Create user signup flow
- [ ] Implement secure token storage
- [ ] Add logout functionality

### Keyboard Extension
- [ ] Create iOS target in Xcode
- [ ] Configure App Groups capability
- [ ] Implement UIInputViewController
- [ ] Add suggestion button UI (3 buttons)
- [ ] Add subtext tooltip
- [ ] Implement text capture logic
- [ ] Add mock loading indicator
- [ ] Connect to platform channel
- [ ] Performance profiling

### Platform Channel
- [ ] Create MethodChannel (Dart side)
- [ ] Implement channel handlers (Swift side)
- [ ] Test message passing
- [ ] Handle error cases
- [ ] Add encryption layer
- [ ] Test with real keyboard

### Cloudflare Workers
- [ ] Create Workers account
- [ ] Setup Wrangler CLI
- [ ] Implement analyzeIntent endpoint
- [ ] Add PII redaction rules
- [ ] Setup KV namespace for rate limiting
- [ ] Integrate Gemini API
- [ ] Add request signing
- [ ] Setup production domain

### Health Scoring
- [ ] Implement scoring formula
- [ ] Add Cantonese keyword list
- [ ] Add English equivalents
- [ ] Test with sample conversations
- [ ] Create 7-day aggregation query
- [ ] Setup daily cron job (Supabase Edge Function)
- [ ] Add weight adjustment from quiz

### Dashboard
- [ ] Create dashboard layout
- [ ] Add health score widget
- [ ] Add trend chart (Chart.flutter)
- [ ] Add emotion pie chart
- [ ] Add usage statistics
- [ ] Add navigation drawer
- [ ] Setup responsive design

### Settings & Onboarding
- [ ] Create language picker
- [ ] Build baseline quiz (5 questions)
- [ ] Calculate quiz percentile
- [ ] Create consent modal
- [ ] Store consent timestamp
- [ ] Add privacy policy modal
- [ ] Create notification settings

### Wisdom Circle
- [ ] Create anonymous post UI
- [ ] Implement post creation
- [ ] Setup PII redaction pipeline
- [ ] Create feed UI
- [ ] Add upvote feature
- [ ] Implement decay algorithm
- [ ] Add moderation dashboard
- [ ] Setup auto-flagging (toxicity > 0.7)

### Testing
- [ ] Unit test: HealthScoringEngine
- [ ] Unit test: Platform channel serialization
- [ ] Integration test: Auth flow
- [ ] Integration test: Supabase RLS
- [ ] Performance test: Keyboard TTI
- [ ] Performance test: App cold start
- [ ] Network test: Latency on 4G

### Documentation
- [ ] Finalize SETUP.md
- [ ] Add code comments
- [ ] Create API documentation
- [ ] Write troubleshooting guide
- [ ] Add screenshot guide
- [ ] Create deployment checklist

## Performance Checklist

### Keyboard Extension
- [ ] Binary size < 40 MB (`lipo -info`)
- [ ] Memory peak < 50 MB (Instruments)
- [ ] TTI < 300 ms (timestamp comparison)
- [ ] Suggestion rendering smooth (60 fps)
- [ ] No memory leaks (detached views)

### Main App
- [ ] Cold start < 1.8 s (Time Profiler)
- [ ] Dashboard load < 500 ms
- [ ] Supabase queries optimized (check plan)
- [ ] No redundant API calls
- [ ] Smooth scrolling (60 fps)

### AI Pipeline
- [ ] End-to-end latency < 1200 ms
- [ ] Cloudflare response < 400 ms
- [ ] Gemini inference < 500 ms
- [ ] Encryption overhead < 50 ms
- [ ] Network timeout: 3 seconds

## Security Checklist

- [ ] Supabase RLS enabled for all tables
- [ ] Raw text never persisted (only hash)
- [ ] AES-256-GCM encryption working
- [ ] Keyboard doesn't log network calls
- [ ] API keys stored in Cloudflare secrets
- [ ] JWT refresh token rotation
- [ ] Consent timestamps logged
- [ ] GDPR deletion pipeline ready (72 hour)

## Deployment Checklist

- [ ] Supabase backups configured
- [ ] Cloudflare Workers domain setup
- [ ] Monitoring & error tracking (Sentry)
- [ ] Analytics setup (Segment/Mixpanel)
- [ ] Rate limiting tested
- [ ] PII redaction verified
- [ ] Keyboard permissions explained clearly
- [ ] Privacy policy updated

## Known Issues & Deferred Items

### Deferred to v1.1
- [ ] Real-time voice transcription
- [ ] Android InputMethodService
- [ ] Proactive push notifications
- [ ] Direct Octopus/MTR API integration (OCR workaround in MVP)

### Deferred to v1.2+
- [ ] Shared couples dashboard
- [ ] Multi-user relationship linking
- [ ] Advanced NLP models fine-tuning
- [ ] Video message support

## Success Metrics

### User Engagement
- Target: 80% keyboard permission acceptance
- Target: 40% daily active users by week 10
- Target: 5 min avg session duration

### Technical
- Target: < 100ms P95 latency
- Target: 99.9% API uptime
- Target: < 5 crashes per 1000 sessions

### Business
- Target: 50+ beta users by week 6
- Target: $0 CAC (organic)
- Target: 4.5+ App Store rating

---

**Last Updated:** April 8, 2026
**Status:** Ready for Development
