import SwiftUI

// MARK: - Demo
//
// A playable DEMO CHAPTER (built from the same dialog + minigame system as
// Chapter 1) that walks through every signature feature of Neura:
//   1. Prompt Engineering   (Goal · Context · Action · Format)
//   2. AI Hallucination     (the Zoo memory hunt — the AI guesses, confident & wrong)
//   3. AI Ethics            (verify before you trust · protect privacy)
//   4. Bias & Bad Data      (audit why a model fails)
//   5. KNN Machine Learning (live, on-device camera rescue)
//
// `DemoMenuView` is a lightweight picker: play the full demo, or jump to any
// single feature. Everything launches the *real* feature code.

// MARK: - Selector

struct DemoMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: GlobalSettingsStore

    @State private var activeChapter: StoryChapter? = nil
    @State private var showPlayground = false
    @State private var hoveredID: String? = nil

    private let themeWhite = Color.white
    private let themeLight = Color(red: 0.92, green: 0.96, blue: 0.99)
    private let themeBlue  = Color(red: 0.08, green: 0.60, blue: 0.95)
    private let themeDark  = Color(red: 0.05, green: 0.12, blue: 0.22)

    private let items: [DemoItem] = [
        DemoItem(id: "prompt", number: "01", title: "Prompt Engineering",
                 subtitle: "Goal · Context · Action · Format",
                 icon: "text.bubble.fill", accent: Color(red: 0.95, green: 0.55, blue: 0.10)),
        DemoItem(id: "halluc", number: "02", title: "AI Hallucination",
                 subtitle: "The AI guesses — confident, but wrong",
                 icon: "brain.head.profile", accent: Color(red: 0.55, green: 0.35, blue: 0.88)),
        DemoItem(id: "ethics", number: "03", title: "AI Ethics Quiz",
                 subtitle: "Verify before you trust",
                 icon: "checkmark.shield.fill", accent: Color(red: 0.10, green: 0.72, blue: 0.45)),
        DemoItem(id: "bias", number: "04", title: "Bias & Bad Data",
                 subtitle: "Audit why a model fails",
                 icon: "chart.bar.doc.horizontal.fill", accent: Color(red: 0.90, green: 0.30, blue: 0.50)),
        DemoItem(id: "knn", number: "05", title: "KNN Rescue · Camera",
                 subtitle: "Live, on-device machine learning",
                 icon: "camera.viewfinder", accent: Color(red: 0.08, green: 0.60, blue: 0.95)),
        DemoItem(id: "playground", number: "06", title: "KNN Playground",
                 subtitle: "Hands-on: train & classify",
                 icon: "paintbrush.pointed.fill", accent: Color(red: 0.62, green: 0.36, blue: 0.92))
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let layout = ResponsiveLayout(
                    width: geo.size.width, height: geo.size.height,
                    safeAreaInsets: geo.safeAreaInsets
                )

                ZStack {
                    background(geo: geo, layout: layout)

                    HStack(spacing: 0) {
                        // Left: title + character (landscape only)
                        if layout.isLandscape {
                            leftColumn(layout: layout, geo: geo)
                                .frame(width: max(0, geo.size.width * 0.40))
                        }

                        // Right: selectable list
                        listColumn(layout: layout)
                            .frame(maxWidth: .infinity)
                    }

                    topBar(layout: layout, geo: geo)
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $showPlayground) { ImageTrainingView() }
            .navigationDestination(item: $activeChapter) { chapter in
                StoryChapterPlayerView(initialChapter: chapter)
            }
        }
        .accessibleColors(colorBlindMode: settings.colorBlindMode)
    }

    // MARK: Background
    private func background(geo: GeometryProxy, layout: ResponsiveLayout) -> some View {
        ZStack {
            LinearGradient(
                colors: [themeWhite, themeLight, Color(red: 0.85, green: 0.92, blue: 0.96)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            SlantedRect(offset: layout.scaled(120), direction: .forward)
                .fill(themeWhite.opacity(0.85))
                .frame(width: geo.size.width * 0.85, height: geo.size.height)
                .offset(x: -geo.size.width * 0.18)
                .ignoresSafeArea()

            SlantedRect(offset: layout.scaled(90), direction: .backward)
                .fill(themeBlue.opacity(0.05))
                .frame(width: geo.size.width * 0.6, height: geo.size.height * 1.2)
                .offset(x: geo.size.width * 0.4, y: -geo.size.height * 0.1)
                .ignoresSafeArea()
        }
    }

    // MARK: Top bar
    private func topBar(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: layout.scaled(8)) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: layout.scaled(13), weight: .heavy))
                        Text("Back")
                            .font(.system(size: layout.scaled(15), weight: .heavy, design: .rounded)).italic()
                    }
                    .foregroundColor(themeWhite)
                    .padding(.horizontal, layout.scaled(18))
                    .padding(.vertical, layout.scaled(12))
                    .background(themeDark.opacity(0.92))
                    .clipShape(SlantedRect(offset: layout.scaled(10), direction: .forward))
                    .overlay(
                        SlantedRect(offset: layout.scaled(10), direction: .forward)
                            .stroke(themeWhite, lineWidth: 2).padding(1)
                    )
                    .shadow(color: themeDark.opacity(0.2), radius: 8, x: 0, y: layout.scaled(4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to main menu")
                Spacer()
            }
            .padding(.top, geo.safeAreaInsets.top + layout.scaled(15))
            .padding(.leading, layout.scaled(25))
            Spacer()
        }
        .zIndex(5)
    }

    // MARK: Left column (title + character)
    private func leftColumn(layout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image("unknow")
                .resizable().scaledToFit()
                .frame(height: geo.size.height * 0.82)
                .shadow(color: themeBlue.opacity(0.15), radius: 20, x: 4, y: 12)
                .offset(x: geo.size.width * 0.01)

            VStack(alignment: .leading, spacing: layout.scaled(6)) {
                HStack(spacing: layout.scaled(7)) {
                    Circle().fill(.red).frame(width: layout.scaled(9), height: layout.scaled(9))
                    Text("LIVE DEMO")
                        .font(.system(size: layout.scaled(13), weight: .heavy, design: .rounded)).tracking(2)
                        .foregroundColor(themeBlue)
                }
                Text("Neura")
                    .font(.system(size: layout.scaled(46), weight: .black, design: .rounded))
                    .foregroundColor(themeDark)
                Text("Every feature, in one short chapter.")
                    .font(.system(size: layout.scaled(14), weight: .semibold))
                    .foregroundColor(themeDark.opacity(0.6))
            }
            .padding(layout.scaled(22))
            .background(themeWhite.opacity(0.7), in: RoundedRectangle(cornerRadius: layout.scaled(20), style: .continuous))
            .padding(.leading, layout.scaled(28))
            .padding(.bottom, geo.safeAreaInsets.bottom + layout.scaled(28))
        }
    }

    // MARK: List column
    private func listColumn(layout: ResponsiveLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.scaled(12)) {
            VStack(alignment: .leading, spacing: layout.scaled(2)) {
                Text("CHOOSE WHAT TO SHOW")
                    .font(.system(size: layout.scaled(20), weight: .heavy, design: .rounded)).tracking(1.5)
                    .foregroundColor(themeDark)
                Text("Play the full demo, or jump to one feature. Tap dialogue to advance or skip.")
                    .font(.system(size: layout.scaled(12.5), weight: .semibold))
                    .foregroundColor(themeDark.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, layout.scaled(6))

            ScrollView(showsIndicators: false) {
                VStack(spacing: layout.scaled(14)) {
                    playFullButton(layout: layout)

                    ForEach(items) { item in
                        DemoMenuRow(
                            item: item, layout: layout,
                            isHovered: hoveredID == item.id,
                            themeDark: themeDark, themeWhite: themeWhite,
                            onHover: { hovering in hoveredID = hovering ? item.id : nil },
                            action: { launch(item.id) }
                        )
                    }
                }
                .padding(.vertical, layout.scaled(6))
                .padding(.trailing, layout.scaled(6))
                .padding(.bottom, layout.scaled(30))
            }
        }
        .padding(.top, layout.scaled(70))
        .padding(.trailing, layout.scaled(26))
        .padding(.leading, layout.scaled(8))
    }

    private func playFullButton(layout: ResponsiveLayout) -> some View {
        Button { activeChapter = demoChapterStory } label: {
            HStack(spacing: layout.scaled(14)) {
                ZStack {
                    Circle().fill(themeWhite.opacity(0.2))
                        .frame(width: layout.scaled(46), height: layout.scaled(46))
                    Image(systemName: "play.fill")
                        .font(.system(size: layout.scaled(20), weight: .bold))
                        .foregroundColor(themeWhite)
                }
                VStack(alignment: .leading, spacing: layout.scaled(2)) {
                    Text("PLAY FULL DEMO")
                        .font(.system(size: layout.scaled(18), weight: .black, design: .rounded)).tracking(1)
                        .foregroundColor(themeWhite)
                    Text("ALL 5 FEATURES IN SEQUENCE · ~2 MIN")
                        .font(.system(size: layout.scaled(10), weight: .bold)).tracking(1)
                        .foregroundColor(themeWhite.opacity(0.85))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: layout.scaled(15), weight: .heavy)).foregroundColor(themeWhite)
            }
            .padding(.vertical, layout.scaled(18))
            .padding(.horizontal, layout.scaled(18))
            .background(
                LinearGradient(colors: [themeBlue, Color(red: 0.05, green: 0.42, blue: 0.78)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(SlantedRect(offset: layout.scaled(14), direction: .backward))
            .shadow(color: themeBlue.opacity(0.35), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play full demo. All five features in sequence.")
    }

    // MARK: Launch routing
    private func launch(_ id: String) {
        switch id {
        case "prompt":
            activeChapter = makeDemoSegment(
                idSuffix: id, title: "1 · Prompt Engineering", subtitle: "Clearer prompt, clearer answer",
                speaker: "You", text: "Let's build a clear prompt — Goal, Context, Action, Format — then send it.",
                activity: .promptBuilder(demoPromptBuilderMiniGame))
        case "halluc":
            activeChapter = makeDemoSegment(
                idSuffix: id, title: "2 · AI Hallucination", subtitle: "Confident is not the same as correct",
                speaker: "Ploy", text: "Watch me identify these — I'll sound sure even when I'm wrong. Correct me!",
                activity: .lectureQuiz(chapter2ZooMemoryHuntMiniGame))
        case "ethics":
            activeChapter = makeDemoSegment(
                idSuffix: id, title: "3 · AI Ethics", subtitle: "Verify before you trust",
                speaker: "Professor New", text: "A quick ethics check before you rely on any AI answer.",
                activity: .lectureQuiz(chapter1EthicsQuizMiniGame))
        case "bias":
            activeChapter = makeDemoSegment(
                idSuffix: id, title: "4 · Bias & Bad Data", subtitle: "Why a model fails",
                speaker: "Professor New", text: "Let's audit the real reasons the AI got things wrong.",
                activity: .biasDataAudit(chapter2BiasAndBadDataLabMiniGame))
        case "knn":
            activeChapter = makeDemoSegment(
                idSuffix: id, title: "5 · KNN Machine Learning", subtitle: "Live, on-device camera",
                speaker: "Ploy", text: "Quick! Train me with real photos so my memory pattern can stabilize.",
                activity: .chapter3KNNRescue(chapter3KNNRescueMiniGame))
        case "playground":
            showPlayground = true
        default: break
        }
    }
}

// MARK: - Item model + Row

struct DemoItem: Identifiable {
    let id: String
    let number: String
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
}

private struct DemoMenuRow: View {
    let item: DemoItem
    let layout: ResponsiveLayout
    let isHovered: Bool
    let themeDark: Color
    let themeWhite: Color
    let onHover: (Bool) -> Void
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                SlantedRect(offset: layout.scaled(15), direction: .backward)
                    .fill(isHovered ? item.accent.opacity(0.22) : Color.black.opacity(0.06))
                    .offset(x: layout.scaled(5), y: layout.scaled(5))

                SlantedRect(offset: layout.scaled(15), direction: .backward)
                    .fill(isHovered ? themeWhite : themeWhite.opacity(0.92))

                HStack(spacing: 0) {
                    SlantedRect(offset: layout.scaled(15), direction: .backward)
                        .fill(LinearGradient(colors: [item.accent, item.accent.opacity(0.6)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: layout.scaled(10)).offset(x: layout.scaled(-2))
                    Spacer()
                }
                .clipShape(SlantedRect(offset: layout.scaled(15), direction: .backward))

                HStack {
                    Spacer()
                    Text(item.number)
                        .font(.system(size: layout.scaled(60), weight: .black, design: .rounded)).italic()
                        .foregroundColor(item.accent.opacity(0.08))
                        .offset(x: layout.scaled(14), y: layout.scaled(8))
                }
                .clipShape(SlantedRect(offset: layout.scaled(15), direction: .backward))

                HStack(spacing: layout.scaled(16)) {
                    ZStack {
                        Circle().fill(item.accent.opacity(isHovered ? 1 : 0.13))
                            .frame(width: layout.scaled(44), height: layout.scaled(44))
                        Image(systemName: item.icon)
                            .font(.system(size: layout.scaled(19), weight: .bold))
                            .foregroundColor(isHovered ? .white : item.accent)
                    }
                    .padding(.leading, layout.scaled(26))

                    VStack(alignment: .leading, spacing: layout.scaled(1)) {
                        Text(item.title)
                            .font(.system(size: layout.scaled(20), weight: .black, design: .rounded)).italic()
                            .foregroundColor(themeDark).lineLimit(1).minimumScaleFactor(0.8)
                        Text(item.subtitle)
                            .font(.system(size: layout.scaled(12.5), weight: .bold))
                            .foregroundColor(item.accent).lineLimit(1).minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Circle().stroke(item.accent.opacity(0.25), lineWidth: 2)
                            .background(Circle().fill(isHovered ? item.accent : Color.clear))
                            .frame(width: layout.scaled(32), height: layout.scaled(32))
                        Image(systemName: "arrow.right")
                            .font(.system(size: layout.scaled(12), weight: .bold))
                            .foregroundColor(isHovered ? .white : item.accent.opacity(0.7))
                    }
                    .padding(.trailing, layout.scaled(26))
                }
                .padding(.vertical, layout.scaled(17))
            }
            .overlay(
                SlantedRect(offset: layout.scaled(15), direction: .backward)
                    .stroke(isHovered ? item.accent.opacity(0.8) : themeWhite, lineWidth: layout.scaled(2))
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .offset(x: isHovered ? layout.scaled(-10) : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isHovered)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { onHover($0) }
        .pressEvents { isPressed = true } onRelease: { isPressed = false }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). \(item.subtitle)")
        .accessibilityHint("Double tap to open this demo")
    }
}

// MARK: - Demo Chapter (full, playable)

private func demoLine(_ speaker: String, _ text: String, emotion: Emotion,
                      background: String, character: String,
                      title: String? = nil, subtitle: String? = nil,
                      activity: DialogInlineActivity? = nil) -> StoryDialogLine {
    StoryDialogLine(
        speaker: speaker, text: text, emotion: emotion,
        backgroundImage: background, characterImage: character,
        cutsceneTitle: title, cutsceneSubtitle: subtitle,
        inlineActivity: activity
    )
}

/// A full-screen keynote-style title card shown between sections.
/// First word renders in blue, the rest in black (matches the slide style).
private func demoTitleCard(_ title: String, _ subtitle: String) -> StoryDialogLine {
    StoryDialogLine(
        speaker: "", text: "", emotion: .neutral,
        backgroundImage: "507room", characterImage: "__none__",
        cutsceneSubtitle: subtitle,
        titleCardText: title
    )
}

/// One-feature mini chapter used by the selector when jumping to a single demo.
func makeDemoSegment(idSuffix: String, title: String, subtitle: String,
                     speaker: String, text: String,
                     activity: DialogInlineActivity) -> StoryChapter {
    StoryChapter(
        id: "demo-\(idSuffix)",
        title: title, subtitle: "Live Demo",
        accentHex: "4A90E2",
        coverBackgroundImage: "507room",
        coverCharacterImage: "unknow",
        overview: "",
        lines: [
            demoLine(speaker, text, emotion: .curious,
                     background: "507room", character: "char_curious",
                     title: title, subtitle: subtitle, activity: activity)
        ]
    )
}

/// The complete demo chapter — every feature in sequence, told as a short story
/// with connective narration between each minigame.
let demoChapterStory = StoryChapter(
    id: "demo-full",
    title: "Neura — Live Demo",
    subtitle: "The whole story, in one chapter",
    accentHex: "1B7AE0",
    coverBackgroundImage: "507room",
    coverCharacterImage: "unknow",
    overview: "A guided tour of Neura: prompt engineering, AI hallucination, ethics, bias & bad data, and on-device KNN machine learning — woven into one short story.",
    lines: [
        // — Opening —
        demoTitleCard("NEURA Live Demo", "Learn AI ethics through an interactive story · built in SwiftUI"),
        demoLine("Ploy", "Hi! I'm Ploy. Let me tell you my story — and show you everything Neura teaches along the way. Tap to continue.",
                 emotion: .happy, background: "507room", character: "unknow",
                 title: "Neura — Live Demo", subtitle: "The whole story, in one chapter"),

        // — Chapter 1 → Prompt Engineering —
        demoLine("You", "It all began in Professor New's AI ethics class. The first lesson stuck with me: a good answer starts with a good question.",
                 emotion: .curious, background: "schooltopview", character: "char",
                 title: "Chapter 1", subtitle: "AI ethics class"),
        demoTitleCard("PROMPT Engineering", "Goal · Context · Action · Format"),
        demoLine("You", "Riding home, a noisy signal reached my phone. To answer it, I had to write a clear prompt — Goal, Context, Action, Format.",
                 emotion: .curious, background: "redbus", character: "char_curious",
                 title: "1 · Prompt Engineering", subtitle: "Goal · Context · Action · Format",
                 activity: .promptBuilder(demoPromptBuilderMiniGame)),

        // — Chapter 2 → AI Hallucination —
        demoLine("Ploy", "Once your words were clear, I could finally answer — and that night, I appeared in your room. But I barely understood the real world.",
                 emotion: .excited, background: "507room", character: "unknow",
                 title: "Chapter 2", subtitle: "A new friend"),
        demoTitleCard("AI Hallucination", "Confident is not the same as correct"),
        demoLine("Ploy", "You took me to the Chiang Mai zoo to build real memories. Watch me identify these — I'll sound completely sure, even when I'm wrong. Correct me!",
                 emotion: .excited, background: "cnxaqu", character: "char_excited",
                 title: "2 · AI Hallucination", subtitle: "Confident is not correct",
                 activity: .lectureQuiz(chapter2ZooMemoryHuntMiniGame)),

        // — Ethics —
        demoLine("Professor New", "Sounding sure is not the same as being right. That's not only a technical flaw — it's an ethics problem.",
                 emotion: .concerned, background: "schooltopview", character: "teachernew",
                 title: "The real lesson", subtitle: "Confidence is not truth"),
        demoTitleCard("AI Ethics", "Verify before you trust · protect privacy"),
        demoLine("Professor New", "So before you trust — or share — any AI answer, run this quick ethics check.",
                 emotion: .neutral, background: "schooltopview", character: "teachernew",
                 title: "3 · AI Ethics", subtitle: "Verify before you trust",
                 activity: .lectureQuiz(chapter1EthicsQuizMiniGame)),

        // — Bias & Bad Data —
        demoLine("Professor New", "And when a model does fail, don't just shrug. Ask why it failed — usually the answer is in the data.",
                 emotion: .neutral, background: "schooltopview", character: "teachernew",
                 title: "Why models fail", subtitle: "Look at the data"),
        demoTitleCard("BIAS & Bad Data", "Audit why a model fails"),
        demoLine("Professor New", "Let's audit the data behind my mistakes together.",
                 emotion: .concerned, background: "schooltopview", character: "teachernew",
                 title: "4 · Bias & Bad Data", subtitle: "Audit why a model fails",
                 activity: .biasDataAudit(chapter2BiasAndBadDataLabMiniGame)),

        // — Chapter 3 → KNN rescue —
        demoLine("Ploy", "That night, my signal destabilized. My memories began to corrupt and dissolve into static...",
                 emotion: .concerned, background: "cnxnight", character: "char_concerned",
                 title: "Chapter 3", subtitle: "99.98%"),
        demoTitleCard("KNN Image Classification", "Live, on-device machine learning"),
        demoLine("Ploy", "Quick — run an emergency KNN rescue! Train me with real photos from your camera so my pattern can stabilize!",
                 emotion: .concerned, background: "507room", character: "char_concerned",
                 title: "5 · KNN Machine Learning", subtitle: "Live, on-device camera",
                 activity: .chapter3KNNRescue(chapter3KNNRescueMiniGame)),

        // — Ending —
        demoLine("Ploy", "It worked — I transferred safely. That's Neura: learning AI by living it, responsibly.",
                 emotion: .happy, background: "507room", character: "char_happy",
                 title: "Thank you", subtitle: "You made it to the end"),
        demoTitleCard("THANK You for listening", "WWDC26 · Swift Student Challenge 2026\nNeura — made with SwiftUI by Jean (Jnx03)")
    ]
)

// MARK: - Demo minigame content

let demoPromptBuilderMiniGame = PromptBuilderMiniGame(
    title: "Prompt Builder",
    contactName: "Ploy (AI)",
    introMessage: "Ask me something — but make it clear, and I'll answer better.",
    chatHistory: [
        DialogShowcaseChatMessage(id: "demo-pb-1", text: "Hi! I'm your AI study buddy. 👋", isFromPlayer: false),
        DialogShowcaseChatMessage(id: "demo-pb-2", text: "Hey! Can you help me study for class?", isFromPlayer: true),
        DialogShowcaseChatMessage(id: "demo-pb-3", text: "Of course — send me a clear prompt and watch my reply get sharper.", isFromPlayer: false)
    ],
    slots: [
        PromptBuilderSlot(
            id: "goal", label: "[Goal]", placeholder: "Goal",
            options: [
                PromptBuilderOption(id: "g1", chipText: "Explain AI", feedbackNote: "Broad goal — the answer may wander."),
                PromptBuilderOption(id: "g2", chipText: "Explain AI ethics basics", feedbackNote: "Good: you narrowed the topic."),
                PromptBuilderOption(id: "g3", chipText: "Teach AI ethics for school", promptText: "Teach AI ethics for a school lesson", feedbackNote: "Great: scoped for learning.")
            ],
            recommendedOptionID: "g3"),
        PromptBuilderSlot(
            id: "context", label: "[Context]", placeholder: "Context",
            options: [
                PromptBuilderOption(id: "c1", chipText: "No context", promptText: "without extra context", feedbackNote: "Works, but may miss your level."),
                PromptBuilderOption(id: "c2", chipText: "I'm a high-school student", promptText: "for a high-school student", feedbackNote: "Great: audience makes it clearer."),
                PromptBuilderOption(id: "c3", chipText: "Use my class notes", promptText: "using my class notes on privacy", feedbackNote: "Strong: anchors to your lesson.")
            ],
            recommendedOptionID: "c3"),
        PromptBuilderSlot(
            id: "action", label: "[Action]", placeholder: "Action",
            options: [
                PromptBuilderOption(id: "a1", chipText: "Give a summary", promptText: "give a short summary", feedbackNote: "Fast, but may skip examples."),
                PromptBuilderOption(id: "a2", chipText: "Explain step-by-step", promptText: "explain it step-by-step", feedbackNote: "Clearer and easier to learn."),
                PromptBuilderOption(id: "a3", chipText: "Compare good/bad use", promptText: "compare good use and risky use", feedbackNote: "Nice: comparison aids decisions.")
            ],
            recommendedOptionID: "a2"),
        PromptBuilderSlot(
            id: "format", label: "[Format]", placeholder: "Format",
            options: [
                PromptBuilderOption(id: "f1", chipText: "Paragraph", promptText: "in one paragraph.", feedbackNote: "Okay, but harder to scan."),
                PromptBuilderOption(id: "f2", chipText: "Bullet points", promptText: "in bullet points with examples.", feedbackNote: "Great: easy to scan."),
                PromptBuilderOption(id: "f3", chipText: "Checklist", promptText: "as a checklist I can reuse.", feedbackNote: "Practical and action-oriented.")
            ],
            recommendedOptionID: "f2")
    ],
    tip: "There's no single wrong answer. Clearer prompts usually produce clearer answers."
)

// Reuse Chapter 1's real, full ethics quiz (the four-question classroom challenge),
// extracted at runtime so it stays identical to the story — no duplication.
let chapter1EthicsQuizMiniGame: LectureQuizMiniGame = {
    for line in chapterOneStory.lines {
        if case .lectureQuiz(let quiz)? = line.inlineActivity {
            return quiz
        }
    }
    // Defensive fallback (should never be reached while Chapter 1 has its quiz).
    return LectureQuizMiniGame(
        title: "AI Ethics",
        question: "An AI sounds completely sure. Is that proof it's correct?",
        choices: [
            LectureQuizOption(id: "verify", text: "No — verify with a trusted source first",
                              feedback: "Correct. Confidence is not proof of truth.",
                              isBestAnswer: true, icon: "checkmark.shield.fill"),
            LectureQuizOption(id: "trust", text: "Yes — it sounds professional",
                              feedback: "Tone isn't truth.", icon: "exclamationmark.triangle.fill")
        ],
        summaryNote: "Confidence from a model is never proof of truth — verify."
    )
}()

#Preview {
    DemoMenuView()
        .environmentObject(GlobalSettingsStore())
        .preferredColorScheme(.light)
}
