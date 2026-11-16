import PromptPalCore
import SwiftUI

public enum ManagementTab: String, CaseIterable {
    case prompts = "Prompt 管理"
    case settings = "偏好设置"
}

@MainActor
final class ManagementNavigationState: ObservableObject {
    @Published var selectedTab: ManagementTab = .prompts
    @Published var selectedPromptID: UUID?
}

struct ManagementView: View {
    @ObservedObject var store: PromptStore
    let hotKeyManager: HotKeyManager
    @ObservedObject var navState: ManagementNavigationState

    @State private var searchQuery: String = ""
    @State private var draftTitle: String = ""
    @State private var draftContent: String = ""
    @State private var draftPinned: Bool = false

    private var filteredPrompts: [PromptItem] {
        store.filteredPrompts(query: searchQuery)
    }

    private var selectedPrompt: PromptItem? {
        guard let id = navState.selectedPromptID else { return nil }
        return store.prompts.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if let loadError = store.lastLoadError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(loadError)（已备份原文件至 Application Support/PromptPal/）")
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button("打开目录") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL.deletingLastPathComponent()])
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
            }
            Divider()
            switch navState.selectedTab {
            case .prompts:
                promptsSplitView
            case .settings:
                SettingsView(hotKeyManager: hotKeyManager)
            }
        }
        .frame(minWidth: 700, minHeight: 460)
        .onAppear {
            ensureSelection()
            syncDraftFromSelection()
        }
        .onChange(of: navState.selectedPromptID) { _, _ in
            syncDraftFromSelection()
        }
    }

    private var headerBar: some View {
        HStack {
            Picker("", selection: $navState.selectedTab) {
                ForEach(ManagementTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            Spacer()

            if navState.selectedTab == .prompts {
                Button {
                    createPrompt()
                } label: {
                    Label("新建 Prompt", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var promptsSplitView: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 220, idealWidth: 250, maxWidth: 320)
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("筛选...", text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            List(filteredPrompts, selection: $navState.selectedPromptID) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.isPinned ? "pin.fill" : "text.quote")
                        .font(.caption)
                        .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)

                    Text(item.displayTitle)
                        .lineLimit(1)

                    Spacer()

                    if item.useCount > 0 {
                        Text("\(item.useCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }
                .tag(item.id)
            }
            .listStyle(.sidebar)
        }
    }

    private var detailPane: some View {
        Group {
            if let item = selectedPrompt {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        TextField("Prompt 标题", text: $draftTitle)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14, weight: .medium))
                            .onChange(of: draftTitle) { _, newValue in
                                persistDraft(for: item, title: newValue, content: draftContent, isPinned: draftPinned)
                            }

                        Toggle("置顶", isOn: $draftPinned)
                            .toggleStyle(.checkbox)
                            .onChange(of: draftPinned) { _, newValue in
                                persistDraft(for: item, title: draftTitle, content: draftContent, isPinned: newValue)
                            }

                        Button {
                            ClipboardService.copy(item.content)
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive) {
                            deleteSelectedPrompt(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("删除 Prompt")
                    }

                    TextEditor(text: $draftContent)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .onChange(of: draftContent) { _, newValue in
                            persistDraft(for: item, title: draftTitle, content: newValue, isPinned: draftPinned)
                        }
                }
                .padding(16)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("选择一条 Prompt 或点击右上角「新建 Prompt」")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func ensureSelection() {
        if navState.selectedPromptID == nil {
            navState.selectedPromptID = store.prompts.first?.id
        }
    }

    private func syncDraftFromSelection() {
        guard let item = selectedPrompt else {
            draftTitle = ""
            draftContent = ""
            draftPinned = false
            return
        }
        draftTitle = item.title
        draftContent = item.content
        draftPinned = item.isPinned
    }

    private func persistDraft(for item: PromptItem, title: String, content: String, isPinned: Bool) {
        guard item.title != title || item.content != content || item.isPinned != isPinned else {
            return
        }
        var updated = item
        updated.title = title
        updated.content = content
        updated.isPinned = isPinned
        store.updatePrompt(updated)
    }

    private func createPrompt() {
        let created = store.addPrompt(title: "", content: "")
        navState.selectedPromptID = created.id
    }

    private func deleteSelectedPrompt(_ item: PromptItem) {
        store.deletePrompt(id: item.id)
        navState.selectedPromptID = filteredPrompts.first?.id ?? store.prompts.first?.id
        syncDraftFromSelection()
    }
}
