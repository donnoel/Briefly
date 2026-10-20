# **Briefly**

### *AI-generated study decks, distilled into fast, satisfying flashcards.*

<p align="center">
  <img src="https://img.shields.io/badge/SwiftUI-iOS-orange?logo=swift" alt="SwiftUI: iOS">
  <img src="https://img.shields.io/badge/Architecture-MVVM%20%2B%20Stores-purple" alt="Architecture: MVVM + Stores">
  <img src="https://img.shields.io/badge/AI-Backend%20Generation-green" alt="AI: Backend Generation">
  <img src="https://img.shields.io/badge/Storage-Documents%20JSON%20%2B%20iCloud-blue" alt="Storage: Documents JSON + iCloud">
  <img src="https://img.shields.io/badge/Platforms-iOS%20%2B%20iPadOS-blue" alt="Platforms: iOS + iPadOS">
  <img src="https://img.shields.io/badge/Repository-Archived-lightgrey?logo=github&logoColor=white" alt="Repository: Archived">
</p>

> **Archived on GitHub.** The implementation and development notes below describe the retained project.

---

## 🧭 Overview

<a id="-what-is-briefly"></a>
<a id="what-is-briefly"></a>

**Briefly** is a SwiftUI learning app that helps you create and review *topic packs* made of **sections** and **flashcards**.

You can:
- browse your library of topics,
- jump into a section as a “deck session”,
- reveal answers, then mark cards as **Next** (or **Finish section** on the last card) or **Review again**,
- track progress over time.

If you want new material, Briefly can **generate a full topic pack through Briefly's backend**, then lets you **review/edit it before saving**.

## 💎 Core Features

| Feature | What it does |
| --- | --- |
| **Topic library** | Browse topic packs organized into sections and flashcards. |
| **Study sessions** | Review focused decks and track learning progress. |
| **Content generation** | Use the documented backend generation flow. |
| **Saved progress** | Resume study from the app's stored topic and progress data. |

<details>
<summary>Feature details and controls</summary>

<a id="-core-features"></a>
<a id="core-features"></a>

| Feature | Description |
|--------|-------------|
| 🧠 **Topic Packs** | Topics are organized into sections, each containing flashcards (front/back). |
| 🎴 **Deck Sessions** | Review one section at a time with a clean “reveal then rate” flow. |
| ✅ **Progress Tracking** | Remembers learned cards + completed sections and shows progress per topic. |
| 🔁 **Review Loop** | Mark **Next** to advance (or **Finish section** on the last card), or **Review again** to repeat. |
| 🪄 **AI Topic Generation** | Generate multi-section packs (with card sources/tags) through Briefly's backend generation service. |
| 🧾 **Review Before Save** | Generated packs open in a review screen so you can refine before saving. |
| ☁️ **iCloud Topic Sync** | User-created topics and topic order sync through your private iCloud database across devices on the same Apple ID, including CloudKit push refresh. |
| 🔎 **Search + Filters** | Search topics and filter by category/difficulty. |
| 🗃️ **Local Persistence** | User-created content persists to disk and syncs through iCloud when available. |

<a id="-how-to-use"></a>
<a id="how-to-use"></a>

### How to Use

#### Library
- The home screen now opens with a richer library layout:
  - a progress overview
  - a **Continue Learning** carousel driven by in-progress and recently opened topics
  - a **Featured** topic card
  - category-based **Explore Topics** rows
- As you scroll deeper into the library, the oversized top area condenses into a compact contextual header so search/navigation feel anchored.
- Your topics still remain available in **Your Order** and **Completed** sections.
- Active search/filter chips appear near the top and can be cleared individually.
- If filters/search remove all visible topics, Briefly shows a **No matching topics** state with a **Clear filters** action.
- On launch, Briefly waits for persisted topic data before showing empty-library prompts so transient “Generate with AI” empty states do not flash.
- Reorder active topics with drag-and-drop.
- Swipe:
  - **Leading**: mark complete/incomplete
  - **Trailing**: delete

#### Topic Detail
- See an immersive topic hero with category, difficulty, section/card counts, and progress.
- The topic hero collapses into a compact pinned header as you scroll.
- Sections are presented as elevated entry cards that keep review actions easy to scan.
- Tap a section to start a deck session.

#### Deck Session
- Tap the card (or **See answer**) to reveal the back with a flip animation.
- After revealing:
  - **Next** marks the card learned and advances (becomes **Finish section** on the final card)
  - **Review again** queues it for another pass
- The section view includes a study header with section/card progress.
- Card height stays stable between cards, with internal scrolling for longer content and a compact stats row for current/remaining/progress.
- When a section finishes, you can restart or continue to the next section.

#### AI Generation
- Tap **Generate with AI** (sparkles).
- Choose:
  - topic title/concept
  - difficulty
  - number of sections + cards per section
- Briefly generates in batches with visible progress, then opens a **review screen**.

</details>

---

## 🚀 Getting Started

<a id="-ai-generation-access"></a>
<a id="ai-generation-access"></a>

### AI Generation Access

Briefly no longer requires a user-provided OpenAI API key for generation.

- Open **Settings** (gear icon) to confirm backend generation status.
- App version/build is shown in iOS Settings for Briefly under **Version**.

<a id="-getting-started"></a>
<a id="getting-started"></a>

### Requirements
- Xcode with the iOS 26.1 SDK or newer
- iOS Simulator or device

### Run
1. Open the project in Xcode
2. Select an iOS simulator
3. Build & Run

## 🧠 How It Works

<a id="-how-it-works"></a>
<a id="how-it-works"></a>

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
- `BrieflyBackendClient` performs backend generation requests.
- `AIContentService` generates a `TopicPackDTO`.
- `GeneratedPackReviewView` lets you review/edit before saving.

<a id="-project-structure"></a>
<a id="project-structure"></a>

### Project Structure

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
│   ├── BrieflyBackendClient.swift
│   ├── AIContentService.swift
│   ├── OpenAIClient.swift
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

## 🔒 Data and Privacy

<a id="-notes"></a>
<a id="notes"></a>

### Notes

- If you don’t include `seed_content.json` in the app bundle, the library may start empty until you generate or import content.
- Generated packs are saved locally as JSON in your Documents directory.
- Generated/user topics are synced to iCloud (private CloudKit database) when available.
- Topic completion/deletion state is tracked separately so you can hide seed topics too.

## 📚 Documentation

- [Repository guidance](AGENTS.md)
- [Project guide](AGENTS.project.md)

## 🗺️ Roadmap

<a id="-roadmap-starter"></a>
<a id="roadmap-starter"></a>

- [ ] Ship a small bundled seed library (`seed_content.json`)
- [ ] Better “edit pack” tools (bulk edits, section reorder)
- [ ] Spaced repetition scheduling (due dates, intervals)
- [x] Private CloudKit topic and topic-order synchronization
- [ ] Home screen widgets

---

## 🤝 Credits

<a id="credits"></a>

Built with care by **Don Noel** and Codex collaboration.

> *Briefly is about learning momentum: tiny sessions, clean progress, and the right next card.*
