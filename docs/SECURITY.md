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
2. `todo_lists`
3. `todos`
4. `antique_items`
5. `valuation_records`
6. `patting_logs`
7. `daily_reviews`
8. `weekly_reports`
9. `resume_profile`
10. `work_experiences`
11. `educations`
12. `skill_items`
13. `project_experiences`
14. `collection_categories`

当前数据库有 14 张表，备份导出已覆盖全部存量业务表。

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
7. 对旧备份缺失的新增列表字段使用空列表默认值，避免 schema v6 字段缺口导致导入中断。

当前限制：

| 限制 | 说明 |
| --- | --- |
| 覆盖导入 | 导入前清空现有数据，不是合并。 |
| 表覆盖现状 | `todo_lists`、任务树字段、软删除字段、简历 List 字段、日报完成任务 ID 与周报文本字段已纳入导入导出镜像测试。 |
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
