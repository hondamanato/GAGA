import Foundation

enum ChecklistCategory: String, Codable, CaseIterable {
    case essentials = "必須"
    case clothing = "衣類"
    case electronics = "電子機器"
    case toiletries = "洗面用具"
    case medicine = "薬・衛生用品"
    case documents = "書類"
    case recommended = "おすすめ"
    case custom = "カスタム"
}

struct ChecklistItem: Identifiable, Codable {
    var id: String
    var name: String
    var category: ChecklistCategory
    var isRequired: Bool
    var isChecked: Bool

    init(id: String = UUID().uuidString, name: String, category: ChecklistCategory, isRequired: Bool = false, isChecked: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.isRequired = isRequired
        self.isChecked = isChecked
    }
}
