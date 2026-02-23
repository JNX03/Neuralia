import SwiftUI

@MainActor
final class StoryProgressStore: ObservableObject {
    static let shared = StoryProgressStore()

    private enum Keys {
        static let completedChapterIDs = "storyProgress.completedChapterIDs"
    }

    @Published private(set) var completedChapterIDs: Set<String> = []

    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func markChapterCompleted(_ chapterID: String) {
        let normalized = chapterID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard !completedChapterIDs.contains(normalized) else { return }

        completedChapterIDs.insert(normalized)
        persist()
    }

    func isChapterCompleted(_ chapterID: String) -> Bool {
        completedChapterIDs.contains(chapterID)
    }

    func isChapterUnlocked(at index: Int, in chapters: [StoryChapter] = StoryChapterRepository.all) -> Bool {
        guard chapters.indices.contains(index) else { return false }
        guard index > 0 else { return true }
        return completedChapterIDs.contains(chapters[index - 1].id)
    }

    func completedCount(in chapters: [StoryChapter] = StoryChapterRepository.all) -> Int {
        chapters.filter { completedChapterIDs.contains($0.id) }.count
    }

    func resetAllProgress() {
        completedChapterIDs.removeAll()
        persist()
    }

    private func load() {
        let stored = userDefaults.stringArray(forKey: Keys.completedChapterIDs) ?? []
        completedChapterIDs = Set(stored)
    }

    private func persist() {
        userDefaults.set(Array(completedChapterIDs).sorted(), forKey: Keys.completedChapterIDs)
    }
}
