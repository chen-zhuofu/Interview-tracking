import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CSVExporter {
    /// 导出投递列表为 CSV 文件，弹出系统保存面板。
    /// - Parameter applications: 要导出的投递列表
    static func exportApplications(_ applications: [Application]) {
        let panel = NSSavePanel()
        panel.title = "导出投递数据"
        panel.nameFieldStringValue = "applications.csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let csv = generateCSV(from: applications)
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("CSV export failed: \(error)")
            }
        }
    }

    /// 生成 CSV 字符串（UTF-8 BOM + 中文列头 + 数据行）
    private static func generateCSV(from applications: [Application]) -> String {
        var lines: [String] = []

        // UTF-8 BOM for Excel compatibility
        lines.append("\u{FEFF}公司名称,职位,薪资,投递日期,当前阶段,职位链接,备注")

        let sorted = applications.sorted { ($0.lastUpdated) > ($1.lastUpdated) }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for app in sorted {
            let companyName = escapeCSV(app.company?.name ?? "")
            let position = escapeCSV(app.position)
            let salary = "" // Not tracked — same as web version
            let appliedDate: String = {
                if let d = app.appliedDate { return formatter.string(from: d) }
                return ""
            }()
            let stageLabel = escapeCSV(app.currentStageTitle)
            let jobLink = escapeCSV(app.jobDescriptionURL ?? "")
            let notes = escapeCSV(app.notes ?? "")

            lines.append("\(companyName),\(position),\(salary),\(appliedDate),\(stageLabel),\(jobLink),\(notes)")
        }

        return lines.joined(separator: "\n")
    }

    /// 转义 CSV 字段（加双引号，内部双引号加倍）
    private static func escapeCSV(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
