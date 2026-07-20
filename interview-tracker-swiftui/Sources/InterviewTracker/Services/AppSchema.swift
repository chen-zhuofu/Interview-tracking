import Foundation
import SwiftData

/// 显式版本化 Schema。把「当前结构」钉成 V1。
///
/// 为什么要这么做：默认情况下 SwiftData 启动时自己猜怎么迁移，猜不动就可能
/// 自作主张重建某张表（= 静默清空）。有了版本化 Schema + 迁移计划，迁移由我们
/// 明确规定：能轻量迁移就保数据，规定不了的改动会「打开失败」而不是「偷偷清空」。
///
/// 以后加字段的规矩：
/// - 只加可选字段（`String?`）或带默认值的字段 → 属于轻量迁移，继续留在 V1 即可。
/// - 若做了不兼容的改动（改类型、删字段、非可选无默认值），必须新开一个
///   `AppSchemaV2` 并在 `AppMigrationPlan.stages` 里补一段迁移，否则启动会报错。
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Company.self,
            Application.self,
            Interview.self,
            TimelineEvent.self,
            StageNode.self,
            MediaAttachment.self,
            ReadingItem.self,
            CareerDocument.self,
            JournalEntry.self,
            JournalTag.self,
            InterviewInsight.self,
            ActivitySession.self,
            TodoItem.self
        ]
    }
}

/// 迁移计划。目前只有 V1，没有跨版本迁移阶段。
/// 将来加 V2 时，往 `schemas` 和 `stages` 里补即可。
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

@MainActor
enum AppModelContainerFactory {
    /// 打开数据库。正常路径：按迁移计划轻量迁移，保数据。
    /// 异常路径：真的打不开（不兼容改动）时——只有在「已有快照可恢复」的前提下——
    /// 才重建空库，随后启动守卫会用快照补回数据；没有快照就直接崩溃报错，绝不盲目清空。
    static func make() -> ModelContainer {
        let schema = Schema(versionedSchema: AppSchemaV1.self)
        let config = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            print("ModelContainer 打开失败：\(error)")

            guard AutoBackupService.latestSnapshot() != nil else {
                fatalError("数据库打不开且没有可用快照，为避免盲目清空数据，停止启动。原因：\(error)")
            }

            // 有快照垫底，才允许重建空库；数据由启动守卫从快照补回。
            for suffix in ["", "-wal", "-shm"] {
                let path = config.url.path + suffix
                try? FileManager.default.removeItem(atPath: path)
            }
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: AppMigrationPlan.self,
                    configurations: config
                )
            } catch {
                fatalError("重建数据库仍失败：\(error)")
            }
        }
    }
}
