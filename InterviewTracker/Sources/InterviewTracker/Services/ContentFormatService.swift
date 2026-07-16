import Foundation

enum ContentFormatService {
    static func formatPrompt(kind: FormatKind, text: String) -> (system: String, user: String) {
        switch kind {
        case .markdown:
            return (
                """
                你是文档整理助手。把用户粘贴的面试相关文本整理成干净的 Markdown。
                规则：保留原意；补全标题/列表/代码块；不要添加虚构内容；只输出整理后的 Markdown，不要解释。
                """,
                text
            )
        case .code:
            return (
                """
                你是代码整理助手。把用户粘贴的面试手撕代码整理整齐：合理缩进、去掉明显乱码空白、保留语言原样。
                若能判断语言，用 markdown 代码围栏包起来（如 ```python）。只输出整理后的代码，不要解释。
                """,
                text
            )
        }
    }

    enum FormatKind {
        case markdown
        case code
    }
}
