import SwiftUI

struct TopicDetailView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: TopicDetailViewModel
    let topicTransition: Namespace.ID

    @State private var compactHeaderVisible = false

    private var style: BrieflyTheme.TopicVisualStyle {
        BrieflyTheme.Colors.topicStyle(for: viewModel.topic.category)
    }

    private var totalCardCount: Int {
        viewModel.topic.sections.reduce(0) { $0 + $1.cards.count }
    }

    private var progressFraction: Double {
        viewModel.progressFraction()
    }

    private var progressPercent: Int {
        Int((progressFraction * 100).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroHeader

                if !viewModel.sections.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionLabel

                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.sections) { section in
                                sectionCard(section)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .coordinateSpace(name: "topicDetailScroll")
        .background(topicBackground)
        .onPreferenceChange(TopicHeroOffsetKey.self) { minY in
            let shouldShowCompactHeader = minY < -120
            if shouldShowCompactHeader != compactHeaderVisible {
                compactHeaderVisible = shouldShowCompactHeader
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(compactHeaderVisible ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                compactTopicHeader
            }
        }
        .navigationTransition(.zoom(sourceID: viewModel.topic.id, in: topicTransition))
    }

    private var heroHeader: some View {
        ZStack(alignment: .topTrailing) {
            heroBackground
            heroSymbol

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    categoryChip

                    Spacer(minLength: 12)

                    difficultyChip
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.topic.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.98))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(viewModel.topic.subtitle)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    heroStat(title: "\(viewModel.sections.count) sections", icon: "square.grid.2x2")
                    heroStat(title: "\(totalCardCount) cards", icon: "rectangle.stack.fill")
                    heroStat(title: progressFraction > 0 ? "\(progressPercent)% learned" : "Fresh topic", icon: "chart.bar.fill")
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(progressFraction > 0 ? "Progress" : "Ready to Begin")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.96))

                        Spacer()

                        Text(progressFraction > 0 ? viewModel.progressText() : "Start with any section")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.82))
                    }

                    ProgressView(value: progressFraction)
                        .progressViewStyle(.linear)
                        .tint(.white.opacity(0.95))
                        .background(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18))
                        .clipShape(Capsule())
                }
                .padding(.top, 6)
            }
            .padding(24)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: TopicHeroOffsetKey.self,
                        value: geometry.frame(in: .named("topicDetailScroll")).minY
                    )
            }
        )
        .padding(.horizontal, 16)
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(style.gradient(for: colorScheme, emphasized: true))
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.clear,
                        Color.black.opacity(colorScheme == .dark ? 0.22 : 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.34 : 0.24))
                    .frame(width: 260, height: 260)
                    .blur(radius: 30)
                    .offset(x: -42, y: -60)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(style.ambient(for: colorScheme).opacity(colorScheme == .dark ? 0.34 : 0.24))
                    .frame(width: 220, height: 220)
                    .blur(radius: 36)
                    .offset(x: 48, y: 70)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12))
            )
            .shadow(color: style.glow(for: colorScheme), radius: 24, x: 0, y: 16)
            .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme), radius: 22, x: 0, y: 14)
    }

    private var heroSymbol: some View {
        ZStack {
            Circle()
                .fill(style.ambient(for: colorScheme).opacity(0.28))
                .frame(width: 260, height: 260)
                .blur(radius: 26)

            Image(systemName: style.symbolName)
                .font(.system(size: 118, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            style.highlight(for: colorScheme).opacity(0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.18)
        }
        .padding(.top, -28)
        .padding(.trailing, -30)
        .allowsHitTesting(false)
    }

    private var categoryChip: some View {
        Label(viewModel.topic.category, systemImage: style.symbolName)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white.opacity(0.98))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.24 : 0.20))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14))
                    )
            )
    }

    private var difficultyChip: some View {
        Label(viewModel.topic.difficulty.rawValue, systemImage: "dial.medium")
            .font(.caption.weight(.semibold))
            .foregroundColor(.white.opacity(0.94))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12))
                    )
            )
    }

    private var sectionLabel: some View {
        HStack {
            Text("Sections")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(BrieflyTheme.Colors.textPrimary)

            Spacer()

            Text("\(viewModel.sections.count)")
                .font(.caption.weight(.semibold))
                .foregroundColor(BrieflyTheme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(BrieflyTheme.Colors.elevatedBackground(colorScheme))
                )
        }
    }

    private func sectionCard(_ section: TopicSection) -> some View {
        let completed = viewModel.isSectionCompleted(section)

        return Button {
            coordinator.showDeck(for: viewModel.topic, section: section)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(section.title)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(BrieflyTheme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)

                        if completed {
                            statusChip(title: "Completed", color: .green)
                        }
                    }

                    HStack(spacing: 8) {
                        sectionStat(title: "\(section.cards.count) cards", icon: "rectangle.stack.fill")
                        sectionStat(title: completed ? "Review again" : "Ready to study", icon: completed ? "arrow.clockwise" : "play.fill")
                    }
                }

                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    if completed {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(style.tint(for: colorScheme))
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(BrieflyTheme.Colors.textSecondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sectionCardBackground(completed: completed))
        }
        .buttonStyle(InteractiveCardButtonStyle())
        .accessibilityIdentifier("topic.section.card")
    }

    private func sectionCardBackground(completed: Bool) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BrieflyTheme.Colors.cardBackground(colorScheme),
                        style.ambient(for: colorScheme).opacity(completed ? (colorScheme == .dark ? 0.16 : 0.12) : (colorScheme == .dark ? 0.12 : 0.08))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(style.highlight(for: colorScheme).opacity(completed ? 0.18 : 0.10))
                    .frame(width: 96, height: 96)
                    .blur(radius: 16)
                    .offset(x: 18, y: -18)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(BrieflyTheme.Colors.cardStroke(colorScheme))
            )
            .shadow(color: BrieflyTheme.Colors.shadowSoft(colorScheme), radius: 10, x: 0, y: 6)
    }

    private func heroStat(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.white.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.08 : 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08))
                )
        )
    }

    private func sectionStat(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))

            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(BrieflyTheme.Colors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BrieflyTheme.Colors.elevatedBackground(colorScheme))
        )
    }

    private func statusChip(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(colorScheme == .dark ? 0.18 : 0.12))
            )
    }

    private var compactTopicHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(style.ambient(for: colorScheme))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.topic.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(BrieflyTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(progressFraction > 0 ? viewModel.progressText() : "\(viewModel.sections.count) sections")
                    .font(.caption2)
                    .foregroundColor(BrieflyTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .opacity(compactHeaderVisible ? 1 : 0)
        .scaleEffect(compactHeaderVisible ? 1 : 0.96)
        .animation(.easeInOut(duration: 0.2), value: compactHeaderVisible)
        .accessibilityHidden(!compactHeaderVisible)
    }

    private var topicBackground: some View {
        ZStack {
            BrieflyTheme.Colors.background(colorScheme)

            RadialGradient(
                colors: [
                    style.ambient(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.10),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )
            .offset(x: 56, y: -30)

            LinearGradient(
                colors: [
                    style.highlight(for: colorScheme).opacity(colorScheme == .dark ? 0.06 : 0.08),
                    .clear,
                    BrieflyTheme.Colors.background(colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct TopicHeroOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
