# Roadmap

最后更新：2026-06-21

本文只写后续计划，不描述为当前已实现。

## 1. 当前基线

当前代码已实现：

| 模块 | 基线 |
| --- | --- |
| 待办 | 周/月视图、任务树、子任务、软删除、归档、统计；树查询已批量化，重新打开可清空完成/取消时间。 |
| 文玩 | 藏品、照片、盘玩打卡、月历、对比、趣味榜单；日志重型榜单已下沉到 DAO 批量聚合；默认分类含长串；估值功能已应用层下线，遗留表/列暂留兼容。 |
| AI 复盘 | 独立 `/review` 历史入口、对话式日报、ISO 周报、离线/在线 AI；日报会读取当日文玩盘玩分钟，文本输入限 500 字，语音输入 60 秒自动截断；纯文本解析失败时有可见降级；已用 `chat_turns` 实现每日 15 轮云端请求限制和熔断后的离线便签。 |
| 简历 | 三模板预览、编辑、拖拽排序、可见性、图片导出。 |
| 设置 | AI 配置、通知、分类管理、JSON 备份；API Key 已走平台安全存储。 |

## 2. AI 智能化迁移原则

以下原则来自新的智能化白皮书，只作为后续规划，不代表当前已经实现。

| 原则 | 规划价值 |
| --- | --- |
| 无损迁移优先 | 先做 Drift schema 迁移和备份兼容，再接状态拦截器和后台调度，避免破坏现有待办、文玩、复盘、简历数据。 |
| 微迁移 | 下一版 schema 不一次性释放全部 AI 表；按捕获层、生成/高光层、向量层分阶段迁移和验证。 |
| PromptBuilder 前置 | AI 策略、turn 计数、token/字符预算、裁剪和离线切换应在业务服务层完成，网络层只负责发送请求。 |
| 模型策略配置化 | 不硬编码供应商和模型名；首版扩展 `user_preferences` 保存 JSON 配置，不新增 `system_configs`，除非后续出现多配置 profile 需求。 |
| 白天低成本捕获 | 白天对话只做轻量捕获和意图提取，不读取历史日报、周报或向量记忆，减少 token 消耗和上下文污染。 |
| 本地成本闸门 | 用本地 turn 计数、输入长度限制、STT 时长限制、PromptBuilder 预算和离线便签模式，阻断无限云端请求。 |
| 日夜职责分离 | 白天收集碎片，夜间或下次打开时集中精炼成结构化日报，降低实时交互压力。 |
| 调度补偿 | 后台任务只能作为目标窗口，必须接受系统调度漂移，并在下次打开 App 时做补偿检查。 |
| 冷热数据分离 | 原始素材放入生成任务/冷数据表，日报表只保留高频读取的精炼结果和校准状态。 |
| 素材优先级裁剪 | 原始素材超限时优先保留高优已完成任务、教练式追问、文玩盘玩日志，再按时间倒序保留普通便签。 |
| 结构化输出降级 | AI 结构化解析失败时限制重试次数；失败后保存原始素材并标记待校准，避免无限重试烧 token。 |
| 高光解耦 | 高光使用独立 `milestones` 主表和多源关联表，不把单一外键过早塞进 `todos`。 |
| 项目高光多对多 | 项目经历和高光也使用 `project_milestone_relations`，支持一个项目由多个高光证据支撑。 |
| 多态清理事务 | `milestone_relations.sourceType/sourceId` 无物理外键，源数据物理删除时必须在 Repository/DAO 事务内同步清理关联。 |
| 自适应向量 | 向量记录模型名、维度和数据来源；检索前校验模型/维度兼容，不兼容则触发重建或提示。 |
| 向量性能红线 | 早期接受 SQLite BLOB + Dart O(N) 线性检索；规模上万后按年份/目标分区并移入 Isolate。 |
| 长期记忆限窗 | RAG 只取少量高相关切片，限制单片长度和总 prompt 预算，避免全量历史灌入。 |
| 简历事实约束 | STAR 润色只使用本地给定事实，禁止虚构量化结果；模型只输出纯文本，排版完全由 Flutter 模板控制。 |
| 排版确定性测试 | 未来 PDF 能力需要 TextPainter/Page Breaker/Golden Tests 等工程兜底，而不是承诺“绝不乱”。 |
| 平台隔离 | 后台调度通过 `AILogScheduler` 域接口抽象；Android 使用 WorkManager，桌面/Web 使用 No-Op + 前台补偿。 |
| 测试容差 | 未来简历导出测试采用 golden 容差、关键布局断言和语义树检查，不使用 1 像素绝对比对。 |

## 3. P0：按现有代码修正文档后的代码债

| 工作 | 说明 |
| --- | --- |
| 备份导入/导出补齐 | `todo_lists` 未覆盖；`user_preferences` 缺 `todo_categories`；`todos` 缺 `list_id/parent_id/recurrence_rule/deleted_at`；简历表缺新增 List 字段。 |
| 文玩图片路径统一 | UI 展示、分享、保存到相册和备份导出已复用 `resolveImageFile()` / `ResolvedImage`；后续继续处理备份恢复写入应用文档目录。 |
| 估值兼容收尾 | 应用层已下线估值；后续仅需在旧备份兼容稳定后评估 schema 物理移除。 |
| 复盘页限制补齐 | 已补文本 500 字、语音 60 秒、PromptBuilder 字符/token 预算、每日 15 轮云端 turn 计数和离线便签模式；后续仍需继续完善深夜素材包裁剪。 |
| 测试补齐 | 当前测试是占位，需要 DAO、Provider、迁移、备份恢复测试。 |
| API Key 安全边界 | 已接入平台安全存储并从 JSON 备份中剔除；后续需要做真机平台验证和加密备份格式评估。 |

## 4. 下一版 Schema 微迁移顺序

以下是智能化迁移的 schema 草案；其中 v9/v10 已落地，后续应继续按小版本递增释放，每个版本只覆盖一个风险面，并配套迁移、备份恢复和 DAO/Provider 测试。

| 对象 | 规划用途 | 注意事项 |
| --- | --- | --- |
| `user_preferences.ai_config` | 保存首版 `LLMStrategyConfig` JSON。 | 已在 schema v9 落地；API Key 不放 JSON，继续走安全存储。 |
| `chat_turns` | 已在 schema v10 落地，保存日间对话、离线便签、在线 turn 计数。 | `turn_date` 使用本地 `YYYY-MM-DD` 字符串；索引 `turn_date + consumes_cloud_turn` 和 `turn_date + created_at`。 |
| `review_generation_jobs` | 保存深夜生成任务、状态、`raw_assets_dump`、`attempt_count`、失败原因。 | `target_date` 使用本地 `YYYY-MM-DD`；成功 7 天后清理 raw dump。 |
| `daily_reviews.calibration_required` | 日报热表增加校准状态。 | 只保存高频读取字段，不把原始长文本塞入日报表。 |
| `milestones` | 高光中转池/正式池。 | `is_confirmed_by_user = false` 时不得直接投递正式简历。 |
| `milestone_relations` | 高光多源关联。 | `source_type/source_id` 需要应用层事务清理。`manual` 来源需设计可空 `source_id` 或单独来源表。 |
| `project_milestone_relations` | 项目经历与高光多对多。 | 避免 `project_experiences` 单外键限制。 |
| `vector_embeddings` | 向量存储。 | 需明确 Float32/Float64 编码、字节序、模型、维度和重建策略。 |

建议版本顺序：

| 版本 | 阶段 | 范围 | 验证重点 |
| --- | --- | --- |
| v10 | 捕获层 | 已新增 `chat_turns`；不改 `daily_reviews`。 | 15 轮熔断按 `role=user AND consumes_cloud_turn=true` 计数；旧备份无 `chat_turns` 时可导入为空表。 |
| v11 | 生成任务层 | 新增 `review_generation_jobs`，为 `daily_reviews` 追加 `calibration_required` 等热字段。 | Catch-Up Guard、raw dump 留存、解析降级；`daily_reviews.date` / `summary` 不改名、不改类型。 |
| v12 | 高光层 | 新增 `milestones`、`milestone_relations`、`project_milestone_relations`。 | 高光确认流、多源追溯、源数据删除时事务清理多态关联。 |
| v13 | 向量层 | 新增 `vector_embeddings` 和人生罗盘相关表/字段。 | embedding 模型/维度兼容校验、线性检索性能基准、分区/Isolate 策略。 |

存量热表保护：`daily_reviews.date` 和 `daily_reviews.summary` 是当前代码使用中的核心字段，后续迁移只做追加列，不重命名、不改类型。每个触及复盘 schema 的迁移测试都要断言这两列仍存在、类型不变，并用旧备份恢复一条日报验证语义不丢失。

## 5. P1：待办改进

| 工作 | 说明 |
| --- | --- |
| 树查询批量化 | 已完成父任务查询 + 子任务 `IN` 批量查询。 |
| 待办索引 | 已在 schema v7 补充树组装、清单筛选、活跃任务统计和今日完成统计相关索引，并用迁移测试覆盖。 |
| 清单 UI 完整化 | `todo_lists` 已有表和 DAO，UI 仍使用有限。 |
| 状态流转测试 | 已修复重新打开清空完成/取消时间；今日统计、本周完成率和拖延率已补专项测试。 |
| 多态清理预留 | 父子任务状态和软删除已事务化；未来高光关联接入后在同一事务清理 `milestone_relations`。 |

## 6. P1：文玩模块瘦身

| 工作 | 说明 |
| --- | --- |
| 图片路径统一 | UI、分享、保存到相册、备份导出和备份恢复已通过相对路径 token + 应用文档目录处理图片。 |
| 长串分类 | 已将“长串”作为默认文玩分类补入分类初始化、分类管理和文档。 |
| 估值物理移除评估 | 已评估：schema v8 继续保留 `valuation_records` 和 `current_valuation` 兼容壳；如未来物理移除，必须单独 schema 版本、迁移测试和旧备份导入测试一起释放，不和 AI 新表迁移混在同一版本。 |
| 榜单性能优化 | 已在 schema v8 为 `patting_logs` 补索引，并把日志重型榜单迁移到 DAO 批量聚合；后续仅需按真实数据规模继续观察查询计划。 |

## 7. P2：AI 助手增强

以下为剩余后续项：

| 工作 | 说明 |
| --- | --- |
| 策略配置 | 首版 `LLMStrategyConfig` JSON 复用 `user_preferences`，不引入 Hive/SharedPreferences，也暂不新增 `system_configs`。 |
| PromptBuilder 深化 | 服务层已新增并接入 OpenAI 调用；后续继续补深夜 raw context pack 的优先级裁剪策略。 |
| 成本闸门剩余项 | 文本 500 字、STT 60 秒、每日云端 turn 计数和离线便签模式已落地；后续补素材预算裁剪和深夜生成限制。 |
| 深夜日报引擎 | 后台调度目标窗口、充电/Wi-Fi 条件、下次打开 App 补偿执行、素材打包。 |
| 调度接口 | 设计纯 Dart `AILogScheduler` 接口，平台实现放到 infrastructure 层；Android WorkManager 约束不使用 `RequiresDeviceIdle`。 |
| 生成任务表 | 设计 `review_generation_jobs` 保存 `target_date` 字符串、状态、`raw_assets_dump`、失败原因和清理状态。 |
| 状态驱动补偿 | Catch-Up Guard 查询昨日 `review_generation_jobs` 状态，而不是只看 `daily_reviews` 是否存在。 |
| 原始素材留存 | 成功任务的 `raw_assets_dump` 默认保留 7 天；失败任务保留到用户手动清理。 |
| 素材裁剪器 | 8000 字左右的 raw context pack 预算，按优先级保留关键素材。 |
| 结构化输出 | JSON schema、解析失败重试、纯文本降级、`calibration_required` 标记。 |
| 高光抽取 | 高光判定门槛、单日数量上限、事实来源追踪。 |

## 8. P2：长期记忆与简历智能化

以下均未实现：

| 工作 | 说明 |
| --- | --- |
| 向量存储 | 当前无 Embedding 表或检索逻辑；后续需先选型本地向量存储、BLOB/数组编码和维度策略。 |
| 人生罗盘 | 当前无五维目标表；后续需定义固定维度、目标字段、修改冷却和存量任务迁移方式。 |
| RAG 检索限窗 | 周报/规划只取 Top-K 切片，限制单片长度和总 prompt 预算。 |
| STAR 润色 | 当前简历无 AI 生成项目 bullet。 |
| 素材池 | 当前无里程碑表；应先定义 `milestones` 和 `milestone_relations` 多源关联。 |
| 项目-高光关联 | 当前无 `project_milestone_relations`；后续用于支持一个项目关联多个高光。 |
| PDF 导出 | 当前简历只支持图片分享；PDF 前置方案已落在 `SPEC_RESUME.md`，实现时再接入 `pdf` / `printing`。 |
