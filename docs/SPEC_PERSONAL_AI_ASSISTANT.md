# 寸积当前功能规格总览

最后更新：2026-06-21

本文是项目总览。它既记录当前代码事实，也记录重新整体审视后的产品边界。模块细节分别见各 `SPEC_*.md`。

## 1. 当前定位

`寸积` 是一个本地优先个人工具，核心不是“AI 聊天”，而是：

> 把行动、兴趣和复盘沉淀为可回看、可整理、可输出的个人证据。

当前最值得坚持的产品主线：

```text
待办/文玩/对话碎片
  -> 每日复盘
  -> 高光候选
  -> 项目经历 / 长期记忆 / 周报
  -> 简历或自我回顾输出
```

## 2. 模块清单

| 模块 | 当前入口 | 当前核心能力 | 下一阶段角色 |
| --- | --- | --- | --- |
| 文玩/盘串 | `/collection` | 藏品、照片、盘玩打卡、月历、照片对比、趣味榜单 | 作为兴趣和情绪调节素材来源 |
| 待办 | `/todos` | 待办树、子任务、状态流转、清单、软删除、归档、周/月视图、复盘入口 | 作为行动事实来源 |
| AI 复盘 | `/review`, `/review/daily/*`, `/review/weekly/:id` | 复盘历史、月度日历、对话日报、日报详情、ISO 周报、AI 输入边界、每日云端 turn 限制 | 下一阶段中枢 |
| 简历 | `/resume` | 三模板预览、编辑资料/经历/技能/项目、拖拽排序、可见性开关、PNG 导出 | 作为证据输出端 |
| 设置 | `/settings` | AI 配置、通知、分类管理、文玩设置、JSON 备份、许可页 | 配置和安全入口 |

不再扩张的方向：

1. 文玩估值不再作为产品能力扩展。
2. 底部 Tab 暂不增加 AI 复盘，避免主导航变重。
3. 在深夜生成和高光确认闭环完成前，不继续铺新的 AI 表。
4. 不承诺后台任务准点运行，Android WorkManager 只作为机会性触发。

## 3. 数据库现状

当前 `schemaVersion = 15`，20 张表：

| 表 | 所属模块 | 当前状态 |
| --- | --- | --- |
| `user_preferences` | 设置 | 使用中；含非敏感 AI 策略 JSON |
| `collection_categories` | 文玩/设置 | 使用中 |
| `todo_lists` | 待办 | 使用中，但仍可继续强化清单工作流 |
| `todos` | 待办 | 使用中 |
| `antique_items` | 文玩 | 使用中 |
| `patting_logs` | 文玩 | 使用中 |
| `valuation_records` | 文玩估值遗留 | 应用层已下线，新备份导出为空 |
| `daily_reviews` | AI 复盘 | 使用中 |
| `weekly_reports` | AI 复盘 | 使用中 |
| `chat_turns` | AI 复盘 | 使用中；保存对话、离线便签和云端 turn 计数 |
| `review_generation_jobs` | AI 复盘 | 使用中；保存生成任务状态和 raw dump |
| `milestones` | AI 复盘/简历素材 | 使用中；底座已落地，确认 UI 未完成 |
| `milestone_relations` | AI 复盘/简历素材 | 使用中；多源关系 |
| `resume_profile` | 简历 | 使用中 |
| `work_experiences` | 简历 | 使用中 |
| `educations` | 简历 | 使用中 |
| `skill_items` | 简历 | 使用中 |
| `project_experiences` | 简历 | 使用中 |
| `project_milestone_relations` | 简历素材 | 使用中；底座已落地，项目绑定 UI 未完成 |
| `vector_embeddings` | AI 长期记忆 | 使用中；底座已落地，embedding 生成和 RAG 链路未完成 |

## 4. 当前 AI 能力边界

已实现：

| 能力 | 当前状态 |
| --- | --- |
| 离线日报/周报模板 | 可用 |
| OpenAI 兼容 Chat Completions | 可用 |
| 多供应商配置 | OpenAI、DeepSeek、通义、硅基流动、自定义 |
| PromptBuilder | 字符预算、token 粗估、输出 token 上限 |
| 输入成本闸门 | 文本 500 字、STT 60 秒、每日 15 轮云端 user turn |
| 纯文本解析降级 | AI 未按格式输出时保留原始内容并提示用户 |
| 深夜任务状态表 | `review_generation_jobs` |
| 前台补偿 | `ReviewCatchUpGuard` 创建/保留昨日 pending 任务 |
| 结构化重试 runner | 已有 JSON -> 修复 JSON -> 纯文本降级的服务层 |
| 高光底座 | `milestones`、`milestone_relations`、候选选择和 DAO |
| 向量底座 | `vector_embeddings`、Float32 BLOB、线性检索和兼容守卫 |
| 简历 AI 安全策略 | STAR 事实约束、AI 输出清洗、PDF 布局计划底座 |

未完成的产品闭环：

| 能力 | 缺口 |
| --- | --- |
| 深夜日报生成 | raw context pack 尚未真实组包并写入日报 |
| WorkManager 回调 | 当前安全空执行，没有生成闭环 |
| 高光确认 | 没有用户确认/忽略/编辑 UI |
| 高光投递简历 | 没有项目经历选择、排序和投递入口 |
| RAG | 没有 embedding 生成、重建任务和检索入口 |
| 人生罗盘 | 只有策略服务，没有持久化表和 UI |
| PDF 导出 | 只有布局计划，未接 `pdf` / `printing` |

## 5. 当前最不合理的地方

| 问题 | 为什么不合理 | 处理原则 |
| --- | --- | --- |
| AI 底座过多但用户不可见 | schema 和服务已经复杂，产品收益还没有显现 | 优先做端到端闭环，不再先建新表 |
| TODO 全部完成但没有下一阶段 | 无法指导继续实现 | TODO 改成下一阶段 backlog |
| 后台任务容易被误解为可靠定时 | 移动系统不会保证准点运行 | UI 和文档统一称“机会性后台 + 前台补偿” |
| 文玩模块趣味性强但可能继续膨胀 | 容易偏离个人证据主线 | 保留趣味榜单，不再扩估值和复杂交易能力 |
| 简历模块还没有证据输入 | 当前仍像独立编辑器 | 先接高光投递，再做 STAR/PDF |
| 备份是明文覆盖导入 | 数据越来越多，风险变大 | 增加 manifest、预检、错误报告和可选加密 |

## 6. 文档索引

| 文档 | 记录内容 |
| --- | --- |
| `ARCHITECTURE.md` | 架构现状、整体诊断、表与依赖 |
| `PLAN.md` | 重新规划后的阶段计划 |
| `ROADMAP.md` | 中长期路线图 |
| `TODO.md` | 下一阶段可执行任务清单 |
| `SPEC_TODO.md` | 待办模块规格 |
| `SPEC_COLLECTION.md` | 文玩模块规格 |
| `SPEC_REVIEW.md` | AI 复盘规格 |
| `SPEC_RESUME.md` | 简历模块规格 |
| `SECURITY.md` | 安全与备份现状和风险 |
