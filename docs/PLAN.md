# 实施计划

最后更新：2026-06-20

当前阶段目标：以代码事实为基线维护文档，再按数据安全、备份兼容、现有链路修补、智能化增强的顺序推进实现。

## 1. 已完成的代码事实梳理

| 范围 | 结论 |
| --- | --- |
| 路由 | 主 Tab 为盘串、待办、简历；设置和复盘为全屏路由。 |
| 数据库 | `schemaVersion = 6`，14 张表。 |
| 待办 | 已有任务树、子任务、软删除、归档、统计；树查询已批量化，重新打开可清空完成/取消时间。 |
| 文玩 | 已有藏品、图片、盘玩、月历、榜单；估值已应用层下线，遗留表/列暂留兼容。 |
| AI 复盘 | 已有对话式日报和周报；日报会读取当日文玩盘玩分钟，文本输入限 500 字，语音输入 60 秒自动截断；未实现深夜后台。 |
| 简历 | 已有三模板和图片导出，未实现 PDF/STAR。 |
| 设置 | 已有 AI 配置、通知、分类管理、JSON 备份；AI API Key 已迁移到平台安全存储。 |
| 备份 | 数据库有 14 张表；`BackupService` 已覆盖全部存量业务表，并补齐 schema 6 的 `todo_lists`、任务树、软删除、简历 List 字段、日报完成任务 ID 与周报文本字段镜像测试。 |

## 2. 下一步建议顺序

1. 处理文玩图片路径统一和默认“长串”分类。
2. 接着补 AI 复盘周报日期范围查询和 AI 输出解析失败的用户可见降级。
3. 为待办今日统计、本周完成率、拖延率补专项单元测试，并评估是否需要索引迁移。
4. AI 智能化前先做 schema RFC：`chat_turns`、`review_generation_jobs`、`milestones`、`vector_embeddings`、人生罗盘相关表。
5. 再进入 15 轮限制、前台 Catch-Up Guard、深夜引擎、RAG、STAR 这类新功能。

## 3. 已吸收的智能化规划优点

| 优点 | 后续落点 |
| --- | --- |
| PromptBuilder 前置 | 把预算估算、裁剪、turn 拦截和离线切换放在业务服务层，网络层保持纯管道。 |
| 模型解耦 | 用 Drift 统一存储策略配置管理白天、深夜、embedding 模型，不硬编码供应商和模型名。 |
| 成本闸门 | 用本地 turn 计数、输入限制、离线便签和 prompt 预算控制白天 AI 成本。 |
| 调度补偿 | 接受 Android 后台任务漂移，用基于 `review_generation_jobs` 状态的 Catch-Up Guard 补偿缺失任务。 |
| 调度去虚 | WorkManager 不使用 `RequiresDeviceIdle` 作为硬条件，避免可达性过低。 |
| 冷热分离 | 原始素材进入 `review_generation_jobs`，`daily_reviews` 保持轻量热表。 |
| 证据留存 | 成功任务 raw dump 延迟 7 天清理，失败任务保留到用户手动处理。 |
| 素材裁剪 | 以高优任务、教练对话、文玩盘玩日志优先，普通便签按时间倒序截断。 |
| 失败降级 | 结构化输出失败后限制重试，保存 raw dump 并标记待手动校准。 |
| 高光解耦 | 用 `milestones` + `milestone_relations` 支持多源证据，不污染单一业务表。 |
| 项目高光多对多 | 用 `project_milestone_relations` 支持一个项目关联多个历史高光。 |
| 多态清理 | 多态关联删除由 Repository/DAO 事务保障，补上 SQLite 无法外键约束的空白。 |
| 向量元数据 | 保存 embedding 模型和维度，检索前做兼容校验。 |
| 向量性能红线 | 小规模用 O(N) 线性检索；上万级再按年/目标分区并移入 Isolate。 |
| 记忆限窗 | RAG 检索只取少量相关切片，避免全量历史进入 prompt。 |
| 简历防幻觉 | STAR 只基于本地事实，最多 3 条 bullet，AI 不控制排版。 |
| PDF 工程兜底 | 未来 PDF 以文本测量、分页算法和 golden 测试保障，而不是口头承诺。 |
| 测试抗震 | 简历导出测试采用像素容差、布局结构断言和语义树检查，降低跨平台字体渲染假阳性。 |
| 安全存储 | API Key 从明文偏好表迁移到平台安全存储，策略配置和密钥分离。 |

## 4. 代码实现前需要确认或定稿

| 问题 | 需要确认 |
| --- | --- |
| 估值物理删表 | 应用层已下线并归档旧备份；是否在后续 schema 迁移中物理移除 `valuation_records` / `current_valuation`。 |
| 备份格式 | 继续 JSON，还是改为数据库 + 图片目录包？ |
| AI 助手增强 | 已定先修当前复盘链路，再做 PromptBuilder/chat_turns，最后做深夜引擎和 RAG；具体迭代切片仍需定稿。 |
| 后台调度 | Android 后台任务能否满足 2:00-5:00、充电、Wi-Fi 的实际可靠性？ |
| 结构化输出 | 各 OpenAI 兼容供应商是否支持 JSON schema / JSON mode？不支持时如何降级？ |
| RAG 维度 | Embedding 模型和向量维度是否固定，还是随供应商配置？ |
| 高光表 | 已定优先独立 `milestones` 表和多源关联表；具体字段、确认流和迁移版本仍需定稿。 |
| 向量存储 | Drift/SQLite 中 `vectorData` 用 BLOB、JSON float array，还是接入专用本地向量扩展？ |
| 多态关联 | `milestone_relations.sourceType/sourceId` 无法用数据库外键直接约束，需要应用层校验和测试。 |
| 日期口径 | `target_date` 使用设备本地日期；跨时区旅行时是否跟随设备当前时区重算？ |
| Retention | `raw_assets_dump` 默认 7 天是否足够，是否需要用户可配置？ |
| Secure storage | 选择哪个 Flutter 插件，Windows/Web 如何降级或提示？ |
| 手动高光 | `manual` 来源的 `milestone_relations.source_id` 是否允许为空？ |
| 向量编码 | `vector_data` 使用 Float32 还是 Float64，是否存储归一化后的向量？ |
| 微迁移 | 下一版 schema 拆成几次版本递增，如何为每一步写迁移测试？ |

## 5. 协作约定

1. 提交前只 stage 本轮相关文件，避免混入无关现场改动。
2. 代码实现前先确认任务范围和验收方式。
3. 迁移、备份恢复、AI 预算控制等高风险变更必须配套测试。
4. 当前文档提交不包含无关本地现场：`build_and_run.bat`、`devtools_options.yaml`。
