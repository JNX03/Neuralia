import SwiftUI

@MainActor
final class StoryProgressStore: ObservableObject {
    static let shared = StoryProgressStore()

    private enum Keys {
        static let completedChapterIDs = "storyProgress.completedChapterIDs"
        static let completedChapterDates = "storyProgress.completedChapterDates"
    }

    @Published private(set) var completedChapterIDs: Set<String> = []
    @Published private(set) var completionDatesByChapterID: [String: Date] = [:]

    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func markChapterCompleted(_ chapterID: String, at date: Date = .now) {
        let normalized = chapterID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        if completedChapterIDs.contains(normalized) {
            // Backfill a missing timestamp for legacy saves.
            if completionDatesByChapterID[normalized] == nil {
                completionDatesByChapterID[normalized] = date
                persist()
            }
            return
        }

        completedChapterIDs.insert(normalized)
        completionDatesByChapterID[normalized] = date
        persist()
    }

    func isChapterCompleted(_ chapterID: String) -> Bool {
        completedChapterIDs.contains(chapterID)
    }

    func completionDate(for chapterID: String) -> Date? {
        completionDatesByChapterID[chapterID]
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
        completionDatesByChapterID.removeAll()
        persist()
    }

    private func load() {
        let stored = userDefaults.stringArray(forKey: Keys.completedChapterIDs) ?? []
        completedChapterIDs = Set(stored)

        let storedDates = userDefaults.dictionary(forKey: Keys.completedChapterDates) ?? [:]
        completionDatesByChapterID = storedDates.reduce(into: [:]) { partialResult, entry in
            guard let number = entry.value as? NSNumber else { return }
            partialResult[entry.key] = Date(timeIntervalSince1970: number.doubleValue)
        }
    }

    private func persist() {
        userDefaults.set(Array(completedChapterIDs).sorted(), forKey: Keys.completedChapterIDs)
        let encodedDates = completionDatesByChapterID.mapValues { $0.timeIntervalSince1970 }
        userDefaults.set(encodedDates, forKey: Keys.completedChapterDates)
    }
}
