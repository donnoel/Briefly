# ✨ **Briefly**
### *AI-generated study decks, distilled into fast, satisfying flashcards.*

<p align="center">
  <img src="https://img.shields.io/badge/SwiftUI-iOS-orange?logo=swift">
  <img src="https://img.shields.io/badge/Architecture-MVVM%20%2B%20Stores-purple">
  <img src="https://img.shields.io/badge/AI-OpenAI%20API-green?logo=openai">
  <img src="https://img.shields.io/badge/Storage-Keychain%20%2B%20Documents%20JSON-blue">
</p>

---

## ✨ What is Briefly?

**Briefly** is a SwiftUI learning app that helps you create and review *topic packs* made of **sections** and **flashcards**.

You can:
- browse your library of topics,
- jump into a section as a “deck session”,
- reveal answers, then mark cards as **Got it** or **Review again**,
- track progress over time.

If you want new material, Briefly can **generate a full topic pack using the OpenAI API**, then lets you **review/edit it before saving**.

---

## 💎 Core Features

| Feature | Description |
|--------|-------------|
| 🧠 **Topic Packs** | Topics are organized into sections, each containing flashcards (front/back). |
| 🎴 **Deck Sessions** | Review one section at a time with a clean “reveal then rate” flow. |
| ✅ **Progress Tracking** | Remembers learned cards + completed sections and shows progress per topic. |
| 🔁 **Review Loop** | Mark **Got it** to advance, or **Review again** to repeat. |
| 🪄 **AI Topic Generation** | Generate multi-section packs (with card sources/tags) using OpenAI. |
| 🧾 **Review Before Save** | Generated packs open in a review screen so you can refine before saving. |
| ☁️ **iCloud Topic Sync** | User-created topics and topic order sync through your private iCloud database across devices on the same Apple ID, including CloudKit push refresh. |
| 🔎 **Search + Filters** | Search topics and filter by category/difficulty. |
| 🗃️ **Local Persistence** | User-created content persists to disk; API keys stored securely. |

---

## 🎛 How to Use

### Library
- The home screen now opens with a richer library layout:
  - a progress overview
  - a **Continue Learning** carousel driven by in-progress and recently opened topics
  - a **Featured** topic card
  - category-based **Explore Topics** rows
- As you scroll deeper into the library, the oversized top area condenses into a compact contextual header so search/navigation feel anchored.
- Your topics still remain available in **Your Order** and **Completed** sections.
- Active search/filter chips appear near the top and can be cleared individually.
- If filters/search remove all visible topics, Briefly shows a **No matching topics** state with a **Clear filters** action.
- Reorder active topics with drag-and-drop.
- Swipe:
  - **Leading**: mark complete/incomplete
  - **Trailing**: delete

### Topic Detail
- See an immersive topic hero with category, difficulty, section/card counts, and progress.
- The topic hero collapses into a compact pinned header as you scroll.
- Sections are presented as elevated entry cards that keep review actions easy to scan.
- Tap a section to start a deck session.

### Deck Session
- Tap the card (or **See answer**) to reveal the back with a flip animation.
- After revealing:
  - **Got it** marks the card learned and advances
  - **Review again** queues it for another pass
- The section view includes a study header with section/card progress.
- Card height stays stable between cards, with internal scrolling for longer content and a compact stats row for current/remaining/progress.
- When a section finishes, you can restart or continue to the next section.

### AI Generation
- Tap **Generate with AI** (sparkles).
- Choose:
  - topic title/concept
  - difficulty
  - number of sections + cards per section
- Briefly generates in batches with visible progress, then opens a **review screen**.

---

## 🔑 OpenAI API Key

Briefly requires an OpenAI API key to generate content.

- Open **Settings** (gear icon)
- Tap **Manage** under *OpenAI API Key*
- Paste the key and save

**Storage:** the API key is stored securely in the iOS **Keychain**.

---

## 🧠 How it works

Briefly is organized around a few simple layers:

### Navigation
- `AppCoordinator` owns a `NavigationStack` path and routes to:
  - topic detail
  - deck session

### Content
- `ContentRepository` merges:
  - bundled seed packs (`seed_content.json`)
  - user packs stored on disk (`user_content.json`)
- Topics can be reordered and marked completed/deleted.

### Progress
- `ProgressStore` tracks learned card IDs and completed section IDs using `UserDefaults`.
- `RecentTopicsStore` keeps a lightweight recent-topic ID list in `UserDefaults` so the library can surface resume-friendly cards without changing topic content or progress data.

### AI
- `OpenAIClient` performs API requests.
- `AIContentService` generates a `TopicPackDTO`.
- `GeneratedPackReviewView` lets you review/edit before saving.

---

## 📁 Project Structure

```text
Briefly/
├── App/
│   ├── BrieflyApp.swift
│   ├── AppCoordinator.swift
│   └── BrieflyTheme.swift
├── Views/
│   ├── RootView.swift
│   ├── LibraryView.swift
│   ├── TopicDetailView.swift
│   ├── DeckView.swift
│   ├── AIGenerationSheet.swift
│   ├── GeneratedPackReviewView.swift
│   └── SettingsSheet.swift
├── ViewModels/
│   ├── LibraryViewModel.swift
│   ├── TopicDetailViewModel.swift
│   ├── DeckSessionViewModel.swift
│   └── GeneratedPackReviewViewModel.swift
├── Models/
│   ├── TopicModels.swift
│   └── TopicDTOs.swift
├── Services/
│   ├── OpenAIClient.swift
│   ├── AIContentService.swift
│   ├── APIKeyStore.swift
│   ├── KeychainStore.swift
│   └── ModelPreferenceStore.swift
└── Store/
    ├── ContentDiskStore.swift
    ├── ProgressStore.swift
    ├── RecentTopicsStore.swift
    ├── TopicStatusStore.swift
    └── TopicOrderStore.swift
```

---

## 🚀 Getting Started

### Requirements
- Xcode
- iOS Simulator or device
- (Optional) OpenAI API key for AI generation

### Run
1. Open the project in Xcode
2. Select an iOS simulator
3. Build & Run
4. In-app: set your API key in **Settings** if you want AI generation

---

## 🧭 Notes

- If you don’t include `seed_content.json` in the app bundle, the library may start empty until you generate or import content.
- Generated packs are saved locally as JSON in your Documents directory.
- Generated/user topics are synced to iCloud (private CloudKit database) when available.
- Topic completion/deletion state is tracked separately so you can hide seed topics too.

---

## 🗺️ Roadmap (starter)

- [ ] Ship a small bundled seed library (`seed_content.json`)
- [ ] Better “edit pack” tools (bulk edits, section reorder)
- [ ] Spaced repetition scheduling (due dates, intervals)
- [ ] iCloud sync (optional)
- [ ] Home screen widgets

---

## ❤️ Credits

Built by **Don Noel**.

---

> *Briefly is about learning momentum: tiny sessions, clean progress, and the right next card.*
