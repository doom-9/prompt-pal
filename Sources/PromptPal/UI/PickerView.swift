import PromptPalCore
import SwiftUI

@MainActor
public final class PickerViewModel: ObservableObject {
    @Published public var query: String = ""
    @Published public var selectedIndex: Int = 0
    @Published public var focusToken: UUID = UUID()

    public init() {}

    public func reset() {
        query = ""
        selectedIndex = 0
        focusToken = UUID()
    }

    public func moveSelection(delta: Int, count: Int) {
        guard count > 0 else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    public func clampSelection(count: Int) {
        guard count > 0 else {
            selectedIndex = 0
            return
        }
        if selectedIndex >= count {
            selectedIndex = count - 1
        } else if selectedIndex < 0 {
            selectedIndex = 0
        }
    }
}

struct PickerView: View {
    @ObservedObject var store: PromptStore
    @ObservedObject var viewModel: PickerViewModel
    let onSelect: (PromptItem) -> Void
    let onOpenManagement: () -> Void
    let onCreateNew: () -> Void

    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [PromptItem] {
        store.filteredPrompts(query: viewModel.query)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.4)
            promptList
            Divider().opacity(0.4)
            footerBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.query) { _, _ in
            viewModel.selectedIndex = 0
        }
        .onChange(of: viewModel.focusToken) { _, _ in
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("搜索 Prompt...", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isSearchFocused)

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var promptList: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text(store.prompts.isEmpty ? "还没有 Prompt，按 ⌘N 新建一条" : "没有匹配的 Prompt")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                PickerRowView(
                                    item: item,
                                    index: index,
                                    isSelected: index == viewModel.selectedIndex
                                )
                                .id(item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(item)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: viewModel.selectedIndex) { _, newIndex in
                        if newIndex >= 0, newIndex < filteredItems.count {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(filteredItems[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            Text("↵ 复制并关闭")
            Text("·")
            Text("⌘1-5 快捷复制")
            Spacer()
            Button("⌘N 新建", action: onCreateNew)
                .buttonStyle(.plain)
            Text("·")
            Button("⌘, 管理", action: onOpenManagement)
                .buttonStyle(.plain)
            Text("·")
            Text("Esc 关闭")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private struct PickerRowView: View {
    let item: PromptItem
    let index: Int
    let isSelected: Bool

    private var previewText: String {
        item.content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isPinned ? "pin.fill" : "text.quote")
                .font(.system(size: 12))
                .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(previewText.isEmpty ? "（空内容）" : previewText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if index < 5 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.clear)
        )
    }
}
