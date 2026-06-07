import Foundation
import FirebaseAI

enum ChecklistTemplateService {

    /// Gemini で行き先・日程・スケジュールを考慮したチェックリストを生成する。
    /// ネットワーク不可時やエラー時はフォールバックの静的リストを返す。
    static func generateChecklist(
        for destinations: [Location],
        departureDate: Date? = nil,
        returnDate: Date? = nil,
        schedule: [DaySchedule] = []
    ) async -> (items: [ChecklistItem], isAIGenerated: Bool) {
        do {
            let items = try await generateWithAI(
                destinations: destinations,
                departureDate: departureDate,
                returnDate: returnDate,
                schedule: schedule
            )
            return (items, true)
        } catch {
            // Gemini error — use fallback checklist
            return (fallbackChecklist(for: destinations), false)
        }
    }

    // MARK: - AI 生成

    private static func generateWithAI(
        destinations: [Location],
        departureDate: Date?,
        returnDate: Date?,
        schedule: [DaySchedule]
    ) async throws -> [ChecklistItem] {
        let ai = FirebaseAI.firebaseAI()
        let model = ai.generativeModel(
            modelName: "gemini-2.5-flash",
            tools: [.googleSearch()]
        )

        let prompt = buildPrompt(
            destinations: destinations,
            departureDate: departureDate,
            returnDate: returnDate,
            schedule: schedule
        )

        let response = try await model.generateContent(prompt)
        guard let text = response.text else {
            return fallbackChecklist(for: destinations)
        }
        return parseResponse(text, destinations: destinations)
    }

    // MARK: - Prompt

    private static func buildPrompt(
        destinations: [Location],
        departureDate: Date?,
        returnDate: Date?,
        schedule: [DaySchedule]
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ja_JP")

        let destList = destinations.map { "\($0.name), \($0.country)" }.joined(separator: " → ")
        let dateRange: String
        if let dep = departureDate, let ret = returnDate {
            dateRange = "\(formatter.string(from: dep)) 〜 \(formatter.string(from: ret))"
        } else {
            dateRange = "未定"
        }

        var scheduleText = ""
        for day in schedule {
            let spots = day.spots.isEmpty ? "未定" : day.spots.joined(separator: ", ")
            scheduleText += "- \(formatter.string(from: day.date)): \(spots)"
            if !day.notes.isEmpty { scheduleText += " (\(day.notes))" }
            scheduleText += "\n"
        }

        return """
        あなたは旅行の持ち物アドバイザーです。以下の旅行情報をもとに、持ち物チェックリストをJSON配列で返してください。

        【旅行情報】
        行き先: \(destList)
        日程: \(dateRange)
        \(scheduleText.isEmpty ? "" : "スケジュール:\n\(scheduleText)")

        【要件】
        - 現地の気候・天候を考慮して衣類や持ち物を提案（例: 雨季なら折りたたみ傘、寒冷地なら防寒着）
        - 現地の文化・マナーを考慮した注意アイテム（例: 寺院訪問なら肌を覆う服、モスクならスカーフ）
        - 各国の入出国要件を考慮（例: 入国カード/出国カードが必要な国、ビザ・eVisa・ESTAの要否、税関申告書など）
        - 海外なら必須書類（パスポート、航空券、保険証書等）を含める
        - カテゴリ: 必須, 書類, 衣類, 電子機器, 洗面用具, 薬・衛生用品, おすすめ, 文化・マナー
        - isRequired は「忘れると旅行に重大な支障が出るもの」のみ true にする（例: パスポート、航空券、入国書類、スマホ、現金、常備薬など）。衣類・日用品・便利グッズは false にする
        - 20〜35個程度
        - 日本語で出力

        【出力形式】
        JSON配列のみを返してください。コードブロック記法(```)は不要です。
        [{"name": "アイテム名", "category": "カテゴリ名", "isRequired": true}]
        """
    }

    // MARK: - Parse

    private static func parseResponse(_ text: String, destinations: [Location]) -> [ChecklistItem] {
        // JSON 部分を抽出（コードブロックで囲まれている場合に対応）
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = jsonString.range(of: "["),
           let end = jsonString.range(of: "]", options: .backwards) {
            jsonString = String(jsonString[start.lowerBound..<end.upperBound])
        }

        guard let data = jsonString.data(using: .utf8) else {
            return fallbackChecklist(for: destinations)
        }

        struct AIItem: Decodable {
            let name: String
            let category: String
            let isRequired: Bool?
        }

        guard let aiItems = try? JSONDecoder().decode([AIItem].self, from: data) else {
            return fallbackChecklist(for: destinations)
        }

        let categoryMap: [String: ChecklistCategory] = [
            "必須": .essentials,
            "書類": .documents,
            "衣類": .clothing,
            "電子機器": .electronics,
            "洗面用具": .toiletries,
            "薬・衛生用品": .medicine,
            "おすすめ": .recommended,
            "文化・マナー": .culture,
        ]

        return aiItems.map { ai in
            ChecklistItem(
                name: ai.name,
                category: categoryMap[ai.category] ?? .recommended,
                isRequired: ai.isRequired ?? false
            )
        }
    }

    // MARK: - Fallback（従来の静的リスト）

    static func fallbackChecklist(for destinations: [Location]) -> [ChecklistItem] {
        var items: [ChecklistItem] = []
        let isInternational = destinations.contains { $0.country != "日本" }

        items.append(ChecklistItem(name: "スマートフォン", category: .essentials, isRequired: true))
        items.append(ChecklistItem(name: "充電器・ケーブル", category: .essentials, isRequired: true))
        items.append(ChecklistItem(name: "財布・現金", category: .essentials, isRequired: true))
        items.append(ChecklistItem(name: "クレジットカード", category: .essentials, isRequired: true))

        if isInternational {
            items.append(ChecklistItem(name: "パスポート", category: .documents, isRequired: true))
            items.append(ChecklistItem(name: "航空券（eチケット）", category: .documents, isRequired: true))
            items.append(ChecklistItem(name: "海外旅行保険証", category: .documents, isRequired: true))
            items.append(ChecklistItem(name: "ビザ / eVisa（必要な場合）", category: .documents))
            items.append(ChecklistItem(name: "入国カード（機内で記入）", category: .documents))
            items.append(ChecklistItem(name: "証明写真（予備）", category: .documents))
            items.append(ChecklistItem(name: "変換プラグ", category: .electronics))
            items.append(ChecklistItem(name: "ポケットWiFi / SIMカード", category: .electronics))
        }

        items.append(ChecklistItem(name: "着替え", category: .clothing))
        items.append(ChecklistItem(name: "下着", category: .clothing))
        items.append(ChecklistItem(name: "パジャマ", category: .clothing))
        items.append(ChecklistItem(name: "歯ブラシ・歯磨き粉", category: .toiletries))
        items.append(ChecklistItem(name: "シャンプー・ボディソープ", category: .toiletries))
        items.append(ChecklistItem(name: "日焼け止め", category: .toiletries))
        items.append(ChecklistItem(name: "常備薬", category: .medicine))
        items.append(ChecklistItem(name: "絆創膏", category: .medicine))
        items.append(ChecklistItem(name: "モバイルバッテリー", category: .electronics))
        items.append(ChecklistItem(name: "イヤホン", category: .electronics))
        items.append(ChecklistItem(name: "カメラ", category: .electronics))
        items.append(ChecklistItem(name: "エコバッグ", category: .recommended))
        items.append(ChecklistItem(name: "ネックピロー", category: .recommended))
        items.append(ChecklistItem(name: "アイマスク", category: .recommended))

        return items
    }
}
