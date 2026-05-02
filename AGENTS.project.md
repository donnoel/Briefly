# AGENTS.project.md

# Briefly Project Guide for Agents

## Product intent
Briefly is an iOS learning app for fast, repeatable flashcard study sessions.
Users create or generate topic packs, review by section, and track learning progress over time.
Success means users can reliably add content, complete deck sessions, and resume progress without data loss.

## Current product phase (MVP+ implemented)
1) Current scope
- Topic library with featured, continue-learning, category browse, active/completed grouping, and contextual sticky headers during scroll
- Section-based deck sessions with multiple-choice quiz flow
- Local persistence for user topic packs (`user_content.json`)
- Topic completion/deletion/order persistence in `UserDefaults`
- Backend-assisted topic generation with review/edit-before-save
- Settings surface for generation status and app preferences

2) Architecture boundaries
- SwiftUI views: rendering and user interaction
- View models: screen state + intents
- Stores/repository: persistence, ordering, completion/deletion, progress
- Services: backend generation client, content generation, keychain/preferences

3) Reliability and UX goals
- Clean build with no warnings
- Deterministic local persistence and stable ordering behavior
- No data loss during delete/re-add/edit-save flows
- Clear error messaging for API/network/decoding failures
- Avoid duplicate/invalid topic identity collisions

4) Testing priorities
- Content repository merge semantics (id/title conflicts)
- Delete/re-add persistence behavior
- Ordering persistence after mutations
- Generation review save behavior on success/failure

## Architecture snapshot (current)
- App entry: `/Users/donnoel/Development/Briefly/Briefly/App/BrieflyApp.swift`
- Root navigation: `/Users/donnoel/Development/Briefly/Briefly/Views/RootView.swift`
- Coordinator: `/Users/donnoel/Development/Briefly/Briefly/App/AppCoordinator.swift`
- Repository/stores:
  - `/Users/donnoel/Development/Briefly/Briefly/Content/ContentRepository.swift`
  - `/Users/donnoel/Development/Briefly/Briefly/Store/ContentDiskStore.swift`
  - `/Users/donnoel/Development/Briefly/Briefly/Store/TopicStatusStore.swift`
  - `/Users/donnoel/Development/Briefly/Briefly/Store/TopicOrderStore.swift`
  - `/Users/donnoel/Development/Briefly/Briefly/Store/ProgressStore.swift`
  - `/Users/donnoel/Development/Briefly/Briefly/Store/RecentTopicsStore.swift`
- AI services:
  - `/Users/donnoel/Development/Briefly/Briefly/Services/BrieflyBackendClient.swift`
  - `/Users/donnoel/Development/Briefly/Briefly/Services/AIGenerationJobTransport.swift`
  - `/Users/donnoel/Development/Briefly/Briefly/Services/OpenAIClient.swift`
  - `/Users/donnoel/Development/Briefly/Briefly/Services/AIContentService.swift`

## Generation backend migration notes
- Current production path remains synchronous text generation via `AIGenerationTransport.generateText(prompt:)`.
- App now includes an additive async-job seam (`AIGenerationJobTransport`) with `start/status/result` methods.
- `AIContentService` exposes job-based methods that reuse existing JSON normalization, DTO decode, trimming, and validation.
- `BrieflyBackendClient` currently bridges job semantics in-process while backend `/jobs` endpoints are being rolled out.
- When backend job endpoints are ready, swap `BrieflyBackendClient` job method internals to call `/jobs` without changing view/view-model call sites.

## Concurrency rules (important)
- Keep SwiftUI-facing state on `@MainActor`.
- Keep networking and disk IO in services/repository boundaries.
- Do not broaden main-actor isolation to hide data-race warnings.

## Behavior invariants (do not regress)
- Active/completed grouping must remain consistent with stored completion state.
- Deleted topics should remain hidden unless explicitly re-added.
- Re-added topics with the same id should persist across relaunch.
- Active topic ordering must persist after reorder and deletion.
- Deck progress and section completion should remain stable across launches.
- Topic content stays in local JSON; generation transport goes through the managed backend.

## UX rules
- Keep flows simple and readable for short study sessions.
- Topic detail should preserve context with a premium hero summary and clear section-entry affordances, without changing deck behavior.
- Preserve the library's resume surfaces: continue-learning cards should be powered by existing progress plus lightweight recency state, not new recommendation logic.
- Keep topic management actions discoverable from all library surfaces (including non-list cards), especially delete and completion toggles.
- Keep error text plain-language and actionable.
- Do not add setup friction to core library/deck usage.

## Coding conventions
- Prefer small, testable functions around merge/order logic.
- Keep DTO/model conversion strict and explicit.
- Use deterministic id/title conflict resolution.

## Build/run notes
- Supported platform: iOS.
- Warning policy: treat warnings as errors for all changes.
- Build command:
  - `xcodebuild -project Briefly.xcodeproj -scheme Briefly -destination 'generic/platform=iOS Simulator' clean build`

## Near-term priorities
- Strengthen repository test coverage for content lifecycle flows.
- Improve AI generation resilience and retry ergonomics.
- Expand seed content and in-app pack editing capabilities.

## Output expectations per patch
Provide:
- Summary of change
- Files modified
- Any migration considerations
- Commit message suggestion
