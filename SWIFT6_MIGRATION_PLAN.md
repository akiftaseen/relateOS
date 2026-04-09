# RelateOS Swift 6 Full Migration Plan

## Goal
Migrate RelateOS from Flutter-driven runtime to fully native iOS Swift 6 + SwiftUI while preserving Keyboard Extension functionality.

## Completed
- Native iOS app entry wired in Swift:
  - App delegate no longer depends on Flutter delegate classes.
  - Scene delegate now boots a native SwiftUI root.
- Native SwiftUI shell screens implemented:
  - Splash view
  - Home/dashboard view
  - Keyboard extension guidance content
- Native shared-data bridge implemented:
  - App Group read/write helpers
  - Health summary accessors
- Native auth domain/services stubs implemented in Swift:
  - User model equivalents
  - Baseline weights model
  - Supabase REST auth/user service scaffolding
- Keyboard extension remains native Swift and integrated with trend sample persistence.
- Xcode build verification passes for Runner + KeyboardExtension.

## In Progress
- Replacing remaining Flutter-side app features with native Swift modules.

## Remaining Work
1. Native Auth UX
- Build SwiftUI sign-in screens (Apple, Google, email/password).
- Wire OAuth callbacks and session persistence in App Group + Keychain Access Group.
- Remove Flutter auth services and providers.

2. Native Supabase Session Layer
- Add token refresh handling and background session hydration.
- Add secure keychain storage for access/refresh tokens.

3. Native Dashboard + Analytics
- Port health score/trend cards from Flutter targets.
- Add 7-day chart and emotion distribution in SwiftUI.
- Remove Flutter chart dependencies.

4. Native Settings + Onboarding
- Language picker (zh-HK, en, zh-CN).
- Baseline quiz and coefficient persistence.
- Keyboard permission consent and timestamp logging.

5. Native Keyboard Data Sync
- Replace any remaining Flutter channel pathways with native App Group + service abstractions.
- Keep extension APIs cleanly decoupled from app runtime.

6. Build/Tooling Cleanup
- Switch standard run/debug from Flutter CLI to Xcode scheme tooling.
- Remove Flutter runtime bootstrapping files once native feature parity is complete.
- Prune Flutter dependencies from iOS target and then from repository.

7. Repository Cleanup
- Archive or remove `lib/` Dart implementation after parity validation.
- Update README/SETUP/ARCHITECTURE docs for Swift-native workflow.

## Validation Gate (Before Deleting Flutter)
- Native app feature parity reached for MVP workflows.
- Keyboard extension fully operational with App Group trend sync.
- Xcode simulator build + device build successful.
- No references to FlutterViewController/FlutterSceneDelegate/FlutterAppDelegate in Runner target.
