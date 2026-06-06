# 个人全能助手 (Personal Assistant)

一款全功能的个人生活管理 Flutter 应用。

## 📱 功能模块

| 模块 | 说明 |
|------|------|
| ✅ **待办清单** | 生活/工作双域管理、四象限看板、日历视图、统计仪表盘 |
| 🚧 **文玩记录** | 藏品建档、图片管理、盘玩日志、估值追踪 |
| 🚧 **AI 复盘** | 每日 AI 复盘、每周自动周报、情绪与能量趋势看板 |
| 🚧 **动态简历** | 原子化简历仓库、多模板、PDF 导出 |

## 🏗️ 技术架构

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.x + Dart 3.x |
| 状态管理 | Riverpod 2.x |
| 本地数据库 | drift (SQLite) |
| 路由 | go_router |
| AI 接口 | OpenAI 兼容 API（可切换） |
| 图表 | fl_chart |
| PDF | pdf + printing |

## 🚀 快速开始

```bash
# 1. 安装 Flutter SDK（需先安装）
# 2. 获取依赖
flutter pub get

# 3. 生成 drift 数据库代码
dart run build_runner build

# 4. 运行
flutter run
```

## 📁 项目结构

```
lib/
├── app/           # 全局配置、主题、路由
├── core/          # 基础设施（数据库、AI、网络、通用组件）
└── features/      # 业务模块（Feature-First + Clean Architecture）
    ├── todo/          # 待办模块
    ├── collection/    # 文玩模块
    ├── ai_assistant/  # AI 复盘模块
    └── resume/        # 简历模块
```

## 📄 文档

- [完整开发计划](docs/PLAN.md)
- [架构设计](docs/ARCHITECTURE.md)
- [待办模块规格](docs/SPEC_TODO.md)
- [文玩模块规格](docs/SPEC_COLLECTION.md)
- [AI 复盘模块规格](docs/SPEC_REVIEW.md)
- [简历模块规格](docs/SPEC_RESUME.md)
- [数据安全说明](docs/SECURITY.md)
