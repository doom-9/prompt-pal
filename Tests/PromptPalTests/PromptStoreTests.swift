import Foundation
import XCTest
@testable import PromptPalCore

@MainActor
final class PromptStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptPalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    private var storeURL: URL {
        tempDir.appendingPathComponent("prompts.json")
    }

    func testSeedingOnFirstLaunch() {
        let store = PromptStore(fileURL: storeURL, seedIfMissing: true)

        XCTAssertEqual(store.prompts.count, 3)
        XCTAssertNil(store.lastLoadError)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testSortingPinnedThenUsageCountThenRecency() {
        let store = PromptStore(fileURL: storeURL, seedIfMissing: false)
        let lowPinned = store.addPrompt(title: "Low Pinned", content: "a", isPinned: true)
        let highUnpinned = store.addPrompt(title: "High Unpinned", content: "b", isPinned: false)
        let lowUnpinned = store.addPrompt(title: "Low Unpinned", content: "c", isPinned: false)

        store.recordUsage(id: highUnpinned.id)
        store.recordUsage(id: highUnpinned.id)
        store.recordUsage(id: lowUnpinned.id)

        let titles = store.prompts.map(\.title)
        XCTAssertEqual(titles, [lowPinned.title, highUnpinned.title, lowUnpinned.title])
    }

    func testSearchMatchesTitleAndContentAndIgnoresWhitespace() {
        let store = PromptStore(fileURL: storeURL, seedIfMissing: false)
        store.addPrompt(title: "Code Review", content: "Check nil values")
        store.addPrompt(title: "Commit", content: "Generate git diff message")

        XCTAssertEqual(store.filteredPrompts(query: "   \n ").count, 2)
        XCTAssertEqual(store.filteredPrompts(query: "DIFF").map(\.title), ["Commit"])
        XCTAssertEqual(store.filteredPrompts(query: "review").map(\.title), ["Code Review"])
        XCTAssertTrue(store.filteredPrompts(query: "nonexistent-xyz").isEmpty)
    }

    func testRecordUsageIncrementsCountAndPersists() {
        let store = PromptStore(fileURL: storeURL, seedIfMissing: false)
        let item = store.addPrompt(title: "Debug", content: "Collect logs first")

        store.recordUsage(id: item.id)

        let reloaded = PromptStore(fileURL: storeURL, seedIfMissing: false)
        let loadedItem = reloaded.prompts.first { $0.id == item.id }
        XCTAssertEqual(loadedItem?.useCount, 1)
        XCTAssertNotNil(loadedItem?.lastUsedAt)
    }

    func testCorruptedJSONBacksUpAndRecovers() throws {
        try Data("{ invalid json".utf8).write(to: storeURL)

        let store = PromptStore(fileURL: storeURL, seedIfMissing: false)

        XCTAssertNotNil(store.lastLoadError)
        XCTAssertTrue(store.prompts.isEmpty)

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("prompts.json") && $0.hasSuffix(".bak") })
    }
}
