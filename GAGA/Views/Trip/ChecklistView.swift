import SwiftUI

struct ChecklistView: View {
    let tripId: String
    let destinations: [Location]
    @State private var items: [ChecklistItem] = []

    var body: some View {
        List {
            ForEach(ChecklistCategory.allCases, id: \.self) { category in
                let categoryItems = items.filter { $0.category == category }
                if !categoryItems.isEmpty {
                    Section(category.rawValue) {
                        ForEach(categoryItems) { item in
                            ChecklistRow(item: item) {
                                toggleItem(item)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("持ち物チェックリスト")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("追加", systemImage: "plus") {
                    addCustomItem()
                }
            }
        }
        .onAppear {
            if items.isEmpty {
                items = ChecklistTemplateService.generateChecklist(for: destinations)
            }
        }
    }

    private func toggleItem(_ item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isChecked.toggle()
    }

    private func addCustomItem() {
        let newItem = ChecklistItem(name: "新しいアイテム", category: .custom)
        items.append(newItem)
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
