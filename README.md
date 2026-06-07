# 个人全能助手 (Personal Assistant)

一款全功能的个人生活管理 Flutter 应用。

## 📱 功能模块

| 模块 | 说明 |
|------|------|
| ✅ **待办清单** | 生活/工作双域管理、周/月视图、分类管理、统计仪表盘 |
| ✅ **文玩记录** | 藏品建档、图片管理、盘玩日志时间线、打卡对比、Banner 同步 |
| ✅ **AI 复盘** | 每日 AI 对话式复盘、每周周报自动汇总、情绪能量趋势看板 |
| ✅ **动态简历** | 原子化简历仓库、PDF 导出 |

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
personal_assistant/
├── lib/                    # Dart 源码
│   ├── app/                # 全局配置、主题、路由
│   ├── core/               # 基础设施（数据库、AI、备份）
│   │   ├── ai/             # AI 服务抽象+OpenAI实现+Provider
│   │   └── database/       # drift 数据库+备份服务+偏好DAO
│   ├── features/           # 业务模块（Feature-First + Clean Architecture）
│   │   ├── collection/     # 文玩模块（藏品/打卡/对比）
│   │   ├── todo/           # 待办模块
│   │   ├── ai_assistant/   # AI 复盘模块（对话式日报+周报）
│   │   ├── resume/         # 简历模块（编辑+预览+PDF导出）
│   │   └── settings/       # 设置页（主题/AI/备份/通知）
│   └── l10n/               # 国际化
├── android/                # Android 平台 (API 36)
├── windows/                # Windows 桌面端
├── web/                    # Web 端
├── test/                   # 单元测试
├── docs/                   # 设计文档
├── assets/                 # 静态资源（图片目录）
├── build_and_run.bat       # 一键构建+安装 APK 脚本
├── pubspec.yaml            # 依赖配置
├── analysis_options.yaml   # Dart Lint 规则
├── CHANGELOG.md            # 变更日志
└── README.md               # 本文件
```

### 根目录文件说明

| 文件 | 作用 | Git |
|------|------|-----|
| `build_and_run.bat` | 双击构建 APK + adb 安装到手机 | ✅ |
| `pubspec.yaml` | Flutter 依赖声明 | ✅ |
| `pubspec.lock` | 锁定依赖版本（保证可重现构建） | ✅ |
| `analysis_options.yaml` | Dart 静态分析规则 | ✅ |
| `CHANGELOG.md` | 版本变更日志 | ✅ |
| `README.md` | 项目说明 | ✅ |
| `.gitignore` | Git 忽略规则 | ✅ |
| `.metadata` | Flutter 项目元数据（自动生成） | ✅ |
| `.flutter-plugins-dependencies` | 插件依赖缓存（自动生成） | ❌ gitignore |
| `.idea/` `*.iml` | IDE 配置 | ❌ gitignore |
| `.dart_tool/` | Dart 工具缓存 | ❌ gitignore |
| `build/` | 构建产物 | ❌ gitignore |
| `.reasonix/` | AI 辅助工具缓存 | ❌ gitignore |

## 📄 文档

- [完整开发计划](docs/PLAN.md)
- [架构设计](docs/ARCHITECTURE.md)
- [待办模块规格](docs/SPEC_TODO.md)
- [文玩模块规格](docs/SPEC_COLLECTION.md)
- [AI 复盘模块规格](docs/SPEC_REVIEW.md)
- [简历模块规格](docs/SPEC_RESUME.md)
- [数据安全说明](docs/SECURITY.md)
