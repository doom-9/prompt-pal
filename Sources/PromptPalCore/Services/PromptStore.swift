import Combine
import Foundation

@MainActor
public final class PromptStore: ObservableObject {
    @Published public private(set) var prompts: [PromptItem] = []
    @Published public private(set) var lastLoadError: String?

    public let fileURL: URL

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(fileURL: URL? = nil, seedIfMissing: Bool = true) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load(seedIfMissing: seedIfMissing)
    }

    public static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PromptPal", isDirectory: true)
            .appendingPathComponent("prompts.json")
    }

    public func filteredPrompts(query: String) -> [PromptItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return prompts }
        return prompts.filter { item in
            item.title.localizedCaseInsensitiveContains(trimmed)
                || item.content.localizedCaseInsensitiveContains(trimmed)
        }
    }

    @discardableResult
    public func addPrompt(title: String, content: String, isPinned: Bool = false) -> PromptItem {
        let now = Date()
        let item = PromptItem(
            title: title,
            content: content,
            isPinned: isPinned,
            createdAt: now,
            updatedAt: now
        )
        prompts.append(item)
        sortAndSave()
        return item
    }

    public func updatePrompt(_ item: PromptItem) {
        guard let index = prompts.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.updatedAt = Date()
        prompts[index] = updated
        sortAndSave()
    }

    public func deletePrompt(id: UUID) {
        prompts.removeAll { $0.id == id }
        sortAndSave()
    }

    public func togglePin(id: UUID) {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[index].isPinned.toggle()
        prompts[index].updatedAt = Date()
        sortAndSave()
    }

    public func recordUsage(id: UUID) {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[index].useCount += 1
        prompts[index].lastUsedAt = Date()
        sortAndSave()
    }

    private func load(seedIfMissing: Bool) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            if seedIfMissing {
                prompts = Self.starterPrompts()
                sortAndSave()
            }
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode([PromptItem].self, from: data)
            prompts = sorted(decoded)
            lastLoadError = nil
        } catch {
            lastLoadError = "无法读取 prompts.json：\(error.localizedDescription)"
            backupCorruptedFile()
            prompts = []
        }
    }

    private func backupCorruptedFile() {
        let fm = FileManager.default
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent).\(Int(Date().timeIntervalSince1970)).bak")
        try? fm.moveItem(at: fileURL, to: backupURL)
    }

    private func sortAndSave() {
        prompts = sorted(prompts)
        save()
    }

    private func sorted(_ items: [PromptItem]) -> [PromptItem] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            if lhs.useCount != rhs.useCount {
                return lhs.useCount > rhs.useCount
            }
            let lhsDate = lhs.lastUsedAt ?? lhs.updatedAt
            let rhsDate = rhs.lastUsedAt ?? rhs.updatedAt
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func save() {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try encoder.encode(prompts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            lastLoadError = "保存失败：\(error.localizedDescription)"
        }
    }

    private static func starterPrompts() -> [PromptItem] {
        let now = Date()
        return [
            PromptItem(
                title: "Plan Mode - 先出方案再写代码",
                content: "先不要修改任何文件。请先阅读相关代码，列出你的实现方案、涉及的文件和潜在风险，等我确认后再动手。",
                isPinned: true,
                createdAt: now,
                updatedAt: now
            ),
            PromptItem(
                title: "Code Review - 检查边界条件与并发",
                content: "请仔细审查当前改动（git diff），重点检查空值处理、边界条件、错误路径以及潜在的并发问题，只汇报真正需要修复的问题。",
                isPinned: true,
                createdAt: now.addingTimeInterval(-1),
                updatedAt: now.addingTimeInterval(-1)
            ),
            PromptItem(
                title: "Debug Root Cause - 定位根因",
                content: "不要猜测原因，也不要只修表面现象。请先收集报错上下文和相关调用链，给出最小复现与根因分析，再提出修复方案。",
                isPinned: false,
                createdAt: now.addingTimeInterval(-2),
                updatedAt: now.addingTimeInterval(-2)
            )
        ]
    }
}
