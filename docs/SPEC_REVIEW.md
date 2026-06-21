# AI 复盘模块规格

最后更新：2026-06-20

本文记录当前 AI 复盘代码现状。深夜自动日报、15 轮熔断、RAG、人生罗盘等尚未实现，放在 `ROADMAP.md` / `TODO.md`。

## 1. 当前页面与入口

| 路由 | 页面 | 当前功能 |
| --- | --- | --- |
| `/review` | `ReviewHomePage` | 独立全屏复盘历史入口，不占用底部 Tab；展示今日复盘入口、本周周报入口和本月历史记录。 |
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

## 3. 当前 AI 服务

| 类型 | 当前实现 |
| --- | --- |
| `AIService` | 定义 `generateDailyReview`、`generateWeeklyReport`、`chat`、`isAvailable`。 |
| `OfflineReviewGenerator` | 本地模板生成聊天回复、日报、周报；无需网络和 Key。 |
| `OpenAIService` | 调用 `/v1/chat/completions` 和 `/v1/models`。 |
| `AIConfigProvider` | 从 `user_preferences.ai_config` 加载 provider/baseUrl/model/预算等非敏感策略，并从安全存储读取 API Key。 |
| `AIPrompts` | 日报和周报纯文本 Prompt。 |
| `AIOutputParser` | 解析日报/周报纯文本输出；格式缺失时保留原始内容并写入用户可见的降级提示。 |

在线服务当前通过纯文本解析返回内容，没有结构化 JSON schema。若模型未按提示词分段输出，系统不会静默写入空内容，而是把原始输出放入评语/周报字段并提示用户手动整理。

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
| `allDailyReviewsProvider` | 全部日报，供历史查看。 |
| `weeklyListByYearProvider` | 当前日历年份所有周报。 |
| `currentWeekNumberProvider` | 当前 ISO 周序号。 |
| `currentIsoWeekProvider` | 当前 ISO 周年和周序号。 |

## 9. 未实现边界

以下不是当前功能：

1. 每日 15 轮云端对话限制。
2. 熔断后的离线便签模式。
3. 深夜 2:00-5:00 后台生成。
4. 充电/Wi-Fi 条件检测。
5. 原始素材 8000 字裁剪器。
6. 结构化 JSON 输出和两次重试策略。
7. 向量库、RAG、人生罗盘。
8. 自动高光里程碑与简历素材标签。

## 10. 未来规划可吸收设计

以下内容来自新的智能化白皮书，只作为后续实现方向。

取舍原则：先修复当前复盘链路的输入边界、真实文玩分钟、周报日期范围和可见降级；再建设 `PromptBuilder`、`chat_turns` 和深夜补偿任务；最后再上向量记忆与人生罗盘。RAG、WorkManager 和向量表都不应早于本地数据债清理。

### 白天捕获

| 设计 | 规划口径 |
| --- | --- |
| `LLMStrategyConfig` | 已落到 `user_preferences.ai_config` JSON 字段，保存供应商、模型、baseUrl 和预算等非敏感策略；旧 `ai_provider` / `ai_base_url` / `ai_model` 列仍作为兼容字段同步写入。 |
| `PromptBuilder` | 已新增 `core/ai/prompt_builder.dart`，负责 prompt 组装、字符/token 预算估算、文本裁剪、turn 决策和离线便签决策；当前 `OpenAIService` 已复用其 prompt 与输出 token 配置。 |
| `chat_turns` 持久化 | v10 新增 `chat_turns` 表，记录本地日期、角色、内容、是否离线、是否消耗云端请求，用于每日 turn 计数和离线便签。 |
| 15 轮熔断 | 未达到上限时允许在线 AI；达到上限后停止云端请求，输入只作为本地离线便签落盘。 |
| 零长历史上下文 | 白天请求只携带当天上下文和当天待办，不读取历史日报、周报或 RAG。 |
| Prompt 预算 | 由 prompt builder/token 估算器控制，而不是依赖 HTTP 拦截器事后截断。 |
| 输入限制 | 文本 500 字和 STT 60 秒已经在 `DailyReviewChatPage` 做本地约束；后续仍需由 `PromptBuilder` 接管更完整的预算、turn 拦截和离线切换。 |

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
| Android 约束 | WorkManager 只使用充电和 unmetered network 等高可达约束；不把 `RequiresDeviceIdle` 作为硬条件。 |
| `target_date` | 生成任务使用设备当前时区下的 `YYYY-MM-DD` 字符串，避免跨日补偿受 epoch/timezone 影响。 |
| Catch-Up Guard | App 初始化时查询昨日 `review_generation_jobs.target_date/status`；不存在、pending 或 failed 时低优先级启动补偿任务。 |
| 素材包 | 从待办、复盘对话、离线便签、文玩 `patting_logs` 中组装 raw context pack。 |
| 裁剪优先级 | 优先保留高优完成任务、教练式追问、文玩盘玩备注；普通便签按时间倒序截断。 |
| 结构化输出 | 优先要求 JSON schema；解析失败限制重试次数；最终失败写入原始素材并标记待手动校准。 |
| 冷热数据分离 | 原始素材不直接塞入 `daily_reviews`，优先设计 `review_generation_jobs` 保存 `target_date`、`status`、`raw_assets_dump`、`failure_reason`、`processed_at`。 |
| 日报热字段 | `daily_reviews` 可只扩展 `calibration_required` 等高频读取字段；原始素材由任务表定期清理或归档。 |
| 热表保活 | 当前 `daily_reviews.date` 和 `summary` 不重命名、不改类型；深夜引擎只追加字段或关联冷表。未来迁移测试必须用 `PRAGMA table_info(daily_reviews)` 断言这两列仍存在且类型不变。 |
| 原始素材留存 | 成功生成后 raw dump 默认保留 7 天再清理；失败任务不自动清理，等待用户手动处理。 |
| 调度抽象 | domain 层定义 `AILogScheduler` 接口；Android 实现 WorkManager，Windows/Web 实现 No-Op 并依赖前台补偿。 |

当前取舍：深夜引擎先实现前台 Catch-Up Guard 补偿闭环，再接 Android WorkManager。桌面/Web 不追求后台常驻。

### 长期记忆

| 设计 | 规划口径 |
| --- | --- |
| RAG 限窗 | 周报/规划只检索少量相关日报切片，限制 Top-K、单片长度和总 prompt 预算。 |
| 人生罗盘 | 固定五个长期维度可以减少目标发散，但需要设计存量待办迁移和用户编辑冷却。 |
| 向量化 | 当前没有向量表；后续需要记录 embeddingModel、dimension、sourceType/sourceId 和 vectorData 存储格式。 |
| 检索守卫 | `VectorRepository` 检索前校验模型和维度兼容；不兼容时拒绝计算并触发重建或提示。 |
| 性能分级 | 早期可用 SQLite BLOB + Dart O(N) 线性余弦检索；超过万级切片后再按年份/目标过滤并在 Isolate 中计算。 |

当前取舍：向量记忆是后置能力。`vector_embeddings.sourceType` 首版只允许当前已存在或已规划落表的业务源，避免把 `habit_log` 这类无现有表支撑的泛名提前写死。
