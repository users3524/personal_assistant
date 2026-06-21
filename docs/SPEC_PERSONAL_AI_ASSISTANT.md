# 寸积当前功能规格总览

最后更新：2026-06-21

本文按当前代码填写，不把未实现设计写成已实现功能。后续 AI 助手增强、深夜引擎、RAG、STAR 生成等规划见 `ROADMAP.md` 和 `TODO.md`。

## 1. 当前模块清单

| 模块 | 当前入口 | 当前核心能力 |
| --- | --- | --- |
| 文玩/盘串 | `/collection` | 藏品档案、图片、分类字段、盘玩打卡、月历、照片对比、每日翻牌、趣味榜单。 |
| 待办 | `/todos` | 待办树、子任务、状态流转、软删除、归档、周/月视图、今日复盘入口。 |
| 简历 | `/resume` | 三模板预览、编辑资料/经历/技能/项目、拖拽排序、可见性开关、图片导出分享。 |
| 设置 | `/settings` | AI 配置、通知、分类管理、文玩设置、JSON 备份导入导出、许可页。 |
| AI 复盘 | `/review`, `/review/daily/*`, `/review/weekly/:id` | 独立复盘历史入口、月度复盘日历、对话式日报、日报详情、ISO 周报生成/查看、离线或在线 AI 生成、文本/STT 输入边界、PromptBuilder 预算、每日 15 轮云端请求限制。 |

## 2. 当前数据库表

当前 `schemaVersion = 15`，表结构来自 Drift 手写表定义。

| 表 | 所属模块 | 当前状态 |
| --- | --- | --- |
| `user_preferences` | 设置 | 使用中。 |
| `collection_categories` | 文玩/设置 | 使用中。 |
| `todo_lists` | 待办 | DAO 支持，UI 使用仍有限。 |
| `todos` | 待办 | 使用中。 |
| `antique_items` | 文玩 | 使用中。 |
| `patting_logs` | 文玩 | 使用中。 |
| `valuation_records` | 文玩估值遗留兼容 | 应用层已下线；新备份不导出估值历史，旧备份导入时归档到藏品备注。 |
| `daily_reviews` | AI 复盘 | 使用中。 |
| `weekly_reports` | AI 复盘 | 使用中。 |
| `chat_turns` | AI 复盘 | 使用中；保存复盘对话、离线便签和每日云端 turn 计数。 |
| `review_generation_jobs` | AI 复盘 | 使用中；保存深夜/前台补偿生成任务状态和原始素材 dump。 |
| `milestones` | AI 复盘/简历素材 | 使用中；高光主表，当前有 DAO、迁移、备份和测试。 |
| `milestone_relations` | AI 复盘/简历素材 | 使用中；高光与待办、日报、文玩打卡或手动来源的多源关系。 |
| `resume_profile` | 简历 | 使用中。 |
| `work_experiences` | 简历 | 使用中。 |
| `educations` | 简历 | 使用中。 |
| `skill_items` | 简历 | 使用中。 |
| `project_experiences` | 简历 | 使用中。 |
| `project_milestone_relations` | 简历素材 | 使用中；项目经历与多个高光的多对多关系。 |
| `vector_embeddings` | AI 长期记忆 | 使用中；保存本地 SQLite BLOB 向量、模型、维度和来源元数据。 |

schema v7 补充 `todos` 查询索引；schema v8 补充文玩 `patting_logs` 榜单和日期统计索引；schema v9 增加非敏感 AI 策略 JSON；schema v10 增加 `chat_turns`；schema v11 增加 `review_generation_jobs`；schema v12 为 `daily_reviews` 增加 `calibration_required`；schema v13-v15 依次增加高光、多对多项目高光关系和本地向量表。

## 3. 当前已实现的数据关系

```text
todos.parent_id -> todos.id
todos.list_id -> todo_lists.id
patting_logs.item_id -> antique_items.id
valuation_records.item_id -> antique_items.id
daily_reviews.completed_todo_ids -> List<String> 保存 Todo ID
project_experiences.tech_stack/key_deliverables/badges -> List<String>
work_experiences.responsibilities/tech_stack -> List<String>
```

## 4. 当前 AI 能力边界

已实现：

| 能力 | 代码位置 |
| --- | --- |
| `AIService` 抽象 | `core/ai/ai_service.dart` |
| 离线模板生成日报/周报 | `core/ai/offline_review_generator.dart` |
| OpenAI 兼容 Chat Completions 调用 | `core/ai/openai_service.dart` |
| 多供应商配置 | `settings_page.dart` |
| 日报 Prompt | `AIPrompts.dailyReviewSystemPrompt` |
| 周报 Prompt | `AIPrompts.weeklyReportSystemPrompt` |
| PromptBuilder 预算 | `PromptBuilder` 按字符预算裁剪 prompt，以 ASCII 每 4 字符约 1 token、非 ASCII 每字符约 1 token 的启发式估算成本。 |
| 纯文本解析降级 | `AIOutputParser` 保留未按格式返回的原始输出，并生成用户可见提示。 |
| 日报文玩分钟输入 | `DailyReviewChatPage` 通过 `AntiqueRepository.sumPattingMinutesByDate()` 读取当日盘玩分钟。 |
| 单次文本 500 字限制 | `DailyReviewChatPage` 输入框和发送入口共同限制。 |
| STT 60 秒截断 | `DailyReviewChatPage` 本地计时器自动停止识别并发送已识别文本。 |
| 每日 15 轮熔断 | `DailyReviewChatPage` + `chat_turns` 只统计真实云端 user turn，达到上限后转离线便签。 |

未实现：

| 能力 | 当前状态 |
| --- | --- |
| 深夜 2:00-5:00 后台引擎 | 已有 Android WorkManager 注册、No-Op 平台实现和前台 Catch-Up Guard；尚未实现 WorkManager 唤醒后的素材组包、AI 生成和日报写入闭环。 |
| 结构化 JSON 输出/重试 | 当前 OpenAI 输出仍按纯文本解析，未接入 JSON schema 和重试。 |
| RAG / 人生罗盘 | 当前无完整产品闭环；向量表、线性检索和兼容校验底座已落地，但未接入 embedding 生成与 RAG 调用链。 |
| STAR 简历生成 | 当前无 AI 简历润色流程。 |

## 5. 文玩估值模块口径

产品口径：文玩记录继续保留，估值模块不再保留为产品功能。

当前已完成应用层下线：

1. 删除 `ValuationChart` 和 `fl_chart` 依赖。
2. 删除 `ValuationRecordEntity`、估值仓库接口/实现和 `totalValuationProvider`。
3. 移除网格卡片估值展示，以及财富榜、潜力榜等估值榜单。
4. `AntiqueEntity` 不再暴露 `currentValuation`。
5. `BackupService` 新导出的 `valuation_records` 为空；旧备份导入时将 `valuation_records.date/amount/remark` 和旧 `current_valuation` 归档到 `antique_items.notes`。

暂留兼容：`valuation_records` 表和 `antique_items.current_valuation` 列仍在 schema v8 中，避免本阶段引入破坏性迁移。已评估结论是下一版 schema 不主动物理移除；若未来确需移除，应作为独立 schema 版本发布，并配套旧库升级、旧备份导入和估值归档测试。

## 6. 已吸收的未来设计原则

以下来自新的智能化规划，只作为后续方向，不属于当前功能。

| 方向 | 设计原则 |
| --- | --- |
| 数据迁移 | 先补 schema 和备份兼容，再接状态拦截器和后台调度，确保现有数据无损。 |
| 策略配置 | 模型供应商、模型名和 embedding 策略配置化；统一走 Drift 存储，不新增 Hive/SharedPreferences。 |
| PromptBuilder | 白天捕获的预算、裁剪、turn 拦截和离线切换放在业务服务层，不放在 Dio 拦截器。 |
| 白天捕获 | 低成本、短上下文、禁止历史/RAG，达到本地 turn 上限后转离线便签。 |
| 深夜精炼 | 接受后台调度漂移；用基于任务状态的打开补偿兜底；原始素材进入冷数据任务表并延迟清理。 |
| 高光拓扑 | 高光独立成表；来源和项目绑定都走多对多关联，并由应用层事务维护多态清理。 |
| 长期记忆 | RAG 检索限窗，向量记录模型/维度元数据，检索前做兼容校验；大规模后按分区和 Isolate 优化。 |
| 简历资产化 | 高光门槛高、单日数量少、STAR 只基于事实，AI 不参与排版，PDF 由确定性模板和测试保障。 |

## 7. 文档索引

| 文档 | 记录内容 |
| --- | --- |
| `ARCHITECTURE.md` | 当前项目结构、路由、数据库、依赖关系。 |
| `SPEC_TODO.md` | 当前待办功能、表、DAO、Provider、页面行为。 |
| `SPEC_COLLECTION.md` | 当前文玩功能和估值移除口径。 |
| `SPEC_REVIEW.md` | 当前 AI 复盘功能和未实现边界。 |
| `SPEC_RESUME.md` | 当前动态简历功能。 |
| `SECURITY.md` | 当前安全、备份、AI Key 风险。 |
| `ROADMAP.md` | 后续规划。 |
| `TODO.md` | 待办清单。 |
