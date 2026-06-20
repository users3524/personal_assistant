# TODO

最后更新：2026-06-20

本清单按当前代码事实整理。

## P0：文档校准

- [x] 以现有代码为准重写架构和模块文档。
- [x] 明确文玩估值模块当前存在，但后续不需要保留。
- [x] 把未实现的深夜引擎、RAG、人生罗盘、STAR 生成移出当前规格主体。

## P0：代码债

- [ ] 将 AI API Key 从 `user_preferences.ai_api_key` 明文迁移到平台安全存储，并设计兼容迁移。
- [ ] 将 `todo_lists` 纳入 `BackupService` 导出和导入。
- [ ] 补齐 `BackupService` 导入列清单：`user_preferences.todo_categories`。
- [ ] 补齐 `BackupService` 导入列清单：`todos.deleted_at/list_id/parent_id/recurrence_rule`。
- [ ] 补齐 `BackupService` 导入列清单：`work_experiences.responsibilities`。
- [ ] 补齐 `BackupService` 导入列清单：`project_experiences.key_deliverables/badges`。
- [ ] 决定并执行文玩估值模块移除方案。
- [ ] 移除估值后同步更新 `pubspec.yaml` 中 `fl_chart` 是否仍需要。
- [ ] 为 Drift 迁移和备份恢复补测试。
- [ ] 为 `BackupService` 增加导出-导入镜像测试，覆盖 `todo_lists`、任务树、软删除、简历 List 字段、`daily_reviews.completed_todo_ids`、`weekly_reports` 当前文本字段和日期毫秒/秒转换。

## P1：待办

- [ ] `TodoDao.getTree()` 改为父任务查询 + 子任务 IN 批量查询。
- [ ] 为待办批量树查询评估并补充 `parent_id`、`list_id`、`deleted_at/status/due_date` 等索引。
- [ ] 父任务状态和软删除改为事务级联。
- [ ] 修复 `TodoEntity.copyWith` 无法显式置空 nullable 时间字段的问题。
- [ ] 评估 `Value<T?>`、哨兵对象或独立 update command，选择一种统一 nullable 清空模式。
- [ ] 完整接入 `todo_lists` 清单 UI。
- [ ] 为今日统计、本周完成率、拖延率补单元测试。
- [ ] 为备份恢复补待办树场景测试：清单、父任务、子任务、软删除、重复策略。

## P1：文玩

- [ ] 统一图片路径策略，避免绝对路径和相对路径混用。
- [ ] 文玩默认分类新增“长串”，并补齐子类型、专属字段和备份/分类管理同步。
- [ ] 文玩 UI、分享、保存、备份导出统一通过 `resolveImageFile()` 解析图片路径。
- [ ] 移除或替换财富榜、潜力榜等估值相关榜单。
- [ ] 移除估值图表页面/组件。
- [ ] 确认估值历史数据迁移或导出策略。
- [ ] 若迁移到文本归档，使用现有字段名 `amount`/`remark`/`date`，不要误用 `val`/`note`。
- [ ] 估值模块物理删表前，先让旧备份中的 `valuation_records` 可导入并重定向归档到藏品描述/备注。
- [ ] 图片备份恢复改为应用文档目录，而不是系统临时目录。
- [ ] 评估文玩榜单从 Provider 循环计算迁移到 DAO 聚合查询，并按查询计划补 `patting_logs(item_id, date DESC)` 等索引。
- [ ] 未来高光关联接入后，删除 `patting_logs`/`antique_items` 时同步事务清理 `milestone_relations`。

## P1：AI 复盘

- [ ] 日报生成读取当日 `patting_logs` 实际盘玩分钟，而不是固定传 0。
- [ ] 为 `DailyReviewChatPage` 文本输入增加 500 字限制，避免白天对话无边界膨胀。
- [ ] 为 `speech_to_text` 录音增加 60 秒硬截断，到时自动 `stop()` 并发送已识别文本。
- [ ] 周报周数计算统一为 ISO 周或明确的本地周规则，并让 `getDailyByWeek()` 改为日期范围查询，避免全表读取和跨年误差。
- [ ] 增加 AI 输出解析失败的用户可见降级；当前纯文本解析失败时不能静默写入空内容。
- [ ] 将 `ReviewHomePage` 注册为独立 `/review` 路由作为复盘历史入口，但不新增底部 Tab，避免主导航过重。

## P1：简历

- [ ] 为 `project_experiences.key_deliverables` 增加编辑 UI。
- [ ] 为 `project_experiences.badges` 增加编辑 UI。
- [ ] 将选中模板持久化到 `user_preferences.resume_template_id`。
- [ ] 将简历 PNG 导出抽成服务，补齐 `debugNeedsPaint` 等待、分享前 mounted 检查和临时目录策略。
- [ ] 将 PDF 导出列为简历模块后续交付能力；实现前先完成 `pdf`/`printing` 依赖评估、确定性 A4 模板设计和导出测试方案。

## P2：未来 AI 助手设计

- [ ] `LLMStrategyConfig` 首版落到 `user_preferences` 的 JSON 配置字段；暂不新增 `system_configs`，除非后续出现多配置 profile 需求。
- [ ] `LLMStrategyConfig` 只保存供应商、模型、baseUrl、预算等非敏感配置；API Key 只读安全存储引用。
- [ ] 设计下一版 schema 微迁移顺序：捕获层、生成/高光层、向量层分阶段释放。
- [ ] 迁移时禁止重命名或变更 `daily_reviews.date` / `summary` 类型，只追加新列。
- [ ] 设计 `PromptBuilder` 服务层：prompt 组装、预算估算、裁剪、turn 拦截、离线切换。
- [ ] 设计 `chat_turns` 表或等价存储：日期、角色、内容、是否离线、是否消耗云端请求。
- [ ] 实现每日 15 轮在线请求限制。
- [ ] 熔断后进入离线便签模式，只本地落盘，不请求云端。
- [ ] 设计 prompt builder 和 token/字符预算估算，首版用字符/中英文比例启发式，不引入本地 tokenizer；白天禁止读取历史日报、周报、RAG。
- [ ] 设计深夜 raw context pack：待办、离线便签、复盘对话、文玩 `patting_logs`。
- [ ] 实现素材 8000 字左右优先级裁剪策略。
- [ ] 深夜引擎先实现前台 Catch-Up Guard 补偿闭环，再调研 Android 后台调度；目标窗口为 2:00-5:00、充电、Wi-Fi。
- [ ] 抽象 `AILogScheduler` 域接口，Android WorkManager 与桌面/Web No-Op 实现放到 infrastructure 层。
- [ ] Android WorkManager 只使用充电 + unmetered network 等可达约束，不把 `RequiresDeviceIdle` 作为硬条件。
- [ ] 设计 `review_generation_jobs` 冷数据表：`target_date`、`status`、`raw_assets_dump`、`attempt_count`、`failure_reason`、`processed_at`、`created_at`。
- [ ] `target_date` 使用本地时区 `YYYY-MM-DD` 字符串，不用 epoch milliseconds。
- [ ] Catch-Up Guard 基于 `review_generation_jobs.target_date/status` 补偿，不只检查 `daily_reviews`。
- [ ] `raw_assets_dump` 留存策略：success 保留 7 天，failed/pending 保留到用户手动清理。
- [ ] 为 `daily_reviews` 设计 `calibration_required` 等热字段，避免把原始素材塞入日报表。
- [ ] 深夜结构化输出总调用上限 3 次：初次 JSON、一次格式修复、一次纯文本降级；失败后标记待校准，禁止无限重试。
- [ ] 设计 `milestones` 主表和 `milestone_relations` 多源关联表。
- [ ] 明确高光来源枚举优先使用当前业务源名：`todo`、`daily_review`、`patting_log`、`manual`，避免使用无法落到现有表的泛名。
- [ ] 为 `milestone_relations.source_type = manual` 明确 `source_id` 可空策略或设计 `manual_milestone_sources`。
- [ ] 设计 `project_milestone_relations`，支持一个项目经历关联多个高光。
- [ ] 为 Todo/Review/Collection 物理删除设计事务级多态关联清理。
- [ ] 高光判定：高门槛、单日最多 2 条、允许 0 条。
- [ ] 向量记忆：选型本地向量存储、embedding 模型/维度元数据、重建策略。
- [ ] 设计 `vector_embeddings`：sourceType/sourceId、embeddingModel、dimension、vectorData；sourceType 首版使用当前业务源名，避免写入尚无表支撑的 `habit_log`。
- [ ] 明确 `vector_data` 编码格式：Float32/Float64、端序、归一化策略和版本字段。
- [ ] 检索前校验 embedding 模型和维度，不兼容时拒绝相似度计算并触发重建。
- [ ] 向量检索先实现 SQLite BLOB + Dart O(N) 余弦相似度，并记录性能基准。
- [ ] 超过万级向量后按年份/人生罗盘维度过滤，并迁移计算到 Isolate。
- [ ] 人生罗盘：固定维度、30 天修改冷却、存量根任务迁移策略。
- [ ] RAG 周报限窗：Top-K <= 5、单片 <= 400 字、总 prompt 预算约 12k tokens。
- [ ] STAR 润色事实约束、最多 3 条 bullet、代码层截断。
- [ ] AI 简历输出清洗：只允许纯文本或字符串数组，不允许样式/布局指令。
- [ ] PDF 导出前设计确定性模板、TextPainter 文本测量、分页保护和 golden 测试。
- [ ] 简历导出测试采用 golden 容差、关键布局结构断言和语义树检查，避免 1 像素绝对比对。
