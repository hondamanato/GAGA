import Foundation

enum ChecklistTemplateService {
    static func generateChecklist(for destinations: [Location]) -> [ChecklistItem] {
        var items: [ChecklistItem] = []

        let isInternational = destinations.contains { $0.country != "日本" }

        // 必須アイテム
        items.append(ChecklistItem(name: "スマートフォン", category: .essentials, isRequired: true))
        items.append(ChecklistItem(name: "充電器・ケーブル", category: .essentials, isRequired: true))
        items.append(ChecklistItem(name: "財布・現金", category: .essentials, isRequired: true))
        items.append(ChecklistItem(name: "クレジットカード", category: .essentials, isRequired: true))

        if isInternational {
            items.append(ChecklistItem(name: "パスポート", category: .documents, isRequired: true))
            items.append(ChecklistItem(name: "航空券（eチケット）", category: .documents, isRequired: true))
            items.append(ChecklistItem(name: "海外旅行保険証", category: .documents, isRequired: true))
            items.append(ChecklistItem(name: "変換プラグ", category: .electronics, isRequired: false))
            items.append(ChecklistItem(name: "ポケットWiFi / SIMカード", category: .electronics, isRequired: false))
        }

        // 衣類
        items.append(ChecklistItem(name: "着替え", category: .clothing))
        items.append(ChecklistItem(name: "下着", category: .clothing))
        items.append(ChecklistItem(name: "パジャマ", category: .clothing))

        // 洗面用具
        items.append(ChecklistItem(name: "歯ブラシ・歯磨き粉", category: .toiletries))
        items.append(ChecklistItem(name: "シャンプー・ボディソープ", category: .toiletries))
        items.append(ChecklistItem(name: "日焼け止め", category: .toiletries))

        // 薬・衛生
        items.append(ChecklistItem(name: "常備薬", category: .medicine))
        items.append(ChecklistItem(name: "絆創膏", category: .medicine))

        // 電子機器
        items.append(ChecklistItem(name: "モバイルバッテリー", category: .electronics))
        items.append(ChecklistItem(name: "イヤホン", category: .electronics))
        items.append(ChecklistItem(name: "カメラ", category: .electronics))

        // おすすめ
        items.append(ChecklistItem(name: "エコバッグ", category: .recommended))
        items.append(ChecklistItem(name: "ネックピロー", category: .recommended))
        items.append(ChecklistItem(name: "アイマスク", category: .recommended))

        return items
    }
}
