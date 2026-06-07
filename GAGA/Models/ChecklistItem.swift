import Foundation

enum ChecklistCategory: String, Codable, CaseIterable {
    case essentials = "必須"
    case clothing = "衣類"
    case electronics = "電子機器"
    case toiletries = "洗面用具"
    case medicine = "薬・衛生用品"
    case documents = "書類"
    case recommended = "おすすめ"
    case culture = "文化・マナー"
    case custom = "カスタム"

    var localizedName: String {
        switch self {
        case .essentials: String(localized: "必須")
        case .clothing: String(localized: "衣類")
        case .electronics: String(localized: "電子機器")
        case .toiletries: String(localized: "洗面用具")
        case .medicine: String(localized: "薬・衛生用品")
        case .documents: String(localized: "書類")
        case .recommended: String(localized: "おすすめ")
        case .culture: String(localized: "文化・マナー")
        case .custom: String(localized: "カスタム")
        }
    }
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
