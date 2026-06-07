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

## Phase 2：待办清单模块（生活/工作双域） ✅ 已完成

- **定义 Todos 表**（含 `startedAt`、`cancelledAt`、`actualMinutes`、`delayCount` 等生命周期字段）
- **实现 TodoDao**：CRUD + 按分类/状态/优先级/日期范围查询 + 全文搜索 + 统计聚合
- **实现双域界面**：TabBar 切换「生活」「工作」，不同主题色区分
- **实现周/月视图** + 分类管理
- **可交付成果**：完整待办模块

## Phase 3：文玩记录模块（藏品数字化资产管理） ✅ 已完成

- **定义 AntiqueItems 表 + ValuationRecords 表 + PattingLogs 表**
- **实现 AntiqueDao**：CRUD + 分类/年份/品相筛选 + 全文搜索 + 关联查询 + 批量查询打卡照片
- **实现网格浏览**：2列网格，封面优先最新打卡照片 + 入手天数 + 分类标签
- **实现藏品表单**：Base64 图片存储 + 分类体系（核桃/手串/把件 + 细分品类 + 专属字段）
- **实现详情页**：Banner 轮播（页指示器+全屏）+ 信息卡片 + 时间线（第N天）+ 打卡对比
- **实现盘玩对话打卡**：拍照/选图 → 确认打卡日期 → 编辑/删除记录
- **实现打卡对比功能**：双图并排全屏对比 + 暗色玻璃质感 UI
- **可交付成果**：完整文玩模块

## Phase 4：每日 AI 复盘 + 每周周报模块 ✅ 已完成

- **定义 DailyReviews 表 + WeeklyReports 表**
- **实现 AI 服务抽象** + OpenAI 兼容实现 + 多供应商配置（OpenAI/DeepSeek/通义千问/硅基流动）
- **实现对话式日报**：5步自然语言对话状态机 → AI 生成评语/建议 → 改进点置顶
- **实现周报流程**：聚合本周日报 → AI 生成结构化周报
- **可交付成果**：完整 AI 复盘模块

## Phase 5：动态简历生成模块 ✅ 已完成

- **定义简历相关表**（ResumeProfile, WorkExperiences, Educations, SkillItems, ProjectExperiences）
- **实现简历编辑页** + PDF 导出
- **可交付成果**：完整简历模块

## Phase 6：集成收尾与发布准备 ✅ 已完成

- **实现 MainShell**：底部导航 5 Tab，StatefulShellRoute 保持状态
- **实现设置页**：主题/AI 配置持久化/通知/备份导出导入/关于
- **实现数据备份恢复**：纯 JSON 导出（含图片 Base64 内联）+ SAF 保存
- **配置打包**：Android APK 构建 + build_and_run.bat 一键脚本
- **可交付成果**：v1.0.1 生产就绪 App

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
