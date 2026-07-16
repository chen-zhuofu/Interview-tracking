import Foundation
import SwiftData

/// Data tools the chat agent can call. Every tool takes / returns JSON.
/// The agent reads first (list_companies / get_company) and then writes,
/// so edits land on the right records.
@MainActor
enum AgentToolbox {
    static let placeholderPosition = "未命名岗位"

    struct ToolResult {
        let output: String
        /// Human-readable summary for the chat transcript / trace.
        let summary: String?
    }

    /// OpenAI-style tool schema list sent to the model.
    static let toolSchemas: [[String: Any]] = [
        tool(
            name: "list_companies",
            description: "列出全部公司及其岗位、想去程度、当前阶段、看板桶。改数据前先看这个。",
            parameters: [:],
            required: []
        ),
        tool(
            name: "get_company",
            description: "查看一家公司的完整信息：公司资料、岗位、全部阶段节点（含 nodeID、日期、备注）。",
            parameters: [
                "companyName": ["type": "string", "description": "公司名，可用别名（如 sierra、moonshot）"]
            ],
            required: ["companyName"]
        ),
        tool(
            name: "upsert_company",
            description: "创建或更新公司资料（名字会自动规范成官方写法并与已有公司合并）。",
            parameters: [
                "name": ["type": "string"],
                "website": ["type": "string"],
                "contactPerson": ["type": "string"],
                "contactEmail": ["type": "string"],
                "opinion": ["type": "string", "description": "用户对公司的看法"],
                "companyDescription": ["type": "string"],
                "notes": ["type": "string"]
            ],
            required: ["name"]
        ),
        tool(
            name: "update_application",
            description: "更新一家公司的机会信息（岗位、想去程度、JD、反馈等）。不涉及阶段。",
            parameters: [
                "companyName": ["type": "string"],
                "position": ["type": "string", "description": "岗位名，禁止写阶段名"],
                "desireLevel": ["type": "integer", "description": "想去程度 1-5"],
                "appliedDate": ["type": "string", "description": "YYYY-MM-DD"],
                "notes": ["type": "string"],
                "feedback": ["type": "string"],
                "jobDescriptionURL": ["type": "string"],
                "jobDescriptionText": ["type": "string"]
            ],
            required: ["companyName"]
        ),
        tool(
            name: "add_stage_node",
            description: """
            在时间线上给公司加一个阶段节点。title 用用户的原话（只做格式化），例如 \
            "猎头联系Leslie"、"预约HR Call"、"HR Call"、"Phone Interview 2"、"Offer"。\
            有具体钟点的面试 date 用 YYYY-MM-DDTHH:mm；只有日期用 YYYY-MM-DD。
            """,
            parameters: [
                "companyName": ["type": "string"],
                "title": ["type": "string"],
                "date": ["type": "string", "description": "YYYY-MM-DD 或 YYYY-MM-DDTHH:mm"],
                "bucket": [
                    "type": "string",
                    "enum": ["not_started", "in_progress", "closed"],
                    "description": "看板桶；不传则自动判断"
                ],
                "isInterview": [
                    "type": "boolean",
                    "description": "这个节点是否算一轮面试。面试从 HR Call 起算；猎头Call、内推、各种「预约X」不算。不传则自动判断"
                ],
                "note": ["type": "string"]
            ],
            required: ["companyName", "title", "date"]
        ),
        tool(
            name: "update_stage_node",
            description: "修改已有阶段节点（先用 get_company 拿 nodeID）。只传要改的字段。",
            parameters: [
                "nodeID": ["type": "string"],
                "title": ["type": "string"],
                "date": ["type": "string", "description": "YYYY-MM-DD 或 YYYY-MM-DDTHH:mm"],
                "bucket": ["type": "string", "enum": ["not_started", "in_progress", "closed"]],
                "isInterview": ["type": "boolean", "description": "这个节点是否算一轮面试"],
                "note": ["type": "string"]
            ],
            required: ["nodeID"]
        ),
        tool(
            name: "delete_stage_node",
            description: "删除一个阶段节点（先用 get_company 拿 nodeID）。",
            parameters: [
                "nodeID": ["type": "string"]
            ],
            required: ["nodeID"]
        ),
        tool(
            name: "delete_company",
            description: "删除整家公司及其全部记录。仅当用户明确要求删除公司时使用。",
            parameters: [
                "companyName": ["type": "string"]
            ],
            required: ["companyName"]
        ),
        tool(
            name: "fetch_webpage",
            description: """
            抓取一个网页并返回其标题和正文纯文本。用户发链接让你看内容时（JD、公司介绍、博客、论文页面等）\
            先用这个工具读网页，再把有用的信息写进对应记录。
            """,
            parameters: [
                "url": ["type": "string", "description": "完整链接，https:// 开头"]
            ],
            required: ["url"]
        ),
        tool(
            name: "list_reading_items",
            description: "列出阅读收藏（论文 / tech blog / YouTube 视频）：itemID、标题、类型、标签、已读状态、来源。改收藏前先看这个。",
            parameters: [:],
            required: []
        ),
        tool(
            name: "add_reading_item",
            description: "添加一条阅读收藏。本地 PDF 只能用户手动添加，agent 只能加带链接的条目。",
            parameters: [
                "title": ["type": "string"],
                "url": ["type": "string", "description": "链接，如 https://arxiv.org/abs/…"],
                "kind": ["type": "string", "enum": ["paper", "blog", "video"], "description": "paper=论文 blog=博客 video=视频"],
                "tags": ["type": "string", "description": "逗号分隔，如 LLM, RLHF"],
                "note": ["type": "string", "description": "一句话备注：为什么值得读"]
            ],
            required: ["title", "url", "kind"]
        ),
        tool(
            name: "update_reading_item",
            description: "修改阅读收藏（先用 list_reading_items 拿 itemID）。只传要改的字段。可标已读/未读、改标签、追加阅读笔记。",
            parameters: [
                "itemID": ["type": "string"],
                "title": ["type": "string"],
                "url": ["type": "string"],
                "kind": ["type": "string", "enum": ["paper", "blog", "video"]],
                "tags": ["type": "string"],
                "note": ["type": "string"],
                "appendReadingNotes": ["type": "string", "description": "追加到阅读笔记末尾（不会覆盖已有笔记）"],
                "isRead": ["type": "boolean"]
            ],
            required: ["itemID"]
        ),
        tool(
            name: "delete_reading_item",
            description: "删除一条阅读收藏（先用 list_reading_items 拿 itemID）。",
            parameters: [
                "itemID": ["type": "string"]
            ],
            required: ["itemID"]
        ),
        tool(
            name: "list_documents",
            description: "列出求职资料库（简历 / slides / cover letter）：docID、标题、类型、备注、关联公司、文件格式。改资料信息前先看这个。文件本身只能用户手动拖入。",
            parameters: [:],
            required: []
        ),
        tool(
            name: "update_document",
            description: "修改一份求职资料的信息（先用 list_documents 拿 docID）。只传要改的字段。不能改文件本体。",
            parameters: [
                "docID": ["type": "string"],
                "title": ["type": "string"],
                "kind": ["type": "string", "enum": ["resume", "slides", "coverLetter", "other"], "description": "resume=简历 slides=Slides coverLetter=Cover Letter"],
                "note": ["type": "string", "description": "版本说明，如「投 OpenAI 的英文版 v3」"],
                "targetCompany": ["type": "string", "description": "关联公司名"]
            ],
            required: ["docID"]
        ),
        tool(
            name: "delete_document",
            description: "删除一份求职资料及其文件（先用 list_documents 拿 docID）。仅当用户明确要求删除时使用。",
            parameters: [
                "docID": ["type": "string"]
            ],
            required: ["docID"]
        )
    ]

    private static func tool(
        name: String,
        description: String,
        parameters: [String: [String: Any]],
        required: [String]
    ) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": parameters,
                    "required": required
                ] as [String: Any]
            ] as [String: Any]
        ]
    }

    // MARK: - Dispatch

    static func execute(
        name: String,
        argumentsJSON: String,
        in context: ModelContext
    ) async -> ToolResult {
        let args = (try? JSONSerialization.jsonObject(
            with: Data(argumentsJSON.utf8)
        ) as? [String: Any]) ?? [:]

        do {
            switch name {
            case "list_companies": return try listCompanies(in: context)
            case "get_company": return try getCompany(args, in: context)
            case "upsert_company": return try upsertCompany(args, in: context)
            case "update_application": return try updateApplication(args, in: context)
            case "add_stage_node": return try addStageNode(args, in: context)
            case "update_stage_node": return try updateStageNode(args, in: context)
            case "delete_stage_node": return try deleteStageNode(args, in: context)
            case "delete_company": return try deleteCompany(args, in: context)
            case "fetch_webpage": return await fetchWebpage(args)
            case "list_reading_items": return try listReadingItems(in: context)
            case "add_reading_item": return try addReadingItem(args, in: context)
            case "update_reading_item": return try updateReadingItem(args, in: context)
            case "delete_reading_item": return try deleteReadingItem(args, in: context)
            case "list_documents": return try listDocuments(in: context)
            case "update_document": return try updateDocument(args, in: context)
            case "delete_document": return try deleteDocument(args, in: context)
            default:
                return ToolResult(output: #"{"error":"unknown tool"}"#, summary: nil)
            }
        } catch {
            return ToolResult(
                output: #"{"error":"\#(error.localizedDescription)"}"#,
                summary: nil
            )
        }
    }

    // MARK: - Web tools

    /// Fetch a webpage and return title + plain-text body (truncated).
    private static func fetchWebpage(_ args: [String: Any]) async -> ToolResult {
        guard var raw = (args["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return ToolResult(output: #"{"error":"url required"}"#, summary: nil)
        }
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "https://" + raw
        }
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return ToolResult(output: #"{"error":"invalid url"}"#, summary: nil)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200...299).contains(status) else {
                return ToolResult(output: #"{"error":"HTTP \#(status)"}"#, summary: nil)
            }
            let html = String(data: data, encoding: .utf8)
                ?? String(decoding: data, as: UTF8.self)
            var text = HTMLTextExtractor.plainText(from: html)
            let truncated = text.count > 12000
            if truncated {
                text = String(text.prefix(12000))
            }
            var payload: [String: Any] = ["url": raw, "text": text]
            if let title = HTMLTextExtractor.title(from: html) { payload["title"] = title }
            if truncated { payload["truncated"] = true }
            return ToolResult(output: jsonString(payload), summary: "读取网页 \(url.host ?? raw)")
        } catch {
            return ToolResult(
                output: #"{"error":"抓取失败：\#(error.localizedDescription)"}"#,
                summary: nil
            )
        }
    }

    // MARK: - Read tools

    private static func listCompanies(in context: ModelContext) throws -> ToolResult {
        let companies = try context.fetch(FetchDescriptor<Company>())
        let rows: [[String: Any]] = companies
            .sorted { $0.name < $1.name }
            .map { company in
                let app = preferredApplication(for: company)
                var row: [String: Any] = [
                    "company": company.name,
                    "position": app?.position ?? "",
                    "currentStage": app?.currentStageTitle ?? "未开始",
                    "bucket": app?.opportunityBucket.rawValue ?? "not_started",
                    "stageNodeCount": app?.stageNodes?.count ?? 0
                ]
                if let desire = app?.desireLevel { row["desireLevel"] = desire }
                return row
            }
        return ToolResult(output: jsonString(rows), summary: nil)
    }

    private static func getCompany(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let company = try findCompany(args["companyName"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"company not found"}"#, summary: nil)
        }
        let app = preferredApplication(for: company)
        var payload: [String: Any] = [
            "company": company.name,
            "position": app?.position ?? "",
            "currentStage": app?.currentStageTitle ?? "未开始",
            "bucket": app?.opportunityBucket.rawValue ?? "not_started"
        ]
        if let desire = app?.desireLevel { payload["desireLevel"] = desire }
        if let website = company.website { payload["website"] = website }
        if let contact = company.contactPerson { payload["contactPerson"] = contact }
        if let opinion = company.opinion { payload["opinion"] = opinion }
        if let notes = app?.notes { payload["notes"] = notes }
        if let feedback = app?.feedback { payload["feedback"] = feedback }
        if let applied = app?.appliedDate { payload["appliedDate"] = dayString(applied) }

        payload["stageNodes"] = (app?.orderedStageNodes ?? []).map { node -> [String: Any] in
            var row: [String: Any] = [
                "nodeID": node.id.uuidString,
                "title": node.title,
                "bucket": node.bucket,
                "isInterview": node.isInterview,
                "date": node.hasTime ? dateTimeString(node.date) : dayString(node.date)
            ]
            if let note = node.note, !note.isEmpty { row["note"] = note }
            return row
        }
        return ToolResult(output: jsonString(payload), summary: nil)
    }

    // MARK: - Write tools

    private static func upsertCompany(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let raw = (args["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return ToolResult(output: #"{"error":"name required"}"#, summary: nil)
        }
        let company = try findOrCreateCompany(named: raw, in: context)
        if let v = args["website"] as? String { company.website = v }
        if let v = args["contactPerson"] as? String { company.contactPerson = v }
        if let v = args["contactEmail"] as? String { company.contactEmail = v }
        if let v = args["opinion"] as? String { company.opinion = mergeText(company.opinion, v) }
        if let v = args["companyDescription"] as? String {
            company.companyDescription = mergeText(company.companyDescription, v)
        }
        if let v = args["notes"] as? String { company.notes = mergeText(company.notes, v) }
        try context.save()
        return ToolResult(
            output: #"{"ok":true,"company":"\#(company.name)"}"#,
            summary: "公司 \(company.name)"
        )
    }

    private static func updateApplication(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let company = try findCompany(args["companyName"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"company not found，先 upsert_company"}"#, summary: nil)
        }
        let app = try ensureApplication(for: company, in: context)

        if let position = (args["position"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !position.isEmpty {
            mergePosition(into: app, position: position)
        }
        if let desire = args["desireLevel"] as? Int, (1...5).contains(desire) {
            app.desireLevel = desire
        }
        if let dateRaw = args["appliedDate"] as? String, let date = ISO8601Flexible.parse(dateRaw) {
            app.appliedDate = date
        }
        if let v = args["notes"] as? String { app.notes = mergeText(app.notes, v) }
        if let v = args["feedback"] as? String {
            app.feedback = mergeText(app.feedback, v)
            UserFeedbackMemoryStore.append(kind: "feedback", text: v, companyHint: company.name)
        }
        if let v = args["jobDescriptionURL"] as? String { app.jobDescriptionURL = v }
        if let v = args["jobDescriptionText"] as? String {
            app.jobDescriptionText = mergeText(app.jobDescriptionText, v)
        }
        app.lastUpdated = Date()
        try context.save()
        return ToolResult(
            output: #"{"ok":true}"#,
            summary: "机会 \(app.position) @ \(company.name)"
        )
    }

    private static func addStageNode(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let rawName = args["companyName"] as? String else {
            return ToolResult(output: #"{"error":"companyName required"}"#, summary: nil)
        }
        let company = try findOrCreateCompany(named: rawName, in: context)
        let app = try ensureApplication(for: company, in: context)

        guard let rawTitle = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTitle.isEmpty,
              let dateRaw = args["date"] as? String,
              let date = ISO8601Flexible.parse(dateRaw)
        else {
            return ToolResult(output: #"{"error":"title/date required"}"#, summary: nil)
        }

        let title = StageClassifier.formatTitle(rawTitle)
        let bucket = OpportunityBucket.parse(args["bucket"] as? String)
            ?? StageClassifier.bucket(forTitle: title)
        let isInterview = (args["isInterview"] as? Bool)
            ?? StageClassifier.isInterview(forTitle: title)

        // Same title on the same day → update instead of duplicating.
        let cal = Calendar.current
        if let existing = (app.stageNodes ?? []).first(where: {
            $0.title.caseInsensitiveCompare(title) == .orderedSame
                && cal.isDate($0.date, inSameDayAs: date)
        }) {
            existing.date = date
            existing.hasTime = ISO8601Flexible.hasClockTime(dateRaw)
            existing.bucket = bucket.rawValue
            existing.isInterview = isInterview
            if let note = args["note"] as? String { existing.note = mergeText(existing.note, note) }
            app.lastUpdated = Date()
            try context.save()
            return ToolResult(
                output: #"{"ok":true,"nodeID":"\#(existing.id.uuidString)","merged":true}"#,
                summary: "更新节点 \(title) · \(company.name)"
            )
        }

        let node = StageNode(
            title: title,
            bucket: bucket.rawValue,
            date: date,
            hasTime: ISO8601Flexible.hasClockTime(dateRaw),
            isInterview: isInterview,
            note: args["note"] as? String,
            application: app
        )
        context.insert(node)
        if app.appliedDate == nil { app.appliedDate = date }
        app.lastUpdated = Date()
        try context.save()
        return ToolResult(
            output: #"{"ok":true,"nodeID":"\#(node.id.uuidString)"}"#,
            summary: "节点 \(title) · \(company.name)"
        )
    }

    private static func updateStageNode(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let node = try findNode(args["nodeID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"node not found，先 get_company 拿 nodeID"}"#, summary: nil)
        }
        if let rawTitle = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawTitle.isEmpty {
            node.title = StageClassifier.formatTitle(rawTitle)
            if args["bucket"] == nil {
                node.bucket = StageClassifier.bucket(forTitle: node.title).rawValue
            }
            if args["isInterview"] == nil {
                node.isInterview = StageClassifier.isInterview(forTitle: node.title)
            }
        }
        if let isInterview = args["isInterview"] as? Bool {
            node.isInterview = isInterview
        }
        if let dateRaw = args["date"] as? String, let date = ISO8601Flexible.parse(dateRaw) {
            node.date = date
            node.hasTime = ISO8601Flexible.hasClockTime(dateRaw)
        }
        if let bucket = OpportunityBucket.parse(args["bucket"] as? String) {
            node.bucket = bucket.rawValue
        }
        if let note = args["note"] as? String {
            node.note = note.isEmpty ? nil : note
        }
        node.application?.lastUpdated = Date()
        try context.save()
        let company = node.application?.company?.name ?? "?"
        return ToolResult(
            output: #"{"ok":true}"#,
            summary: "更新节点 \(node.title) · \(company)"
        )
    }

    private static func deleteStageNode(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let node = try findNode(args["nodeID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"node not found"}"#, summary: nil)
        }
        let label = "\(node.application?.company?.name ?? "?")·\(node.title)"
        node.application?.lastUpdated = Date()
        context.delete(node)
        try context.save()
        return ToolResult(output: #"{"ok":true}"#, summary: "删除节点 \(label)")
    }

    private static func deleteCompany(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let company = try findCompany(args["companyName"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"company not found"}"#, summary: nil)
        }
        let name = company.name
        context.delete(company)
        try context.save()
        return ToolResult(output: #"{"ok":true}"#, summary: "已删除 \(name)")
    }

    // MARK: - Reading library tools

    private static func listReadingItems(in context: ModelContext) throws -> ToolResult {
        let items = try context.fetch(FetchDescriptor<ReadingItem>())
        let rows: [[String: Any]] = items
            .sorted { $0.createdAt > $1.createdAt }
            .map { item in
                var row: [String: Any] = [
                    "itemID": item.id.uuidString,
                    "title": item.title,
                    "kind": item.kind,
                    "isRead": item.isRead,
                    "source": item.domain
                ]
                if !item.tags.isEmpty { row["tags"] = item.tags }
                if let note = item.note, !note.isEmpty { row["note"] = note }
                if item.hasNotes { row["hasReadingNotes"] = true }
                return row
            }
        return ToolResult(output: jsonString(rows), summary: nil)
    }

    private static func addReadingItem(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty,
              let url = (args["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !url.isEmpty
        else {
            return ToolResult(output: #"{"error":"title/url required"}"#, summary: nil)
        }
        let kind = ReadingKind(rawValue: (args["kind"] as? String) ?? "") ?? .blog

        // 同链接已存在 → 不重复收藏。
        let existing = try context.fetch(FetchDescriptor<ReadingItem>())
        if let dup = existing.first(where: { $0.urlString.caseInsensitiveCompare(url) == .orderedSame }) {
            return ToolResult(
                output: #"{"ok":true,"itemID":"\#(dup.id.uuidString)","duplicate":true}"#,
                summary: "已存在：\(dup.title)"
            )
        }

        let item = ReadingItem(
            title: title,
            urlString: url,
            kind: kind,
            tags: (args["tags"] as? String) ?? "",
            note: args["note"] as? String
        )
        context.insert(item)
        try context.save()
        return ToolResult(
            output: #"{"ok":true,"itemID":"\#(item.id.uuidString)"}"#,
            summary: "收藏「\(title)」（\(kind.label)）"
        )
    }

    private static func updateReadingItem(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let item = try findReadingItem(args["itemID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"item not found，先 list_reading_items 拿 itemID"}"#, summary: nil)
        }
        if let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            item.title = title
        }
        if let url = (args["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !url.isEmpty {
            item.urlString = url
        }
        if let kind = ReadingKind(rawValue: (args["kind"] as? String) ?? "") {
            item.kind = kind.rawValue
        }
        if let tags = args["tags"] as? String { item.tags = tags }
        if let note = args["note"] as? String { item.note = note.isEmpty ? nil : note }
        if let extra = (args["appendReadingNotes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !extra.isEmpty {
            let current = item.readingNotes ?? ""
            item.readingNotes = current.isEmpty ? extra : current + "\n\n" + extra
        }
        if let isRead = args["isRead"] as? Bool { item.isRead = isRead }
        try context.save()
        return ToolResult(
            output: #"{"ok":true}"#,
            summary: "更新收藏「\(item.title)」"
        )
    }

    private static func deleteReadingItem(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let item = try findReadingItem(args["itemID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"item not found"}"#, summary: nil)
        }
        let title = item.title
        if let fileName = item.fileName {
            AttachmentStore.delete(fileName: fileName)
        }
        context.delete(item)
        try context.save()
        return ToolResult(output: #"{"ok":true}"#, summary: "删除收藏「\(title)」")
    }

    private static func findReadingItem(_ raw: String?, in context: ModelContext) throws -> ReadingItem? {
        guard let raw, let id = UUID(uuidString: raw) else { return nil }
        var descriptor = FetchDescriptor<ReadingItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Document vault tools

    private static func listDocuments(in context: ModelContext) throws -> ToolResult {
        let documents = try context.fetch(FetchDescriptor<CareerDocument>())
        let rows: [[String: Any]] = documents
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { doc in
                var row: [String: Any] = [
                    "docID": doc.id.uuidString,
                    "title": doc.title,
                    "kind": doc.kind,
                    "file": doc.originalFileName
                ]
                if let note = doc.note, !note.isEmpty { row["note"] = note }
                if let company = doc.targetCompany, !company.isEmpty { row["targetCompany"] = company }
                return row
            }
        return ToolResult(output: jsonString(rows), summary: nil)
    }

    private static func updateDocument(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let doc = try findDocument(args["docID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"document not found，先 list_documents 拿 docID"}"#, summary: nil)
        }
        if let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            doc.title = title
        }
        if let kind = DocumentKind(rawValue: (args["kind"] as? String) ?? "") {
            doc.kind = kind.rawValue
        }
        if let note = args["note"] as? String {
            doc.note = note.isEmpty ? nil : note
        }
        if let company = args["targetCompany"] as? String {
            doc.targetCompany = company.isEmpty ? nil : CompanyNameNormalizer.canonicalize(company)
        }
        doc.updatedAt = Date()
        try context.save()
        return ToolResult(
            output: #"{"ok":true}"#,
            summary: "更新资料「\(doc.title)」"
        )
    }

    private static func deleteDocument(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let doc = try findDocument(args["docID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"document not found"}"#, summary: nil)
        }
        let title = doc.title
        AttachmentStore.delete(fileName: doc.fileName)
        context.delete(doc)
        try context.save()
        return ToolResult(output: #"{"ok":true}"#, summary: "删除资料「\(title)」")
    }

    private static func findDocument(_ raw: String?, in context: ModelContext) throws -> CareerDocument? {
        guard let raw, let id = UUID(uuidString: raw) else { return nil }
        var descriptor = FetchDescriptor<CareerDocument>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Lookup helpers

    static func findCompany(_ raw: String?, in context: ModelContext) throws -> Company? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let all = try context.fetch(FetchDescriptor<Company>())
        let canonical = CompanyNameNormalizer.canonicalize(raw)
        let keys = Set([
            CompanyNameNormalizer.matchingKey(raw),
            CompanyNameNormalizer.matchingKey(canonical)
        ])
        return all.first {
            keys.contains(CompanyNameNormalizer.matchingKey($0.name))
                || keys.contains(CompanyNameNormalizer.matchingKey(CompanyNameNormalizer.canonicalize($0.name)))
        }
    }

    static func findOrCreateCompany(named raw: String, in context: ModelContext) throws -> Company {
        if let existing = try findCompany(raw, in: context) {
            // Upgrade stored name to the official display form when we know it.
            let official = CompanyNameNormalizer.canonicalize(existing.name)
            if existing.name != official { existing.name = official }
            return existing
        }
        let company = Company(name: CompanyNameNormalizer.canonicalize(raw))
        context.insert(company)
        return company
    }

    static func ensureApplication(for company: Company, in context: ModelContext) throws -> Application {
        if let existing = preferredApplication(for: company) { return existing }
        let app = Application(position: placeholderPosition, company: company)
        context.insert(app)
        return app
    }

    /// Company is the smallest unit — one opportunity per company.
    static func preferredApplication(for company: Company) -> Application? {
        (company.applications ?? []).sorted { $0.lastUpdated > $1.lastUpdated }.first
    }

    private static func findNode(_ raw: String?, in context: ModelContext) throws -> StageNode? {
        guard let raw, let id = UUID(uuidString: raw) else { return nil }
        var descriptor = FetchDescriptor<StageNode>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func mergePosition(into application: Application, position: String) {
        let incoming = position.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incoming.isEmpty, incoming != placeholderPosition else { return }
        var parts = application.position
            .components(separatedBy: " · ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != placeholderPosition }
        for part in incoming.components(separatedBy: " · ") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if !parts.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                parts.append(trimmed)
            }
        }
        application.position = parts.isEmpty ? placeholderPosition : parts.joined(separator: " · ")
    }

    private static func mergeText(_ existing: String?, _ incoming: String) -> String {
        let trimmed = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return existing ?? "" }
        guard let existing, !existing.isEmpty else { return trimmed }
        if existing.contains(trimmed) { return existing }
        return existing + "\n" + trimmed
    }

    // MARK: - Formatting

    private static func jsonString(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        ) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func dateTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f.string(from: date)
    }
}
