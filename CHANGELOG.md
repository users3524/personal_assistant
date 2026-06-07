# Changelog — 个人全能助手

> 自动构建 APK 下载地址：
> [GitHub Releases](https://github.com/users3524/personal_assistant/releases)

---
## v1.0.0 (2026-06-07)

**里程碑：首次成功编译 APK，可在 Android 16 真机运行**

### 新增功能
- 待办事项管理（Todo）：创建、编辑、分类、优先级、生命周期追踪
- 文玩藏品管理（Collection）：藏品录入/盘玩日志/估价记录/图片管理
- AI 日报/周报（AI Assistant）：日报复盘、周报汇总、AI 评语生成
- 动态简历（Resume）：多模板 PDF 导出、个人资料/工作/教育/技能/项目模块
- 用户设置：主题切换（浅色/深色）、AI 配置、通知、备份恢复（AES 加密）
- SQLite 本地持久化（drift 框架），12 张表的完整 CRUD

### 构建相关
- Flutter 3.44.1 / Dart 3.12.1 / JDK 17
- Gradle 9.5.1 / AGP 9.1.0
- 首次编译验证通过 ✅（APK 181MB debug 包）

---

## 开发阶段 Commit 记录
- 🔧 chore: 补全所有表文件的 library 声明，清理无用导入
- 🐛 fix: 构建环境全面升级与修复，成功编译 181MB debug APK
- 🐛 fix: bypass AAR metadata check for AGP 9.1 plugin compatibility
- 🐛 fix: force compileSdk=36 on all subprojects via withPlugin
- 🐛 fix: force all subproject compileSdk to 36 for AGP 9.1 AAR compat
- 🐛 fix: build system config for JDK 17 and AGP 9.1.0
- 🐛 fix: upgrade AGP to 9.1.0 for JDK 21 compatibility
- 🐛 fix: enable core library desugaring, disable Kotlin incremental compilation
- 🐛 fix: upgrade Gradle to 9.4.1 for Java 26 compatibility
- 🐛 fix: upgrade dependencies and fix drift codegen issues
- 🐛 fix: 修复所有导入路径和 drift 代码生成
- 🐛 fix: 修复 app_database 缺失的 import 和 drift 表解析
- 🐛 fix: 批量修复导入路径和 drift 语法问题
- 🐛 fix(build): 修复导入路径和语法错误，重新生成 drift 代码
- ✨ build(android): 新增 Android 平台支持，目标 Android 16 (API 36)
- 🐛 fix(build): 修复 resume_preview 语法错误，升级 analyzer 版本
- ♻️ refactor(dartpad): 精简代码，移除潜在兼容性问题
- 🐛 fix(dartpad): 完全重写 — 使用基础组件确保兼容性
- 🐛 fix(dartpad): 修复 ListTile style 参数和 SwitchListTile onChanged 错误
- 🐛 fix(dartpad): 修复 Map 取值类型转换错误
- 📝 docs(dartpad): 添加 DartPad 兼容版 UI 原型
- ✨ feat(backup): 创建数据备份/恢复服务（AES-256-CBC 加密）
- ✨ feat(settings): 创建设置页面 — 主题/AI配置/通知/备份/关于
- ✨ feat(ui): 创建简历编辑页和预览页（含3套模板）
- ✨ feat(repo): 创建简历仓库实现和 Riverpod Provider
- ✨ feat(dao): 创建简历模块 DAO — 5张表的完整 CRUD
- ✨ feat(db): 注册简历模块5张表并创建领域实体
- ✨ feat(ui): add daily review form, detail page, and weekly report page
- ✨ feat(ui): add ReviewHomePage with daily/weekly entry and stats
- ✨ feat(review): add repository, providers, and OpenAI service
- ✨ feat(dao): add ReviewDao for DailyReviews and WeeklyReports
- ✨ feat(db): register DailyReviews and WeeklyReports tables
- ✨ ✨ Phase 3: 文玩记录模块
- 🎉 🎉 初始化项目：个人全能助手 Flutter App

