import SwiftUI

struct ChecklistView: View {
    let tripId: String
    let destinations: [Location]
    var departureDate: Date?
    var returnDate: Date?
    var schedule: [DaySchedule] = []

    @State private var items: [ChecklistItem] = []
    @State private var isGenerating = false
    @State private var isAIGenerated = false
    @State private var newItemName = ""
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            List {
                let requiredItems = items.filter { $0.isRequired }
                if !requiredItems.isEmpty {
                    Section("必須") {
                        ForEach(requiredItems) { item in
                            ChecklistRow(item: item) {
                                toggleItem(item)
                            }
                        }
                    }
                }

                ForEach(ChecklistCategory.allCases, id: \.self) { category in
                    if category == .essentials { } else {
                        let categoryItems = items.filter { $0.category == category && !$0.isRequired }
                        if !categoryItems.isEmpty {
                            Section(category.rawValue) {
                                ForEach(categoryItems) { item in
                                    ChecklistRow(item: item) {
                                        toggleItem(item)
                                    }
                                }
                                .onDelete { offsets in
                                    deleteItems(in: category, at: offsets)
                                }
                            }
                        }
                    }
                }

                Section {
                    HStack(spacing: 6) {
                        Image(systemName: isAIGenerated ? "sparkles" : "list.bullet")
                            .foregroundStyle(isAIGenerated ? .purple : .secondary)
                            .font(.caption)
                        Text(isAIGenerated ? "AIが行き先に合わせて作成しました" : "基本テンプレートを表示中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("アイテムを追加") {
                    HStack {
                        TextField("新しいアイテム", text: $newItemName)
                        Button {
                            addCustomItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .opacity(isGenerating ? 0.3 : 1)

            if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("AIがチェックリストを作成中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("行き先の気候・文化を分析しています")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .navigationTitle("持ち物チェックリスト")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await regenerate() }
                } label: {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                }
                .disabled(isGenerating)
            }
        }
        .task {
            if items.isEmpty {
                await loadOrGenerate()
            }
        }
    }

    private func loadOrGenerate() async {
        if let saved = try? await ChecklistService.load(tripId: tripId), !saved.isEmpty {
            items = saved
            isAIGenerated = true
            return
        }
        await generateChecklist()
    }

    private func generateChecklist() async {
        isGenerating = true
        defer { isGenerating = false }
        let result = await ChecklistTemplateService.generateChecklist(
            for: destinations,
            departureDate: departureDate,
            returnDate: returnDate,
            schedule: schedule
        )
        items = result.items
        isAIGenerated = result.isAIGenerated
        scheduleSave()
    }

    private func regenerate() async {
        ChecklistService.invalidate(tripId: tripId)
        items = []
        await generateChecklist()
    }

    private func toggleItem(_ item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isChecked.toggle()
        scheduleSave()
    }

    private func deleteItems(in category: ChecklistCategory, at offsets: IndexSet) {
        let categoryItems = items.filter { $0.category == category }
        let idsToRemove = offsets.map { categoryItems[$0].id }
        items.removeAll { idsToRemove.contains($0.id) }
        scheduleSave()
    }

    private func addCustomItem() {
        let name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        items.append(ChecklistItem(name: name, category: .custom))
        newItemName = ""
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let currentItems = items
        let id = tripId
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            try? await ChecklistService.save(tripId: id, items: currentItems)
        }
    }
}

private struct ChecklistRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .green : .gray)

                Text(item.name)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)

                Spacer()

                if item.isRequired {
                    Text("必須")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
