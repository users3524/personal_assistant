# 数据安全与备份现状

最后更新：2026-06-20

本文只记录当前代码中的安全和备份事实。

## 1. 本地数据

| 数据 | 存储位置 | 当前风险 |
| --- | --- | --- |
| SQLite 数据库 | `ApplicationDocumentsDirectory/personal_assistant.db` | 本地明文数据库。 |
| AI API Key | `user_preferences.ai_api_key` | 明文持久化。 |
| 文玩图片/打卡图片 | 当前多处保存到应用文档目录 `antique_images/`，数据库保存路径。 | 路径和文件未加密。 |
| 轻量设置 | `ApplicationDocumentsDirectory/app_settings.json` | JSON 明文。 |
| 备份文件 | 用户选择路径或应用文档目录。 | JSON 明文，可能包含敏感信息。 |

## 2. AI 请求

当前 AI 配置支持：

| Provider | 当前配置 |
| --- | --- |
| 离线模式 | 使用 `OfflineReviewGenerator`，不发网络请求。 |
| OpenAI | `https://api.openai.com/v1`。 |
| DeepSeek | `https://api.deepseek.com`。 |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1`。 |
| 硅基流动 | `https://api.siliconflow.cn/v1`。 |
| 自定义 | 用户手动输入 baseUrl/model/key。 |

当前在线 AI 请求通过 `dio` 调用 OpenAI 兼容接口，请求内容包括日报/周报摘要、完成任务标题和用户输入文本。

## 3. 备份导出

来源：`BackupService._collectData()`

当前 JSON 备份包含：

1. `user_preferences`
2. `todos`
3. `antique_items`
4. `valuation_records`
5. `patting_logs`
6. `daily_reviews`
7. `weekly_reports`
8. `resume_profile`
9. `work_experiences`
10. `educations`
11. `skill_items`
12. `project_experiences`
13. `collection_categories`

注意：当前数据库有 14 张表，但备份导出没有包含 `todo_lists`。

图片处理：导出时会尝试读取 `imagePaths` / `photoPaths` 对应文件，存在则编码为 `base64:<content>`；失败则保留原路径。

## 4. 备份导入

来源：`BackupService._restoreData()`

当前导入流程：

1. 读取 JSON 文件。
2. 清空当前所有业务表。
3. 按固定顺序用 `customStatement` 插入数据。
4. 将 drift `toJson()` 的 camelCase key 转为 snake_case。
5. 对日期列把毫秒时间戳转换为 Drift SQLite 使用的秒时间戳。
6. 对 `base64:` 图片解码到系统临时目录 `personal_assistant_images`。

当前限制：

| 限制 | 说明 |
| --- | --- |
| 覆盖导入 | 导入前清空现有数据，不是合并。 |
| 表未覆盖 | `todo_lists` 当前没有导出，也没有导入。 |
| 表列清单落后 | `user_preferences` 导入列未包含 `todo_categories`；`todos` 未包含 `list_id`、`parent_id`、`recurrence_rule`、`deleted_at`；`work_experiences` 未包含 `responsibilities`；`project_experiences` 未包含 `key_deliverables`、`badges`。 |
| 图片恢复目录 | Base64 图片恢复到系统临时目录，不是应用文档目录。 |
| 明文 | 无密码保护和加密。 |

## 5. 通知权限

`NotificationService` 初始化本地通知，设置页首次启动会提示用户允许通知。Android 13+ 权限请求通过 `requestNotificationsPermission()`。

当前通知：

| 通知 | ID | 默认用途 |
| --- | --- | --- |
| 每日复盘 | 1001 | 每日指定时间提醒。 |
| 每周周报 | 1002 | 每周日指定时间提醒。 |
| 测试通知 | 9999 | 设置页测试。 |

## 6. 当前未实现的安全能力

1. API Key 加密存储。
2. 备份文件密码保护。
3. 专有备份包。
4. 图片目录整体备份。
5. AI 请求内容审计。
6. 数据迁移前自动备份。

## 7. 后续安全规划

| 规划 | 说明 |
| --- | --- |
| API Key 安全存储 | 当前 `user_preferences.ai_api_key` 是明文；后续应迁移到平台安全存储。Android 优先走 Keystore；Windows/Web 需要单独确认可用降级方案。 |
| 配置与密钥分离 | `LLMStrategyConfig` 只保存供应商、模型名、baseUrl、预算等非敏感字段；密钥只通过安全存储读取。 |
| 兼容迁移 | 首次升级时检测旧明文 Key，写入安全存储后清空数据库字段，并保留失败回滚提示。 |
| 备份策略 | 明文 JSON 备份不应导出 API Key；若未来需要导出，应提供用户确认和加密备份格式。 |
