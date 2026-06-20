[English](./README_EN.md) | [中文](./README.md)

<h1 align="center">📋 个人全能助手</h1>

<div align="center">

<h3>待办 · 文玩 · AI 复盘 · 动态简历 —— 你的生活工作管理中心</h3>

<p>
  <a href="https://github.com/users3524/personal_assistant/releases">
    <img alt="GitHub release" src="https://img.shields.io/github/v/release/users3524/personal_assistant?color=blue&label=版本" />
  </a>
  <a href="https://github.com/users3524/personal_assistant/blob/main/LICENSE">
    <img alt="License" src="https://img.shields.io/badge/license-暂无-blueviolet" />
  </a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" />
  <img alt="Platform" src="https://img.shields.io/badge/Android-API_28+-3DDC84?logo=android" />
  <img alt="CI" src="https://img.shields.io/badge/build-passing-brightgreen" />
</p>

<p>
基于 <strong>Flutter + Riverpod + Drift</strong> 构建的全功能本地优先生活管理工具。
一套代码覆盖 Android / Windows / Web，数据 100% 存储在设备本地。
</p>

🚧 <strong>开发中 — 功能持续完善</strong>

</div>

---

> [!WARNING]
> 本应用定位为个人工具，**不收集任何用户数据**，不上传服务器。
> AI 复盘功能仅向用户自行配置的 API 地址发送请求。
> 备份文件为明文 JSON，请用户自行妥善保管。

---

## 📑 目录

- [项目简介](#-项目简介)
- [快速开始](#-快速开始)
- [核心功能模块](#-核心功能模块)
- [技术架构](#-技术架构)
- [项目结构](#-项目结构)
- [文档索引](#-文档索引)
- [开发计划](#-开发计划)
- [隐私与安全](#-隐私与安全)
- [鸣谢](#-鸣谢)
- [许可证](#-许可证)

---

## 🎯 项目简介

**个人全能助手**是一个面向个人生活的多功能管理应用，以**本地优先、隐私安全、功能实用**为设计原则。

| 核心理念 | 说明 |
|---------|------|
| 🏠 **本地优先** | 所有数据存储于设备本地 SQLite，无需注册账号，不上传任何服务器 |
| 🔒 **隐私安全** | 无广告 SDK、无第三方统计、无崩溃分析，AI API Key 可配置任意供应商 |
| 🧩 **模块化** | 待办、文玩、AI 复盘、简历四大模块独立运作又相互打通 |
| 📱 **跨平台** | Flutter 构建，Android / Windows / Web 三端覆盖 |

### 模块联动示意图

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

---

## 🚀 快速开始

### a. 下载 APK（推荐）

前往 [GitHub Releases](https://github.com/users3524/personal_assistant/releases) 下载最新 APK 直接安装。

> [!NOTE]
> 当前仅提供 Android arm64-v8a 构建。Windows / Web 版本可通过本地构建运行。

### b. 本地构建

```bash
# 1. 安装 Flutter SDK（3.x 以上，含 Dart 3.x）
# 2. 克隆仓库
git clone https://github.com/users3524/personal_assistant.git
cd personal_assistant

# 3. 获取依赖
flutter pub get

# 4. 生成 drift 数据库代码
dart run build_runner build --delete-conflicting-outputs

# 5. 运行（连接设备或模拟器）
flutter run

# 或构建 APK
flutter build apk --debug
```

### c. 一键构建脚本

Windows 用户可直接双击 `build_and_run.bat`，自动完成构建 + 安装到已连接设备。

---

## ✨ 核心功能模块

### ✅ 待办清单
> 生活 / 工作双域管理，全生命周期追踪

- **双域切换**：底部 TabBar 切换「生活」「工作」，不同主题色区分
- **优先级 + 分类**：1-5 级优先级 + 自定义分类标签
- **生命周期追踪**：创建 → 开始 → 完成/取消，记录实际耗时与延期次数
- **多视图**：日视图、周视图、月视图，分类管理
- **统计仪表盘**：按分类/状态/优先级的完成率、耗时分布

### 🏺 文玩记录
> 藏品数字化资产管理，盘玩打卡时间线

- **藏品建档**：名称、分类、购入价格、品相、描述、多图
- **分类体系**：核桃 / 手串 / 把件 三大类，每类含细分品类 + 专属字段
- **盘玩打卡**：拍照记录 → 时间线展示，支持打卡对比（双图并排）
- **Banner 轮播**：优先展示最新打卡照片，全屏缩放查看
- **估值追踪**：fl_chart 折线图展示估值变化趋势

### 🤖 AI 复盘
> 自然语言对话式日报 + 周报自动汇总

- **对话式日报**：5 步自然语言状态机，AI 引导填写今日总结、收获、不足
- **情绪能量趋势**：可视化看板展示情绪与能量变化
- **周报自动汇总**：聚合本周日报 → AI 生成结构化周报
- **可切换供应商**：OpenAI / DeepSeek / 通义千问 / 硅基流动，API Key 本地存储
- **改进点置顶**：每日不足之处在首页 📌 置顶提醒

### 📄 动态简历
> 原子化简历仓库，多模板 PDF 导出

- **原子化数据**：个人资料、工作经历、教育背景、技能、项目经历独立管理
- **可见性控制**：每条记录可单独开关，灵活组合简历内容
- **多模板引擎**：简洁经典 / 现代卡片 / 技术极简 三套模板
- **PDF 导出**：A4 布局，调用系统分享面板保存或打印
- **一键导入周报亮点**：从 AI 周报直接导入项目经历

### ⚙️ 设置与管理
- 🌓 **主题切换**：浅色 / 深色模式，持久化到数据库
- 🔑 **AI 配置**：任意 OpenAI 兼容 API 地址 + Key + 模型选择
- 🔔 **通知管理**：定时/即时通知开关
- 💾 **备份与恢复**：纯 JSON 导出（含图片 Base64 内联），SAF 选择保存位置
- 📖 **开源许可**：内置 Flutter `showLicensePage`

---

## 🏗️ 技术架构

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&style=flat" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&style=flat" />
  <img alt="Riverpod" src="https://img.shields.io/badge/Riverpod-2.x-5C4EE5?style=flat" />
  <img alt="Drift" src="https://img.shields.io/badge/Drift-2.x-005A9C?style=flat" />
  <img alt="go_router" src="https://img.shields.io/badge/go__router-14.x-30B0D8?style=flat" />
  <img alt="Dio" src="https://img.shields.io/badge/Dio-5.x-FF4081?style=flat" />
  <img alt="fl_chart" src="https://img.shields.io/badge/fl__chart-0.68-FF6F00?style=flat" />
</p>

| 层级 | 技术 | 用途 |
|------|------|------|
| **框架** | Flutter 3.x + Dart 3.x | 跨平台 UI |
| **状态管理** | Riverpod 2.x | 编译安全、可测试、异步数据流 |
| **本地数据库** | drift + sqlite3_flutter_libs | SQLite ORM，类型安全 |
| **路由** | go_router 14.x | 声明式路由，StatefulShellRoute 保持 Tab 状态 |
| **网络** | dio 5.x | AI API HTTP 调用 |
| **图表** | fl_chart | 估值趋势、情绪能量看板 |
| **PDF** | pdf + printing | A4 简历渲染导出 |
| **通知** | flutter_local_notifications | 定时/即时提醒 |
| **国际化** | flutter_localizations + intl | .arb 多语言 |

### Feature 内部 Clean Architecture

```
feature/
├── data/                            # 数据层
│   ├── datasources/                 # DAO + drift 表定义
│   └── repositories/                # 仓库实现 + Provider
├── domain/                          # 业务层（纯 Dart，零 Flutter 依赖）
│   ├── entities/                    # 纯 Dart 实体
│   └── repositories/                # 抽象接口
└── presentation/                    # 表示层
    ├── providers/                   # Riverpod 状态
    ├── pages/                       # 页面
    └── widgets/                     # 本模块组件
```

### 数据库设计（13 张表）

| 表名 | 用途 |
|------|------|
| `user_preferences` | 用户设置（主题/AI/通知/语言） |
| `todos` | 待办事项 |
| `antique_items` | 藏品主表（含 categoryMetadata JSON） |
| `valuation_records` | 估值记录 |
| `patting_logs` | 盘玩打卡日志 |
| `daily_reviews` | 每日 AI 复盘 |
| `weekly_reports` | 每周周报 |
| `resume_profile` | 简历个人资料 |
| `work_experiences` | 工作经历 |
| `educations` | 教育经历 |
| `skill_items` | 技能项 |
| `project_experiences` | 项目经历 |

---

## 📁 项目结构

```
personal_assistant/
├── lib/                           # Dart 源码
│   ├── main.dart                  # 入口
│   ├── app/                       # 全局配置
│   │   ├── app.dart               # MaterialApp + 主题 + 路由 + 初始化
│   │   ├── router/                # go_router 路由表 + 路由名常量
│   │   └── theme/                 # 主题/色彩/字体定义
│   ├── core/                      # 基础设施
│   │   ├── ai/                    # AI 服务抽象 + OpenAI 实现 + Provider
│   │   └── database/              # drift 数据库 + 备份 + 偏好 DAO + 迁移
│   ├── features/                  # 业务模块（Feature-First）
│   │   ├── collection/            # 文玩（藏品/打卡/对比/榜单）
│   │   ├── todo/                  # 待办（双域/视图/统计）
│   │   ├── ai_assistant/          # AI 复盘（日报/周报/情绪看板）
│   │   ├── resume/                # 简历（编辑/预览/PDF/导入周报）
│   │   └── settings/              # 设置（主题/AI/通知/备份/分类管理）
│   └── l10n/                      # 国际化资源
├── android/                       # Android 平台 (API 36)
├── windows/                       # Windows 桌面端
├── web/                           # Web 端
├── test/                          # 单元测试
├── docs/                          # 设计文档（见下方索引）
├── build_and_run.bat              # 一键构建 + 安装 APK
├── pubspec.yaml                   # 依赖配置
├── analysis_options.yaml          # Dart Lint 规则
└── CHANGELOG.md                   # 版本变更日志
```

---

## 📖 文档索引

| 文档 | 内容 | 适合读者 |
|------|------|---------|
| [📄 完整开发计划](docs/PLAN.md) | 各 Phase 的开发和完成状态 | 贡献者、维护者 |
| [🗺️ 核心路线图](docs/ROADMAP.md) | v1.1.0+ 规划、当前进行中、已废弃 | 贡献者 |
| [⏳ 待实现功能](docs/TODO.md) | 已知问题与后续优化项（含优先级） | 贡献者 |
| [🏗️ 架构设计](docs/ARCHITECTURE.md) | 技术栈选型、分层架构、路由、数据库 ER | 开发者 |
| [✅ 待办模块规格](docs/SPEC_TODO.md) | 数据模型、DAO 接口、筛选查询、统计 | 模块开发者 |
| [🏺 文玩模块规格](docs/SPEC_COLLECTION.md) | 藏品/打卡/估值模型、图片存储方案、分类体系 | 模块开发者 |
| [🤖 AI 复盘模块规格](docs/SPEC_REVIEW.md) | 日报/周报模型、对话状态机、情绪分析 | 模块开发者 |
| [📄 简历模块规格](docs/SPEC_RESUME.md) | 简历数据模型、模板引擎、PDF 导出优化 | 模块开发者 |
| [🔒 数据安全说明](docs/SECURITY.md) | 敏感数据范围、备份风险、开发规范 | 所有用户 |
| [📋 变更日志](CHANGELOG.md) | 各版本的 Bug 修复和新增功能 | 用户、贡献者 |

---

## 🗺️ 开发计划

### ✅ 已完成

- [x] **Phase 1 — 脚手架与基础设施**：项目初始化、主题系统、路由表、数据库
- [x] **Phase 2 — 待办清单**：双域管理、周/月视图、分类、统计
- [x] **Phase 3 — 文玩记录**：藏品建档、盘玩打卡、估值追踪、打卡对比
- [x] **Phase 4 — AI 复盘**：对话式日报、周报自动汇总、情绪能量看板
- [x] **Phase 5 — 动态简历**：原子化数据、多模板 PDF 导出、周报导入
- [x] **Phase 6 — 集成收尾**：MainShell 5 Tab、设置页、备份恢复、v1.0.1 发布
- [x] **Phase 7 — v1.0.2 里程碑**：逾期逻辑重写、待办软删除、文玩后宫排行榜、简历三模板、技术栈编辑、仪表盘

### 🔜 规划中

详见 [ROADMAP.md](docs/ROADMAP.md) 和 [TODO.md](docs/TODO.md)，主要方向：

- **Phase 8 — 文玩轻量化**：下线估值模块，移除 fl_chart 依赖
- **Phase 9 — 四层架构**：分类→清单→任务→子任务，AI 复盘状态机
- **APK 体积瘦身**：限制单架构构建，清理 assets 目录，移除无用依赖
- **图片存储规范化**：废除 Base64 入 JSON 备份，全部改为沙盒文件存储

---

## 🔒 隐私与安全

| 措施 | 状态 |
|------|------|
| 无广告 SDK、无第三方统计、无崩溃分析 | ✅ |
| 所有数据本地 SQLite 存储，不上传任何服务器 | ✅ |
| AI API 请求仅发往用户自行配置的地址（HTTPS） | ✅ |
| AI API Key 持久化（当前明文，计划 v1.1 加密） | 🟡 |
| 备份文件为明文 JSON，用户自行保管 | ✅ |
| 图片不保留 EXIF 信息 | ✅ |
| 构建产物、IDE 配置不提交 Git | ✅ |

> [!CAUTION]
> 备份文件包含 AI API Key、个人资料、藏品价格等敏感信息，
> 请勿公开分享。建议导出后自行加密存储。

---

## 🙏 鸣谢

- [Flutter](https://flutter.dev/) — 跨平台 UI 框架
- [Riverpod](https://riverpod.dev/) — 编译安全的 Dart 状态管理
- [Drift](https://drift.simonbinder.eu/) — Dart 的 SQLite ORM
- [go_router](https://github.com/flutter/packages/tree/main/packages/go_router) — Flutter 声明式路由
- [fl_chart](https://github.com/imaNNeo/fl_chart) — Flutter 图表库
- [pdf](https://pub.dev/packages/pdf) + [printing](https://pub.dev/packages/printing) — PDF 生成与打印

---

## 📄 许可证

本项目当前**未选择正式开源许可证**，保留所有权利。

- 欢迎阅读代码和学习架构。
- 如需在其他项目中使用，请联系作者获得授权。

---

<p align="center">
  <sub>Made with ❤️ for personal productivity</sub>
  <br/>
  <a href="https://github.com/users3524/personal_assistant">
    <img src="https://moe-counter.lxchapu.com/:personal_assistant?theme=moebooru" alt="访问计数">
  </a>
</p>
