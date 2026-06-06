# Flutter 个人全能助手 — 完整开发计划

| 项目 | 值 |
|------|------|
| 项目名 | `personal_assistant` |
| 框架 | Flutter 3.x + Dart 3.x |
| 架构 | Feature-first + Clean Architecture 分层 |
| 状态管理 | Riverpod 2.x |
| 本地数据库 | drift（SQLite 编译安全 ORM） |
| 路由 | go_router |
| 网络 | dio |
| AI 接口 | OpenAI Chat Completion API（兼容层，可换其他） |
| 图表 | fl_chart |
| PDF | pdf |
| 通知 | flutter_local_notifications |
| 图片 | image_picker + cached_network_image |

---

## Phase 1：项目脚手架与基础设施搭建

- **初始化 Flutter 项目**，配置 `pubspec.yaml`，引入核心依赖
- **搭建 Feature-First + Clean Architecture 目录结构**
- **配置主题系统**：浅色/深色双主题，用户偏好持久化
- **配置路由表**（go_router + StatefulShellRoute 保持各 Tab 状态独立）
- **设计数据库**（drift/SQLite），包含 `user_preferences` 表
- **可交付成果**：可运行的空壳 App，含主题切换 + 底部导航框架 + 数据库初始化

## Phase 2：待办清单模块（生活/工作双域）

- **定义 Todos 表**（含 `startedAt`、`cancelledAt`、`actualMinutes`、`delayCount` 等生命周期字段）
- **实现 TodoDao**：CRUD + 按分类/状态/优先级/日期范围查询 + 全文搜索 + 统计聚合
- **实现双域界面**：TabBar 切换「生活」「工作」，不同主题色区分
- **实现四象限看板**：重要-紧急矩阵，支持拖拽变更
- **实现 Slidable 操作**：左滑完成 / 右滑删除 + 撤销 Snackbar
- **实现日历视图**：月历 + 密度圆点
- **实现统计仪表盘**：今日完成率环形进度、本周完成率、拖延率卡片
- **实现本地通知**
- **可交付成果**：完整待办模块

## Phase 3：文玩记录模块（藏品数字化资产管理）

- **定义 AntiqueItems 表 + ValuationRecords 表 + PattingLogs 表**
- **实现 AntiqueDao**：CRUD + 分类/年份/品相筛选 + 全文搜索 + 关联查询
- **实现相册式浏览**：网格视图（2列），封面大图 + 名称 + 当前估值
- **实现藏品表单**：图片相对路径存储方案（使用 `path_provider` 动态拼接）
- **实现详情页**：大图轮播 + 信息卡片 + 估值走势折线图
- **实现盘玩日志页**：每日打卡 + 时间线对比「盘玩进化录」
- **实现保养提醒**
- **可交付成果**：完整文玩模块

## Phase 4：每日 AI 复盘 + 每周周报模块

- **定义 DailyReviews 表 + WeeklyReports 表**
- **实现 AI 服务抽象**：传入结构化精简文本（非全文），控制 Token 消耗
- **实现 OpenAI 实现** + 专业中文 Prompt 模板
- **实现日报流程**：定时提醒 → 展示今日完成的 Todo + 盘玩时长 → AI 评语
- **实现周报流程**：聚合本周日报精简摘要 → AI 生成结构化周报
- **实现 AI 亮点一键导入简历**
- **实现数据看板**：情绪折线图、能量叠加图、日历热力图（fl_chart）
- **可交付成果**：完整 AI 复盘模块

## Phase 5：动态简历生成模块

- **定义简历相关表**（ResumeProfile, WorkExperiences, Educations, SkillItems, ProjectExperiences）
- **实现简历引擎**：收集 `isVisible=true` 条目 → 按 `sortOrder` 排序 → 传入模板
- **实现简历编辑页**：TabBar 切换各类别，支持排序/可见性
- **实现一键导入周报亮点**
- **实现 3 套简历模板**（简洁经典 / 现代卡片 / 技术极简）
- **实现实时预览** + **PDF 导出**（字体子集化方案）
- **可交付成果**：完整简历模块

## Phase 6：集成收尾与发布准备

- **实现 MainShell**：底部导航 5 Tab，StatefulShellRoute 保持状态
- **实现设置页**：主题/AI/通知/备份/关于
- **实现数据备份恢复**：AES-256-CBC 加密导出/导入
- **实现国际化**：中英文，`.arb` 文件管理
- **配置打包**：应用图标 + 启动页 + 权限配置
- **最终集成测试**：全链路数据流验证
- **可交付成果**：生产就绪 App

---

## 模块间数据流全景

```
[待办模块: 完成任务 + 耗时/延期数据] ──(自动聚合)──┐
                                                   │
[文玩模块: 盘玩时长 + 打卡频率] ──────────────┐  ▼
                                         ├──► [AI 复盘模块]
[用户手动输入: 今日心得/不足/情绪] ────────────┘     │
                                                     ▼ (一键导入亮点)
                                               [动态简历仓库]
                                                     ▼
                                             [PDF / Markdown 导出]
```
