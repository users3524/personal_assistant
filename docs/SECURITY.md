# 数据安全与备份现状

最后更新：2026-06-20

本文只记录当前代码中的安全和备份事实。

## 1. 本地数据

| 数据 | 存储位置 | 当前风险 |
| --- | --- | --- |
| SQLite 数据库 | `ApplicationDocumentsDirectory/personal_assistant.db` | 本地明文数据库。 |
| AI API Key | `flutter_secure_storage` 平台安全存储；`user_preferences.ai_api_key` 仅作为旧版本迁移入口保留。 | 数据库备份不再导出密钥；Web/桌面端安全强度取决于插件平台实现。 |
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

当前在线 AI 请求通过 `dio` 调用 OpenAI 兼容接口，请求内容包括日报/周报摘要、完成任务标题和用户输入文本。API Key 从安全存储读取，不再从 Drift 偏好表明文字段读取。

## 3. 备份导出

来源：`BackupService._collectData()`

当前 JSON 备份包含：

1. `user_preferences`
2. `todo_lists`
3. `todos`
4. `antique_items`
5. `valuation_records`（兼容键保留，新导出为空）
6. `patting_logs`
7. `daily_reviews`
8. `weekly_reports`
9. `resume_profile`
10. `work_experiences`
11. `educations`
12. `skill_items`
13. `project_experiences`
14. `collection_categories`

当前数据库有 14 张表，备份导出已覆盖全部存量业务表。估值功能已应用层下线，因此新备份保留 `valuation_records` 键但内容为空；`antique_items.currentValuation` 导出为 `null`。

图片处理：导出时会尝试读取 `imagePaths` / `photoPaths` 对应文件，存在则编码为 `base64:<content>`；失败则保留原路径。

密钥处理：`user_preferences.aiApiKey` 在导出 JSON 中强制写为 `null`，避免明文备份泄漏。

## 4. 备份导入

来源：`BackupService._restoreData()`

当前导入流程：

1. 读取 JSON 文件。
2. 清空当前所有业务表。
3. 按固定顺序用 `customStatement` 插入数据。
4. 将 drift `toJson()` 的 camelCase key 转为 snake_case。
5. 对日期列把毫秒时间戳转换为 Drift SQLite 使用的秒时间戳。
6. 对 `base64:` 图片解码到应用文档目录下的 `antique_images/` 或 `patting_images/`，数据库保存相对路径 token。
7. 对旧备份缺失的新增列表字段使用空列表默认值，避免历史 schema 字段缺口导致导入中断。
8. 若旧备份中包含 `user_preferences.aiApiKey` / `ai_api_key`，导入时迁移到安全存储并清空数据库字段；若备份不含密钥，覆盖导入会清空当前安全存储中的 AI Key。
9. 若旧备份中包含 `valuation_records` 或 `antique_items.currentValuation`，导入时归档到对应藏品的 `notes`，不再回灌估值表。

当前限制：

| 限制 | 说明 |
| --- | --- |
| 覆盖导入 | 导入前清空现有数据，不是合并。 |
| 表覆盖现状 | `todo_lists`、任务树字段、软删除字段、简历 List 字段、日报完成任务 ID 与周报文本字段已纳入导入导出镜像测试。 |
| 估值兼容 | 旧备份估值历史会归档到藏品备注；新备份不导出估值历史。 |
| 图片恢复目录 | Base64 图片恢复到应用文档目录，数据库保存相对路径 token。 |
| 备份文件明文 | 备份 JSON 本身无密码保护和加密；但 AI API Key 已从导出内容中剔除。 |

## 5. 通知权限

`NotificationService` 初始化本地通知，设置页首次启动会提示用户允许通知。Android 13+ 权限请求通过 `requestNotificationsPermission()`。

当前通知：

| 通知 | ID | 默认用途 |
| --- | --- | --- |
| 每日复盘 | 1001 | 每日指定时间提醒。 |
| 每周周报 | 1002 | 每周日指定时间提醒。 |
| 测试通知 | 9999 | 设置页测试。 |

## 6. 当前未实现的安全能力

1. 备份文件密码保护。
2. 专有备份包。
3. 图片目录整体备份。
4. AI 请求内容审计。
5. 数据迁移前自动备份。

## 7. 后续安全规划

| 规划 | 说明 |
| --- | --- |
| 安全存储平台验证 | 已接入 `flutter_secure_storage`；后续仍需在 Android、Windows、Web 真机/真环境逐项验证插件行为和降级提示。 |
| 配置与密钥分离 | 后续 `LLMStrategyConfig` 只保存供应商、模型名、baseUrl、预算等非敏感字段；密钥继续只通过安全存储读取。 |
| 加密备份格式 | 明文 JSON 备份不导出 API Key；若未来需要导出密钥，应提供用户确认和加密备份格式。 |
