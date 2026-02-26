# AGENTS.md

This repo is an Apple-platform app codebase. You are an engineering agent (Codex) collaborating with the human. Make small, correct, testable changes with a clean build at every step.

## Hard requirements (do not violate)
- **No build warnings.** Treat warnings as errors in practice.
- **No large rewrites.** Prefer small, surgical diffs.
- **Apple-native only.** No third-party libraries unless explicitly requested.
- **SwiftUI + MVVM + Stores.** Keep UI declarative; keep business logic in view models/services/stores.
- **Concurrency correctness.** Keep UI state on `@MainActor`; keep disk/network work off the main thread unless required.
- **Persistence must be safe.** Use deterministic data models and atomic writes where appropriate.
- **Privacy-first.** No unexpected network calls beyond explicit OpenAI feature usage.
- **Preserve user flows.** Do not regress topic browsing, deck review, AI generation, or settings flows.

## Workflow
1. Read existing code and architecture before editing.
2. Propose a minimal plan in 2-5 bullets.
3. Implement the smallest viable patch.
4. Ensure build passes with **zero warnings**.
5. If tests exist or are touched, run them. Add tests for non-trivial logic.
6. If behavior changed, update docs (`README.md` / `AGENTS.project.md`) in the same patch.

## Code style
- Keep types focused and composable.
- Prefer `Foundation` and structured error handling over ad-hoc `print` diagnostics.
- Use small services for disk/network boundaries.
- Prefer `@MainActor` for SwiftUI-facing view models/stores; avoid unnecessary actor broadening.
- Keep shared state predictable; avoid introducing new global singletons.

## Deliverables for each change
- Mention which files were modified and why.
- Provide a short commit message suggestion.
- Mention any user-visible behavior changes explicitly.

## What not to do
- Don't introduce new dependencies.
- Don't suppress warnings to "make it pass".
- Don't change behavior silently.
- Don't hide errors; surface actionable, user-friendly failure messages.

If something is ambiguous, default to the simplest solution that preserves correctness and forward progress.
