# AI 复盘模块规格

最后更新：2026-06-21

本文记录当前 AI 复盘代码现状。重新规划后，AI 复盘是项目中枢：负责把待办、对话和文玩素材沉淀成日报、高光和后续简历/长期记忆素材。

## 1. 当前页面与入口

| 路由 | 页面 | 当前功能 |
| --- | --- | --- |
| `/review` | `ReviewHomePage` | 独立全屏复盘历史入口，不占用底部 Tab；展示今日复盘入口、本周周报入口、本月历史记录和“查看全部”月度复盘日历。 |
| `/review/daily/new` | `DailyReviewChatPage` | 创建今日复盘。 |
| `/review/daily/edit/:date` | `DailyReviewChatPage(dateStr)` | 加载已有复盘并继续对话/保存。 |
| `/review/daily/:date` | `DailyReviewDetailPage` | 查看日报详情，编辑或删除。 |
| `/review/weekly/:id` | `WeeklyReportPage` | 查看/生成某周周报。 |

## 2. 数据表

### `daily_reviews`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `date` | 日期，声明唯一键。 |
| `summary` | 今日总结。 |
| `highlights` | 今日收获。 |
| `improvements` | 今日不足。 |
| `energy_level` | 能量水平 1-5。 |
| `mood_level` | 情绪水平 1-5。 |
| `completed_todo_ids` | 完成待办 ID 列表，`StringListConverter`。 |
| `patting_minutes` | 盘玩分钟数；日报生成和保存时从当日 `patting_logs.duration_minutes` 聚合写入，默认 0。 |
| `ai_comment` | AI 评语。 |
| `ai_suggestion` | AI 建议。 |
| `is_ai_generated` | 是否 AI 生成。 |
| `is_manually_edited` | 是否人工编辑。 |
| `calibration_required` | 是否需要人工校准；用于深夜结构化输出失败后的热字段标记。 |
| `created_at` / `updated_at` | 时间戳。 |

### `weekly_reports`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `week_number` | ISO 周序号。 |
| `year` | 年份。 |
| `overview` | 本周概览。 |
| `highlights` | 本周亮点。 |
| `improvements` | 待改进。 |
| `next_week_plan` | 下周计划。 |
| `is_ai_generated` | 是否 AI 生成。 |
| `is_manually_edited` | 是否人工编辑。 |
| `created_at` / `updated_at` | 时间戳。 |

### `chat_turns`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `turn_date` | 设备本地日期 `YYYY-MM-DD`，用于每日 turn 计数。 |
| `role` | `user` / `assistant` 等角色。 |
| `content` | 原始对话或离线便签文本。 |
| `is_offline` | 离线模板、未配置 Key 或达到云端 turn 上限时为 true。 |
| `consumes_cloud_turn` | 只有真实发起云端请求的 user turn 为 true。 |
| `source` | 首版默认 `daily_review_chat`。 |
| `created_at` | 写入时间。 |

### `review_generation_jobs`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `target_date` | 设备本地日期 `YYYY-MM-DD`，用于深夜/前台补偿任务去重。 |
| `status` | `pending` / `success` / `failed`。 |
| `raw_assets_dump` | 原始素材包 JSON 文本；当前只保存字段，不在启动时生成内容。 |
| `attempt_count` | 生成尝试次数。 |
| `failure_reason` | 失败原因。 |
| `processed_at` | 成功或失败处理时间。 |
| `created_at` | 任务创建时间。 |

### `milestones`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `title` | 高光标题。 |
| `description` | 高光描述。 |
| `occurred_at` | 高光发生时间。 |
| `importance_score` | 重要性评分，默认 0。 |
| `is_ai_generated` | 是否 AI 候选高光。 |
| `is_confirmed_by_user` | 是否经用户确认。 |
| `created_at` / `updated_at` | 时间戳。 |

### `milestone_relations`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `milestone_id` | 关联 `milestones.id`，删除高光时级联清理。 |
| `source_type` | 来源类型：`todo` / `daily_review` / `patting_log` / `manual`。 |
| `source_id` | 来源记录 ID；`manual` 必须为空，其他来源必须非空。 |
| `note` | 来源备注。 |
| `created_at` | 创建时间。 |

### `project_milestone_relations`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `project_id` | 关联 `project_experiences.id`。 |
| `milestone_id` | 关联 `milestones.id`。 |
| `sort_order` | 项目内高光排序。 |
| `created_at` | 创建时间。 |

### `vector_embeddings`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `source_type` / `source_id` | 向量来源，沿用 `todo` / `daily_review` / `patting_log` / `manual` 约束。 |
| `embedding_model` | 生成向量的 embedding 模型名。 |
| `dimension` | 向量维度，必须大于 0。 |
| `vector_data` | Float32 little-endian BLOB，当前编码版本 `float32_le_v1`。 |
| `storage_backend` | 当前固定 `sqlite_blob`。 |
| `encoding_version` | 当前固定 `float32_le_v1`。 |
| `content_hash` | 可选内容哈希，用于重建/去重判断。 |
| `created_at` / `updated_at` | 时间戳。 |

## 3. 当前 AI 服务

| 类型 | 当前实现 |
| --- | --- |
| `AIService` | 定义 `generateDailyReview`、`generateWeeklyReport`、`chat`、`isAvailable`。 |
| `OfflineReviewGenerator` | 本地模板生成聊天回复、日报、周报；无需网络和 Key。 |
| `OpenAIService` | 调用 `/v1/chat/completions` 和 `/v1/models`。 |
| `AIConfigProvider` | 从 `user_preferences.ai_config` 加载 provider/baseUrl/model/预算等非敏感策略，并从安全存储读取 API Key。 |
| `AIPrompts` | 日报和周报纯文本 Prompt。 |
| `PromptBuilder` | 组装日报/周报/聊天 prompt，按字符预算裁剪，按启发式估算 token，并输出各场景 `max_tokens`。 |
| `RawContextClipper` / `RawContextPackClipper` | 为深夜 raw context pack 提供约 8000 字默认预算的优先级裁剪，并能输出带 `clip` 元数据的真实素材 JSON。 |
| `ReviewCatchUpGuard` | App 初始化后在后台检查昨日 `review_generation_jobs`，缺失、pending 或 failed 时保留/创建 pending 补偿任务；不阻塞启动。 |
| `ReviewGenerationJobExecutor` | 前台执行 pending 任务入口：生成并保存 `raw_assets_dump`，调用 `NightlyStructuredReviewRunner`，成功后写入 `daily_reviews`；App 启动补偿和复盘页手动触发共用，按 `targetDate` 合并并发。 |
| `AILogScheduler` | 域层调度接口；Android infrastructure 使用 WorkManager 注册周期任务，桌面/Web 为 No-Op。 |
| `ReviewGenerationJobDao.pruneSuccessfulRawAssetDumps()` | 启动后后台清理超过 7 天的 success 任务 `raw_assets_dump`；failed/pending 原始素材保留到未来手动清理入口。 |
| `NightlyStructuredReviewRunner` | 已接入前台执行入口；初次 JSON、一次 JSON 修复、一次纯文本降级共 3 次调用上限；成功标记任务 success，失败标记 failed 并设置日报校准状态。 |
| `AIOutputParser` | 解析日报/周报纯文本输出；格式缺失时保留原始内容并写入用户可见的降级提示。 |
| `MilestoneDao` | 已支持创建高光、多源关系、按来源/确认状态查询、清理关系，以及项目经历与多个高光绑定。 |
| `VectorEmbeddingDao` | 已支持 SQLite BLOB 向量 upsert、按来源/模型读取、线性检索、索引元数据校验和按来源删除。 |

在线服务当前通过纯文本解析返回内容，没有结构化 JSON schema。若模型未按提示词分段输出，系统不会静默写入空内容，而是把原始输出放入评语/周报字段并提示用户手动整理。

当前 `PromptBuilder` 不引入本地 tokenizer：ASCII 连续片段按每 4 个字符约 1 token 估算，空白会切分 ASCII 片段；非 ASCII 字符按 1 字符约 1 token 估算。`promptBudgetChars` 是输入 prompt 的硬字符预算，裁剪时优先保留前文并追加“已按预算截断”提示；预算过小时直接截断到预算长度。`dailyReviewMaxTokens`、`weeklyReportMaxTokens`、`chatMaxTokens` 分别控制三个场景的输出 token 上限。

## 4. 当前对话式日报流程

来源：`DailyReviewChatPage`

| 步骤 | 当前实现 |
| --- | --- |
| 欢迎 | 页面初始化后添加引导消息。 |
| Step 0 | 首次输入作为 `summary`。 |
| Step 1 | 收集 `highlights`。 |
| Step 2 | 收集 `improvements`。 |
| Step 3 | 解析“情绪N 能量N”或确认默认评分。 |
| Step 4 | 调用 AI 生成评语和建议；生成后可继续聊天或保存。 |
| Step 5 | 完成保存。 |

AI 生成日报时读取 `todoRepo.getToday()`，筛选已完成任务标题作为 `completedTitles`；同时通过 `AntiqueRepository.sumPattingMinutesByDate()` 聚合复盘日期当天的文玩盘玩分钟，作为 `pattingMinutes` 传入 AI。当前聚合使用本地日期半开区间 `[dayStart, nextDay)`，避免次日 00:00 的打卡被重复计入。

当前 `DailyReviewChatPage` 文本输入框限制单次最多 500 字；发送入口也会对程序化输入（例如语音转文字结果）做同样的 500 字截断。

页面在调用云端 AI 前读取 `chat_turns` 统计当天 `role = user AND consumes_cloud_turn = true` 的 turn 数；达到 15 轮后不再请求云端，只把用户输入写成离线便签。本地 `OfflineReviewGenerator` 不消耗云端 turn。

## 5. 当前语音输入

来源：`speech_to_text`

| 能力 | 当前实现 |
| --- | --- |
| 初始化 | 点击麦克风时调用 `_speech.initialize()`。 |
| 识别 | `_speech.listen(onResult: ...)` 保存 `_lastWords`。 |
| 结束 | 停止后把 `_lastWords` 送入 `_sendMessage()`。 |
| 时长限制 | 开始识别后启动 60 秒本地计时器，到时自动停止识别并发送已识别文本。 |

当前语音限制是页面本地计时器实现，并不是 `speech_to_text` 插件或平台层的硬实时保证。

## 6. 当前日报保存

保存时构造 `DailyReviewEntity`：

| 字段 | 当前赋值 |
| --- | --- |
| `date` | 当前复盘日期。 |
| `summary` | 对话收集。 |
| `highlights` | 对话收集，空字符串转 null。 |
| `improvements` | 对话收集，空字符串转 null。 |
| `energyLevel` / `moodLevel` | 对话评分。 |
| `pattingMinutes` | 保存复盘日期当天 `patting_logs.duration_minutes` 总和。 |
| `aiComment` / `aiSuggestion` | AI 结果。 |
| `isAiGenerated` | `aiComment.isNotEmpty`。 |
| `isManuallyEdited` | 固定 false。 |

若当天已有日报则 `updateDaily()`，否则 `createDaily()`。

## 7. 当前周报

| 能力 | 当前实现 |
| --- | --- |
| 查询 | 按 ISO `year + weekNumber` 查询。 |
| 数据来源 | `ReviewRepository.getDailyByWeek()`；底层按 ISO 周一到下周一的半开日期范围查询日报。 |
| AI 输入 | `DailyReviewSummary` 列表，包含日报摘要、收获、不足、能量、情绪、完成数、盘玩分钟。 |
| 输出 | overview/highlights/improvements/nextWeekPlan 纯文本。 |

周规则统一由 `IsoWeek` 计算：周一作为一周开始，周四所在年份作为 ISO 周年。`WeeklyReportPage` 支持通过 `?year=YYYY` 指定 ISO 周年；旧 `/review/weekly/:id` 链接未带年份时默认当前 ISO 周年。

## 8. 当前统计

| Provider | 当前含义 |
| --- | --- |
| `monthlyAvgMoodProvider` | 当前月平均情绪。 |
| `monthlyAvgEnergyProvider` | 当前月平均能量。 |
| `dailyListByMonthProvider` | 当前日历年份下指定月份的日报列表，首页本月历史记录使用。 |
| `dailyListByYearMonthProvider` | 指定 `year * 100 + month` 的日报列表，月度复盘日历使用。 |
| `allDailyReviewsProvider` | 全部日报，供历史查看。 |
| `weeklyListByYearProvider` | 当前日历年份所有周报。 |
| `currentWeekNumberProvider` | 当前 ISO 周序号。 |
| `currentIsoWeekProvider` | 当前 ISO 周年和周序号。 |

`ReviewHomePage` 的“查看全部”会打开月度复盘日历弹窗。日历按周一到周日排列本月日期，有日报的日期显示情绪颜色和 emoji；点击有日报的日期会跳转到 `/review/daily/YYYY-MM-DD`。

## 9. 未实现边界

以下不是当前功能：

1. 深夜后台任务的原始素材组包与真实生成执行。
2. 运行时充电/Wi-Fi 条件检测 UI 或用户可见状态。
3. WorkManager 唤醒后的日报写入闭环。
4. embedding 自动生成、RAG、人生罗盘和用户可见长期记忆入口。
5. 自动高光抽取、确认 UI 与简历素材投递闭环。

注意：结构化 JSON -> 修复 JSON -> 纯文本降级的 runner 已通过前台执行入口接入 AI 服务和日报写入；WorkManager 回调仍待复用同一入口。

## 10. 未来规划可吸收设计

以下内容来自新的智能化白皮书，只作为后续实现方向。

取舍原则：下一阶段先打通 `review_generation_jobs` 的真实执行闭环，再做高光确认和简历投递；RAG、人生罗盘和后台条件 UI 都应后置。

### 白天捕获

| 设计 | 规划口径 |
| --- | --- |
| `LLMStrategyConfig` | 已落到 `user_preferences.ai_config` JSON 字段，保存供应商、模型、baseUrl 和预算等非敏感策略；旧 `ai_provider` / `ai_base_url` / `ai_model` 列仍作为兼容字段同步写入。 |
| `PromptBuilder` | 已新增 `core/ai/prompt_builder.dart`，负责 prompt 组装、字符/token 预算估算、文本裁剪、turn 决策和离线便签决策；当前 `OpenAIService` 已复用其 prompt 与输出 token 配置。 |
| `chat_turns` 持久化 | v10 新增 `chat_turns` 表，记录本地日期、角色、内容、是否离线、是否消耗云端请求，用于每日 turn 计数和离线便签。 |
| 15 轮熔断 | 已在 `DailyReviewChatPage` 接入；未达到上限时允许在线 AI，达到上限后停止云端请求，输入只作为本地离线便签落盘。 |
| 零长历史上下文 | 白天请求只携带当天上下文和当天待办，不读取历史日报、周报或 RAG。 |
| Prompt 预算 | 由 `PromptBuilder` 的字符预算、启发式 token 估算和场景输出 token 上限控制，而不是依赖 HTTP 拦截器事后截断。 |
| 输入限制 | 文本 500 字和 STT 60 秒已经在 `DailyReviewChatPage` 做本地约束；页面已复用 `PromptBuilder.decideDelivery()` 做云端 turn 拦截。 |

当前取舍：首版 `LLMStrategyConfig` 已扩展 `user_preferences.ai_config` 存 JSON，暂不新增 `system_configs`；首版 token 预算用字符/中英文比例估算，暂不引入本地 tokenizer。

#### `chat_turns` 表设计

| 字段 | 设计 |
| --- | --- |
| `id` | 自增主键。 |
| `turn_date` | 设备本地日期 `YYYY-MM-DD`，用于每日 turn 计数；不使用 epoch。 |
| `role` | `user` / `assistant` / `system`，首版 UI 只写 user 和 assistant。 |
| `content` | 原始对话或离线便签文本，写入前沿用当前 500 字输入限制。 |
| `is_offline` | 达到熔断、离线模式或未配置 Key 时为 true。 |
| `consumes_cloud_turn` | 只有真实发起在线模型请求的 user turn 为 true；assistant 回复和离线便签为 false。 |
| `source` | `daily_review_chat` / `manual_note` 等来源，首版默认 `daily_review_chat`。 |
| `created_at` | 写入时间。 |

索引：`chat_turns(turn_date, consumes_cloud_turn)` 用于 15 轮计数；`chat_turns(turn_date, created_at)` 用于按日恢复对话和深夜 raw context pack。

计数规则：每日在线 turn 数只统计 `role = user AND consumes_cloud_turn = true`；达到 15 后，`PromptBuilder.decideDelivery()` 返回离线便签决策，页面只落盘不请求云端。旧备份没有 `chat_turns` 时导入为空表，不影响既有日报。

### 深夜精炼

| 设计 | 规划口径 |
| --- | --- |
| 触发条件 | 2:00-5:00 作为目标窗口而非精确定时承诺；需要充电和 Wi-Fi 条件；不满足或系统漂移时在下次打开 App 后补偿执行。 |
| Android 约束 | WorkManager 已注册周期任务，只使用充电和 unmetered network 等高可达约束；不把 `RequiresDeviceIdle` 作为硬条件。 |
| `target_date` | 生成任务使用设备当前时区下的 `YYYY-MM-DD` 字符串，避免跨日补偿受 epoch/timezone 影响。 |
| Catch-Up Guard | App 初始化时查询昨日 `review_generation_jobs.target_date/status`；不存在、pending 或 failed 时低优先级启动补偿任务。 |
| 素材包 | 从待办、复盘对话、离线便签、文玩 `patting_logs` 中组装 raw context pack。 |
| 裁剪优先级 | 优先保留高优完成任务、教练式追问、文玩盘玩备注；普通便签按时间倒序截断。 |
| 结构化输出 | 优先要求 JSON schema；解析失败限制重试次数；最终失败写入原始素材并标记待手动校准。 |
| 冷热数据分离 | 原始素材不直接塞入 `daily_reviews`，优先设计 `review_generation_jobs` 保存 `target_date`、`status`、`raw_assets_dump`、`failure_reason`、`processed_at`。 |
| 日报热字段 | `daily_reviews.calibration_required` 已追加；原始素材由任务表定期清理或归档，不写入日报热表。 |
| 热表保活 | 当前 `daily_reviews.date` 和 `summary` 不重命名、不改类型；深夜引擎只追加字段或关联冷表。未来迁移测试必须用 `PRAGMA table_info(daily_reviews)` 断言这两列仍存在且类型不变。 |
| 原始素材留存 | 成功生成后 raw dump 默认保留 7 天，过期后只清空 `raw_assets_dump` 而不删除任务记录；失败和待处理任务不自动清理，等待用户手动处理。 |
| 调度抽象 | domain 层已定义 `AILogScheduler` 接口；Android infrastructure 实现 WorkManager，Windows/Web 实现 No-Op 并依赖前台补偿。 |

当前取舍：深夜引擎已实现前台 Catch-Up Guard、Android WorkManager 注册、任务冷表、结构化 runner、真实素材组包、raw pack 裁剪、前台 pending job 执行入口和日报写入；WorkManager 回调当前只做安全空执行，任务状态 UI 仍按 TODO 分步接入。桌面/Web 不追求后台常驻。

#### Raw Context Pack 设计

`raw context pack` 是深夜生成任务的原始输入包，按目标本地日期 `target_date = YYYY-MM-DD` 组装。首版只读取当前已有热数据，不读取历史日报、周报、RAG 或向量记忆。

| 分区 | 数据来源 | 首版字段 | 排序与过滤 |
| --- | --- | --- | --- |
| `todos` | `todos` / `TodoDao` | `id`、`title`、`status`、`priority`、`due_date`、`completed_at`、`actual_minutes`、`tags` | 只取目标日期相关的已完成、逾期或活跃任务；已完成任务优先，按优先级和完成时间排序。 |
| `chat_turns` | `chat_turns` / `ChatTurnDao.getByDate()` | `role`、`content`、`is_offline`、`consumes_cloud_turn`、`source`、`created_at` | 只取目标日期；按 `created_at ASC` 保留对话顺序；离线便签和云端 user turn 都进入素材。 |
| `daily_review_draft` | `daily_reviews` / 当前对话收集结果 | `summary`、`highlights`、`improvements`、`energy_level`、`mood_level`、`patting_minutes` | 若目标日期已有日报，作为校准/补全素材；不把长篇 raw pack 回写进 `daily_reviews`。 |
| `patting_logs` | `patting_logs` / `AntiqueDao.getPattingLogsByDate()` | `id`、`item_id`、`date`、`duration_minutes`、`method`、`note`、`photo_count` | 只取目标日期半开区间 `[dayStart, nextDay)`；优先保留有备注、时长较长的记录；图片只记录数量或相对路径摘要，不内联 base64。 |

输出形态首版为 JSON 对象，至少包含 `target_date`、`generated_at`、`timezone_offset_minutes` 和上述分区数组。隐私边界：API Key、图片 base64、备份文件路径、平台安全存储引用都不得进入 raw pack。

`RawContextClipper` 已实现首版裁剪策略，默认预算为 8000 字符。排序规则优先保留高优已完成任务，其次保留教练式对话/云端 user turn、有备注的文玩打卡、日报草稿和普通离线便签；同分素材按 `created_at` 倒序保留较新的内容。空内容会被丢弃，超预算素材整体丢弃而不拆分。`RawContextPackClipper` 已接入真实 raw pack，输出仍是可解析 JSON，并在 `clip` 中记录 `input_chars`、`kept_chars`、保留项摘要和丢弃原因；`ReviewGenerationJobExecutor` 已把该 JSON 保存到 pending job 的 `raw_assets_dump`，并交给 runner 生成日报 AI 输出。

### 长期记忆

| 设计 | 规划口径 |
| --- | --- |
| RAG 限窗 | 周报/规划只检索少量相关日报切片，限制 Top-K、单片长度和总 prompt 预算。 |
| 人生罗盘 | 固定五个长期维度可以减少目标发散，但需要设计存量待办迁移和用户编辑冷却。 |
| 向量化 | `vector_embeddings` 表、Float32 BLOB 编码、模型/维度元数据和线性检索守卫已落地；后续仍需接入 embedding 生成、重建任务和 RAG 使用链。 |
| 检索守卫 | `VectorRepository` 检索前校验模型和维度兼容；不兼容时拒绝计算并触发重建或提示。 |
| 性能分级 | 早期可用 SQLite BLOB + Dart O(N) 线性余弦检索；超过万级切片后再按年份/目标过滤并在 Isolate 中计算。 |

当前取舍：向量记忆是后置能力。`vector_embeddings.sourceType` 首版只允许当前已存在或已规划落表的业务源，避免把 `habit_log` 这类无现有表支撑的泛名提前写死。

## 11. 下一阶段规划

| 工作 | 原因 | 验收 |
| --- | --- | --- |
| 任务状态 UI | 用户需要知道为什么没生成或需校准 | pending/failed/calibrationRequired 在 `/review` 可见 |
| 高光候选 | 复盘是高光来源中枢 | 单日最多 2 条，允许 0 条，来源可追溯 |
