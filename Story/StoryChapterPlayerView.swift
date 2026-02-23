import SwiftUI

@MainActor
struct StoryChapterPlayerView: View {
    @State private var currentChapter: StoryChapter
    @State private var continuePrompt: StoryChapter?

    init(initialChapter: StoryChapter) {
        _currentChapter = State(initialValue: initialChapter)
    }

    var body: some View {
        ResponsiveDialogView(
            nodes: currentChapter.nodes,
            chapterTopBarDropFactor: 0.5,
            onComplete: { handleChapterCompleted() }
        )
        .id(currentChapter.id)
        .navigationBarBackButtonHidden(true)
        .alert(item: $continuePrompt) { nextChapter in
            Alert(
                title: Text("Continue to \(nextChapter.title)?"),
                message: Text("You finished \(currentChapter.title). Start \(nextChapter.title) now?"),
                primaryButton: .default(Text("Continue")) {
                    currentChapter = nextChapter
                },
                secondaryButton: .cancel(Text("Not now"))
            )
        }
    }

    private func handleChapterCompleted() {
        StoryProgressStore.shared.markChapterCompleted(currentChapter.id)

        guard let nextChapter = nextChapter(after: currentChapter) else { return }
        continuePrompt = nextChapter
    }

    private func nextChapter(after chapter: StoryChapter) -> StoryChapter? {
        let chapters = StoryChapterRepository.all
        guard let currentIndex = chapters.firstIndex(where: { $0.id == chapter.id }) else { return nil }
        let nextIndex = currentIndex + 1
        guard chapters.indices.contains(nextIndex) else { return nil }
        return chapters[nextIndex]
    }
}
