import Foundation
import SwiftData

/// Data tools the chat agent can call. Every tool takes / returns JSON.
/// The agent reads first (list_companies / get_company) and then writes,
/// so edits land on the right records.
@MainActor
enum AgentToolbox {
    static let placeholderPosition = "未命名岗位"

    struct PendingWrite: Identifiable, Equatable {
        let id: UUID
        let toolName: String
        let argumentsJSON: String
        let preview: String

        init(toolName: String, argumentsJSON: String, preview: String) {
            self.id = UUID()
            self.toolName = toolName
            self.argumentsJSON = argumentsJSON
            self.preview = preview
        }
    }

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
        ),
        tool(
            name: "list_interview_insights",
            description: "列出全部面试心得：insightID、标题、关联公司、正文摘要。改心得前先看这个。",
            parameters: [:],
            required: []
        ),
        tool(
            name: "add_interview_insight",
            description: """
            记一条面试心得。用户面完某轮想记录感受、被问的题、复盘要点时用这个。\
            body 写心得正文（用户原话为准，可整理但别编造）；title 可给个简短标题；\
            company 可选，关联到某家公司。
            """,
            parameters: [
                "title": ["type": "string", "description": "简短标题，如「NVIDIA · HR Call 复盘」"],
                "company": ["type": "string", "description": "关联公司名（可选）"],
                "body": ["type": "string", "description": "心得正文"]
            ],
            required: ["body"]
        ),
        tool(
            name: "update_interview_insight",
            description: "修改一条面试心得（先用 list_interview_insights 拿 insightID）。只传要改的字段。appendBody 会追加到正文末尾，不覆盖。",
            parameters: [
                "insightID": ["type": "string"],
                "title": ["type": "string"],
                "company": ["type": "string"],
                "appendBody": ["type": "string", "description": "追加到正文末尾"]
            ],
            required: ["insightID"]
        ),
        tool(
            name: "delete_interview_insight",
            description: "删除一条面试心得（先用 list_interview_insights 拿 insightID）。仅当用户明确要求删除时使用。",
            parameters: [
                "insightID": ["type": "string"]
            ],
            required: ["insightID"]
        ),
        tool(
            name: "list_activities",
            description: """
            查看某一天的活动时间记录：每段活动的 sessionID、名称、开始/结束时间、时长，\
            以及按名称汇总的各项总时长。用户问「我今天 / 某天都干了什么、各花了多久」用这个。\
            date 不传默认今天。
            """,
            parameters: [
                "date": ["type": "string", "description": "YYYY-MM-DD，不传是今天"]
            ],
            required: []
        ),
        tool(
            name: "start_activity",
            description: """
            开始一段活动。用户说「9点开始干活 / 学习 / 写代码」这类话时用这个。\
            会自动把上一段还没结束的活动在这个时间点收尾，再开一段新的。\
            category 用活动名（干活 / 工作统一叫「工作」；做饭、散步、看博客、复习等用用户说的词）。\
            at 传开始时间 YYYY-MM-DDTHH:mm；用户没说几点就不传（默认现在）。
            """,
            parameters: [
                "category": ["type": "string", "description": "活动名，如 工作 / 做饭 / 散步 / 看博客"],
                "at": ["type": "string", "description": "开始时间 YYYY-MM-DDTHH:mm，不传为现在"],
                "note": ["type": "string", "description": "可选细节，如「写日志功能」"],
                "status": ["type": "string", "description": "可选状态，如 进行中 / 已完成 / 暂停 / 未完成"]
            ],
            required: ["category"]
        ),
        tool(
            name: "stop_activity",
            description: """
            结束当前正在进行的活动。用户说「收 / 收工了 / 结束了 / 不干了 / 去睡觉了」这类\
            只表示停下、后面没有立刻开始别的活动时用这个。at 传结束时间 YYYY-MM-DDTHH:mm，不传为现在。
            """,
            parameters: [
                "at": ["type": "string", "description": "结束时间 YYYY-MM-DDTHH:mm，不传为现在"],
                "note": ["type": "string", "description": "可选，补一句这段做了什么"]
            ],
            required: []
        ),
        tool(
            name: "update_activity",
            description: "修改一段活动记录（先用 list_activities 拿 sessionID）。只传要改的字段。endAt 传空字符串表示改回「进行中」。",
            parameters: [
                "sessionID": ["type": "string"],
                "category": ["type": "string"],
                "startAt": ["type": "string", "description": "YYYY-MM-DDTHH:mm"],
                "endAt": ["type": "string", "description": "YYYY-MM-DDTHH:mm；空字符串=进行中"],
                "note": ["type": "string"],
                "status": ["type": "string", "description": "状态，如 进行中 / 已完成 / 暂停 / 未完成"]
            ],
            required: ["sessionID"]
        ),
        tool(
            name: "delete_activity",
            description: "删除一段活动记录（先用 list_activities 拿 sessionID）。仅当用户明确要求删除时使用。",
            parameters: [
                "sessionID": ["type": "string"]
            ],
            required: ["sessionID"]
        ),
        tool(
            name: "list_todos",
            description: "列出待办清单「我要做的事」：todoID、标题、优先级(P0-P3)、分类(生活/职业)、是否完成。改待办前先看这个。",
            parameters: [:],
            required: []
        ),
        tool(
            name: "add_todo",
            description: """
            新增一条待办（「我要做的事」）。用户说「todo / 加个 todo / 提醒我做 X / 我要做 X」时必须用这个。\
            用户没说优先级时：禁止调用本工具，先问 P0/P1/P2/P3，等用户回答后再加。\
            category 不传默认 career。一句话里有多件事就分多次调用。
            """,
            parameters: [
                "title": ["type": "string", "description": "要做的事，用用户原话"],
                "priority": [
                    "type": "string",
                    "enum": ["p0", "p1", "p2", "p3"],
                    "description": "p0 最紧急 → p3 最不急；用户没说时不要传，先问"
                ],
                "category": [
                    "type": "string",
                    "enum": ["life", "career"],
                    "description": "life=生活 career=职业；不传默认 career"
                ]
            ],
            required: ["title", "priority"]
        ),
        tool(
            name: "update_todo",
            description: "修改一条待办（先用 list_todos 拿 todoID）。只传要改的字段。isDone=true 标记完成。",
            parameters: [
                "todoID": ["type": "string"],
                "title": ["type": "string"],
                "priority": ["type": "string", "enum": ["p0", "p1", "p2", "p3"]],
                "category": ["type": "string", "enum": ["life", "career"]],
                "isDone": ["type": "boolean", "description": "true=已完成 false=未完成"]
            ],
            required: ["todoID"]
        ),
        tool(
            name: "delete_todo",
            description: "删除一条待办（先用 list_todos 拿 todoID）。仅当用户明确要求删除时使用。",
            parameters: [
                "todoID": ["type": "string"]
            ],
            required: ["todoID"]
        ),
        tool(
            name: "remember_preference",
            description: """
            把用户明确说的长期偏好 / 规则 / 纠正写入跨会话记忆。\
            用户说「每次…都要…」「以后…」「记住…」「不要再…」这类可复用规则时必须立刻调用。\
            普通聊天、一次性请求、临时问题不要记。kind：preference=偏好规则，correction=纠正错误做法。
            """,
            parameters: [
                "text": ["type": "string", "description": "用一两句中文写清规则本身，不要写闲聊"],
                "kind": [
                    "type": "string",
                    "enum": ["preference", "correction", "feedback"],
                    "description": "preference=长期偏好/规则；correction=纠正错误做法；feedback=用户反馈"
                ]
            ],
            required: ["text"]
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

    private static let writeToolNames: Set<String> = [
        "upsert_company",
        "update_application",
        "add_stage_node",
        "update_stage_node",
        "delete_stage_node",
        "delete_company",
        "add_reading_item",
        "update_reading_item",
        "delete_reading_item",
        "update_document",
        "delete_document",
        "add_interview_insight",
        "update_interview_insight",
        "delete_interview_insight",
        "start_activity",
        "stop_activity",
        "update_activity",
        "delete_activity",
        "add_todo",
        "update_todo",
        "delete_todo"
    ]

    static func isWriteTool(_ name: String) -> Bool {
        writeToolNames.contains(name)
    }

    static func prepareWrite(
        name: String,
        argumentsJSON: String,
        in context: ModelContext
    ) -> PendingWrite {
        let args = (try? JSONSerialization.jsonObject(
            with: Data(argumentsJSON.utf8)
        ) as? [String: Any]) ?? [:]
        return PendingWrite(
            toolName: name,
            argumentsJSON: argumentsJSON,
            preview: previewWrite(name: name, args: args, in: context)
        )
    }

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
            case "list_interview_insights": return try listInterviewInsights(in: context)
            case "add_interview_insight": return try addInterviewInsight(args, in: context)
            case "update_interview_insight": return try updateInterviewInsight(args, in: context)
            case "delete_interview_insight": return try deleteInterviewInsight(args, in: context)
            case "list_activities": return try listActivities(args, in: context)
            case "start_activity": return try startActivity(args, in: context)
            case "stop_activity": return try stopActivity(args, in: context)
            case "update_activity": return try updateActivity(args, in: context)
            case "delete_activity": return try deleteActivity(args, in: context)
            case "list_todos": return try listTodos(in: context)
            case "add_todo": return try addTodo(args, in: context)
            case "update_todo": return try updateTodo(args, in: context)
            case "delete_todo": return try deleteTodo(args, in: context)
            case "remember_preference": return rememberPreference(args)
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

    private static func previewWrite(
        name: String,
        args: [String: Any],
        in context: ModelContext
    ) -> String {
        switch name {
        case "upsert_company":
            let raw = args["name"] as? String ?? "未命名公司"
            let company = try? findCompany(raw, in: context)
            let action = company == nil ? "新增公司" : "更新公司"
            return "\(action)「\(CompanyNameNormalizer.canonicalize(raw))」\(fieldSummary(args, excluding: ["name"]))"

        case "update_application":
            let company = args["companyName"] as? String ?? "未知公司"
            return "更新「\(CompanyNameNormalizer.canonicalize(company))」的机会信息\(fieldSummary(args, excluding: ["companyName"]))"

        case "add_stage_node":
            let company = args["companyName"] as? String ?? "未知公司"
            let title = args["title"] as? String ?? "未命名阶段"
            let date = args["date"] as? String ?? "日期未提供"
            return "给「\(CompanyNameNormalizer.canonicalize(company))」新增阶段「\(title)」· \(date)"

        case "update_stage_node":
            let node = try? findNode(args["nodeID"] as? String, in: context)
            let label = node.map { "\($0.application?.company?.name ?? "?") · \($0.title)" } ?? "未知阶段"
            return "更新阶段「\(label)」\(fieldSummary(args, excluding: ["nodeID"]))"

        case "delete_stage_node":
            let node = try? findNode(args["nodeID"] as? String, in: context)
            let label = node.map { "\($0.application?.company?.name ?? "?") · \($0.title)" } ?? "未知阶段"
            return "删除阶段「\(label)」"

        case "delete_company":
            let raw = args["companyName"] as? String ?? "未知公司"
            let company = try? findCompany(raw, in: context)
            let appCount = company?.applications?.count ?? 0
            let nodeCount = company?.applications?
                .compactMap(\.stageNodes)
                .reduce(0) { $0 + $1.count } ?? 0
            return "删除公司「\(CompanyNameNormalizer.canonicalize(raw))」及其 \(appCount) 个机会、\(nodeCount) 个阶段"

        case "add_reading_item":
            return "新增阅读收藏「\(args["title"] as? String ?? "未命名")」"

        case "update_reading_item":
            let item = try? findReadingItem(args["itemID"] as? String, in: context)
            return "更新阅读收藏「\(item?.title ?? "未知条目")」\(fieldSummary(args, excluding: ["itemID"]))"

        case "delete_reading_item":
            let item = try? findReadingItem(args["itemID"] as? String, in: context)
            return "删除阅读收藏「\(item?.title ?? "未知条目")」及其本地文件"

        case "update_document":
            let doc = try? findDocument(args["docID"] as? String, in: context)
            return "更新资料「\(doc?.title ?? "未知资料")」\(fieldSummary(args, excluding: ["docID"]))"

        case "delete_document":
            let doc = try? findDocument(args["docID"] as? String, in: context)
            return "删除资料「\(doc?.title ?? "未知资料")」及其本地文件"

        case "add_interview_insight":
            let company = (args["company"] as? String).map { "\(CompanyNameNormalizer.canonicalize($0)) · " } ?? ""
            let title = args["title"] as? String
            let label = title?.isEmpty == false ? title! : (args["body"] as? String).map { String($0.prefix(20)) } ?? "面试心得"
            return "新增面试心得「\(company)\(label)」"

        case "update_interview_insight":
            let insight = try? findInsight(args["insightID"] as? String, in: context)
            return "更新面试心得「\(insight?.displayTitle ?? "未知心得")」\(fieldSummary(args, excluding: ["insightID"]))"

        case "delete_interview_insight":
            let insight = try? findInsight(args["insightID"] as? String, in: context)
            return "删除面试心得「\(insight?.displayTitle ?? "未知心得")」"

        case "start_activity":
            let cat = args["category"] as? String ?? "活动"
            let when = ISO8601Flexible.parse(args["at"] as? String).map { activityClock($0) } ?? "现在"
            return "开始活动「\(cat)」· \(when)"

        case "stop_activity":
            let when = ISO8601Flexible.parse(args["at"] as? String).map { activityClock($0) } ?? "现在"
            let open = (try? currentOpenSession(in: context)) ?? nil
            return "结束活动「\(open?.category ?? "当前活动")」· \(when)"

        case "update_activity":
            let session = try? findActivity(args["sessionID"] as? String, in: context)
            return "更新活动「\(session?.category ?? "未知")」\(fieldSummary(args, excluding: ["sessionID"]))"

        case "delete_activity":
            let session = try? findActivity(args["sessionID"] as? String, in: context)
            return "删除活动「\(session?.category ?? "未知")」"

        case "add_todo":
            let title = args["title"] as? String ?? "待办"
            let p = (args["priority"] as? String).flatMap(TodoPriority.init(rawValue:)) ?? .p2
            let c = (args["category"] as? String).flatMap(TodoCategory.init(rawValue:)) ?? .career
            return "新增待办「\(title)」· \(p.label) · \(c.label)"

        case "update_todo":
            let todo = try? findTodo(args["todoID"] as? String, in: context)
            if let done = args["isDone"] as? Bool {
                return "\(done ? "完成" : "取消完成")待办「\(todo?.title ?? "未知待办")」"
            }
            return "更新待办「\(todo?.title ?? "未知待办")」\(fieldSummary(args, excluding: ["todoID"]))"

        case "delete_todo":
            let todo = try? findTodo(args["todoID"] as? String, in: context)
            return "删除待办「\(todo?.title ?? "未知待办")」"

        default:
            return "执行写入操作 \(name)"
        }
    }

    private static func fieldSummary(
        _ args: [String: Any],
        excluding excluded: Set<String>
    ) -> String {
        let labels: [String: String] = [
            "website": "网站",
            "contactPerson": "联系人",
            "contactEmail": "联系邮箱",
            "opinion": "看法",
            "companyDescription": "公司简介",
            "notes": "备注",
            "position": "岗位",
            "desireLevel": "想去程度",
            "appliedDate": "投递日期",
            "feedback": "反馈",
            "jobDescriptionURL": "JD 链接",
            "jobDescriptionText": "JD 内容",
            "title": "标题",
            "date": "日期",
            "bucket": "状态",
            "isInterview": "计为面试",
            "note": "备注",
            "url": "链接",
            "kind": "类型",
            "tags": "标签",
            "appendReadingNotes": "追加阅读笔记",
            "isRead": "已读状态",
            "targetCompany": "关联公司",
            "company": "关联公司",
            "body": "正文",
            "appendBody": "追加正文",
            "category": "活动",
            "startAt": "开始",
            "endAt": "结束",
            "at": "时间",
            "status": "状态",
            "priority": "优先级",
            "isDone": "完成状态"
        ]
        let values = args.keys
            .filter { !excluded.contains($0) }
            .sorted()
            .map { key -> String in
                let value = args[key].map { String(describing: $0) } ?? ""
                let compact = value.count > 80 ? String(value.prefix(80)) + "…" : value
                return "\(labels[key] ?? key)：\(compact)"
            }
        return values.isEmpty ? "" : "（\(values.joined(separator: "；"))）"
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

    // MARK: - Interview insight tools

    private static func listInterviewInsights(in context: ModelContext) throws -> ToolResult {
        let insights = try context.fetch(FetchDescriptor<InterviewInsight>())
        let rows: [[String: Any]] = insights
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { insight in
                var row: [String: Any] = [
                    "insightID": insight.id.uuidString,
                    "title": insight.displayTitle
                ]
                if let company = insight.companyName, !company.isEmpty { row["company"] = company }
                if !insight.body.isEmpty { row["body"] = String(insight.body.prefix(200)) }
                return row
            }
        return ToolResult(output: jsonString(rows), summary: nil)
    }

    private static func addInterviewInsight(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let body = (args["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            return ToolResult(output: #"{"error":"body required"}"#, summary: nil)
        }
        let company = (args["company"] as? String)?.trimmingCharacters(in: .whitespaces)
        let insight = InterviewInsight(
            title: (args["title"] as? String) ?? "",
            companyName: (company?.isEmpty == false) ? CompanyNameNormalizer.canonicalize(company!) : nil,
            body: body
        )
        context.insert(insight)
        try context.save()
        return ToolResult(
            output: #"{"ok":true,"insightID":"\#(insight.id.uuidString)"}"#,
            summary: "面试心得「\(insight.displayTitle)」"
        )
    }

    private static func updateInterviewInsight(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let insight = try findInsight(args["insightID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"insight not found，先 list_interview_insights 拿 insightID"}"#, summary: nil)
        }
        if let title = args["title"] as? String { insight.title = title }
        if let company = (args["company"] as? String)?.trimmingCharacters(in: .whitespaces) {
            insight.companyName = company.isEmpty ? nil : CompanyNameNormalizer.canonicalize(company)
        }
        if let extra = (args["appendBody"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !extra.isEmpty {
            insight.body = insight.body.isEmpty ? extra : insight.body + "\n\n" + extra
        }
        insight.updatedAt = Date()
        try context.save()
        return ToolResult(output: #"{"ok":true}"#, summary: "更新面试心得「\(insight.displayTitle)」")
    }

    private static func deleteInterviewInsight(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let insight = try findInsight(args["insightID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"insight not found"}"#, summary: nil)
        }
        let label = insight.displayTitle
        context.delete(insight)
        try context.save()
        return ToolResult(output: #"{"ok":true}"#, summary: "删除面试心得「\(label)」")
    }

    private static func findInsight(_ raw: String?, in context: ModelContext) throws -> InterviewInsight? {
        guard let raw, let id = UUID(uuidString: raw) else { return nil }
        var descriptor = FetchDescriptor<InterviewInsight>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Todo tools

    private static func listTodos(in context: ModelContext) throws -> ToolResult {
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let rows: [[String: Any]] = todos
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                if a.priorityValue.rank != b.priorityValue.rank {
                    return a.priorityValue.rank < b.priorityValue.rank
                }
                return a.createdAt < b.createdAt
            }
            .map { todo in
                [
                    "todoID": todo.id.uuidString,
                    "title": todo.title,
                    "priority": todo.priorityValue.label,
                    "category": todo.categoryValue.label,
                    "isDone": todo.isDone
                ]
            }
        return ToolResult(output: jsonString(rows), summary: nil)
    }

    private static func addTodo(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return ToolResult(output: #"{"error":"title required"}"#, summary: nil)
        }
        // 没说优先级就拒绝写入，逼着先问用户，不要静默默认成 P2。
        guard let priority = (args["priority"] as? String).flatMap(TodoPriority.init(rawValue:)) else {
            return ToolResult(
                output: #"{"error":"priority required：先问用户 P0/P1/P2/P3，再 add_todo"}"#,
                summary: nil
            )
        }
        let category = (args["category"] as? String).flatMap(TodoCategory.init(rawValue:)) ?? .career
        let todo = TodoItem(title: title, priority: priority, category: category)
        context.insert(todo)
        try context.save()
        AutoBackupService.snapshotThrottled(context: context)
        return ToolResult(
            output: #"{"ok":true,"todoID":"\#(todo.id.uuidString)"}"#,
            summary: "待办「\(title)」· \(priority.label) · \(category.label)"
        )
    }

    private static func updateTodo(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let todo = try findTodo(args["todoID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"todo not found，先 list_todos 拿 todoID"}"#, summary: nil)
        }
        if let title = (args["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            todo.title = title
        }
        if let p = (args["priority"] as? String).flatMap(TodoPriority.init(rawValue:)) {
            todo.priority = p.rawValue
        }
        if let c = (args["category"] as? String).flatMap(TodoCategory.init(rawValue:)) {
            todo.category = c.rawValue
        }
        if let done = args["isDone"] as? Bool {
            todo.isDone = done
            todo.doneAt = done ? Date() : nil
        }
        todo.updatedAt = Date()
        try context.save()
        AutoBackupService.snapshotThrottled(context: context)
        return ToolResult(output: #"{"ok":true}"#, summary: "更新待办「\(todo.title)」")
    }

    private static func deleteTodo(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let todo = try findTodo(args["todoID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"todo not found"}"#, summary: nil)
        }
        let label = todo.title
        context.delete(todo)
        try context.save()
        AutoBackupService.snapshotThrottled(context: context)
        return ToolResult(output: #"{"ok":true}"#, summary: "删除待办「\(label)」")
    }

    private static func findTodo(_ raw: String?, in context: ModelContext) throws -> TodoItem? {
        guard let raw, let id = UUID(uuidString: raw) else { return nil }
        var descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 立刻写入跨会话记忆，不走批准卡（不是数据库写）。
    private static func rememberPreference(_ args: [String: Any]) -> ToolResult {
        guard let text = (args["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return ToolResult(output: #"{"error":"text required"}"#, summary: nil)
        }
        let kindRaw = (args["kind"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "preference"
        let kind: String
        switch kindRaw {
        case "correction": kind = "correction"
        case "feedback": kind = "feedback"
        default: kind = "preference"
        }
        let ok = UserFeedbackMemoryStore.appendIfNew(kind: kind, text: text)
        guard ok else {
            return ToolResult(output: #"{"error":"memory write failed"}"#, summary: nil)
        }
        return ToolResult(
            output: #"{"ok":true,"kind":"\#(kind)"}"#,
            summary: "已记入记忆（\(kind)）"
        )
    }

    // MARK: - Activity time-tracking tools

    private static func listActivities(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        let cal = Calendar.current
        let day = ISO8601Flexible.parse(args["date"] as? String).map { cal.startOfDay(for: $0) }
            ?? cal.startOfDay(for: Date())
        let sessions = try context.fetch(FetchDescriptor<ActivitySession>())
            .filter { cal.isDate($0.startAt, inSameDayAs: day) }
            .sorted { $0.startAt < $1.startAt }

        let rows: [[String: Any]] = sessions.map { session in
            var row: [String: Any] = [
                "sessionID": session.id.uuidString,
                "category": session.category,
                "start": dateTimeString(session.startAt),
                "durationMinutes": Int(session.durationSeconds / 60),
                "ongoing": session.isOngoing
            ]
            if let end = session.endAt { row["end"] = dateTimeString(end) }
            if !session.note.isEmpty { row["note"] = session.note }
            if !session.status.isEmpty { row["status"] = session.status }
            return row
        }
        var totals: [String: Int] = [:]
        for session in sessions {
            totals[session.category, default: 0] += Int(session.durationSeconds / 60)
        }
        let payload: [String: Any] = [
            "date": dayString(day),
            "sessions": rows,
            "totalsMinutes": totals
        ]
        return ToolResult(output: jsonString(payload), summary: nil)
    }

    private static func startActivity(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let category = (args["category"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty else {
            return ToolResult(output: #"{"error":"category required"}"#, summary: nil)
        }
        let start = ISO8601Flexible.parse(args["at"] as? String) ?? Date()

        // 先把上一段还没结束的活动在这个时间点收尾。
        if let open = try currentOpenSession(in: context), open.startAt < start {
            open.endAt = start
            open.updatedAt = Date()
        }

        let session = ActivitySession(
            category: category,
            startAt: start,
            note: (args["note"] as? String) ?? "",
            status: (args["status"] as? String) ?? ""
        )
        context.insert(session)
        try context.save()
        return ToolResult(
            output: #"{"ok":true,"sessionID":"\#(session.id.uuidString)"}"#,
            summary: "开始「\(category)」\(activityClock(start))"
        )
    }

    private static func stopActivity(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let open = try currentOpenSession(in: context) else {
            return ToolResult(output: #"{"error":"没有正在进行的活动"}"#, summary: nil)
        }
        let end = ISO8601Flexible.parse(args["at"] as? String) ?? Date()
        let clamped = max(open.startAt, end)
        open.endAt = clamped
        if let note = (args["note"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            open.note = mergeText(open.note, note)
        }
        open.updatedAt = Date()
        try context.save()
        return ToolResult(
            output: #"{"ok":true}"#,
            summary: "结束「\(open.category)」\(activityClock(clamped)) · 共 \(ActivityDuration.label(open.durationSeconds))"
        )
    }

    private static func updateActivity(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let session = try findActivity(args["sessionID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"session not found，先 list_activities 拿 sessionID"}"#, summary: nil)
        }
        if let category = (args["category"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            session.category = category
        }
        if let start = ISO8601Flexible.parse(args["startAt"] as? String) {
            session.startAt = start
        }
        if let endRaw = args["endAt"] as? String {
            if endRaw.trimmingCharacters(in: .whitespaces).isEmpty {
                session.endAt = nil
            } else if let end = ISO8601Flexible.parse(endRaw) {
                session.endAt = end
            }
        }
        if let note = args["note"] as? String {
            session.note = note
        }
        if let status = args["status"] as? String {
            session.status = status
        }
        session.updatedAt = Date()
        try context.save()
        return ToolResult(output: #"{"ok":true}"#, summary: "更新活动「\(session.category)」")
    }

    private static func deleteActivity(
        _ args: [String: Any],
        in context: ModelContext
    ) throws -> ToolResult {
        guard let session = try findActivity(args["sessionID"] as? String, in: context) else {
            return ToolResult(output: #"{"error":"session not found"}"#, summary: nil)
        }
        let label = session.category
        context.delete(session)
        try context.save()
        return ToolResult(output: #"{"ok":true}"#, summary: "删除活动「\(label)」")
    }

    private static func currentOpenSession(in context: ModelContext) throws -> ActivitySession? {
        try context.fetch(FetchDescriptor<ActivitySession>())
            .filter { $0.endAt == nil }
            .sorted { $0.startAt > $1.startAt }
            .first
    }

    private static func findActivity(_ raw: String?, in context: ModelContext) throws -> ActivitySession? {
        guard let raw, let id = UUID(uuidString: raw) else { return nil }
        var descriptor = FetchDescriptor<ActivitySession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func activityClock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "M月d日 HH:mm"
        return f.string(from: date)
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

        // 1) 精确：比对键完全相等（优先，避免抢过完全同名的公司）。
        if let exact = all.first(where: {
            keys.contains(CompanyNameNormalizer.matchingKey($0.name))
                || keys.contains(CompanyNameNormalizer.matchingKey(CompanyNameNormalizer.canonicalize($0.name)))
        }) {
            return exact
        }

        // 2) 词前缀模糊：如「sierra」认出已存的「Sierra AI」，避免重复新建。
        return all.first { company in
            let names = [company.name, CompanyNameNormalizer.canonicalize(company.name)]
            return keys.contains { key in
                names.contains { CompanyNameNormalizer.isWordPrefixMatch(key, $0) }
            }
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
