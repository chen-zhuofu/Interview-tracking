import Foundation

/// 9 阶段顺序（不可变）
let STAGE_ORDER: [String] = [
    "applied",
    "resume_screening",
    "first_interview",
    "second_interview",
    "third_interview",
    "hr_interview",
    "offer",
    "accepted",
    "rejected"
]

/// 阶段 key → 中文标签
let STAGE_LABELS: [String: String] = [
    "applied": "投递",
    "resume_screening": "简历筛选",
    "first_interview": "一面",
    "second_interview": "二面",
    "third_interview": "三面",
    "hr_interview": "HR面",
    "offer": "Offer",
    "accepted": "入职",
    "rejected": "拒绝"
]

/// 面试类型 key → 中文标签
let INTERVIEW_TYPE_LABELS: [String: String] = [
    "phone": "电话面",
    "video": "视频面",
    "onsite": "现场面"
]

/// 面试结果 key → 中文标签
let RESULT_LABELS: [String: String] = [
    "pending": "待定",
    "passed": "通过",
    "failed": "未通过"
]

/// 属于"面试中"状态的阶段集合（用于仪表盘统计）
let INTERVIEWING_STAGES: Set<String> = [
    "resume_screening",
    "first_interview",
    "second_interview",
    "third_interview",
    "hr_interview"
]
