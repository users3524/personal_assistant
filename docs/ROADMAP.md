# 🗺️ 个人全能助手 — 核心开发计划 (Roadmap v1.1.0+)

---

## 📌 当前进行中：Phase 8 & 9 — 基础设施演进与待办/AI深度重构

应用架构正从扁平单表向多层级关系型存储平滑迁移，彻底剔除低频与高内存隐患功能。

---

### 1. 🗑️ 功能做减法：文玩模块轻量化

- [ ] 彻底下线"文玩估值模块"（`valuation_records` 表、`ValuationRecords` 实体、`fl_chart` 图表）
- [ ] 从 `pubspec.yaml` 中移除 `fl_chart` 依赖，减少 APK 体积
- [ ] 物理销毁 `valuation_records` 数据表，编写 Drift schema migration 清理列
- [ ] 移除阅历页面中死板的全部 Tab 切换，改为每日随机展示 1~3 个趣味榜单

### 2. 📋 待办功能多层级重构（最高优先级）

- [x] 底层引入 `TodoLists`（清单表）与 `Todos` 自关联外键 `parentId`
- [ ] 架构演进：建立 **分类 → 清单 → 任务 → 子任务** 四层控制流
- [ ] 清单管理 UI：支持创建/重命名/删除清单，清单按分类分组
- [x] 数据隔离：主仪表盘（`TodoStatsCard`）统计分母强制限制 `WHERE parent_id IS NULL`
- [x] 修复 Flutter 侧滑报错：`Dismissible` 组件 stable `Key` 绑定 + 乐观更新
- [x] 子任务创建入口：详情页右上角菜单 + AlertDialog + Notifier

### 3. 🧠 AI 与待办深度互通：真正的复盘状态机

- [ ] 剔除单纯的文本日报。5 步复盘状态机启动时，由 DAO 自动查询【今日已完成高优】与【今日逾期/活跃】硬数据
- [ ] 将硬数据作为 Context 组装入 System Prompt 喂给大模型，实现 AI 引导的"动态复盘与原因分析"
- [ ] 逆向回流闭环：AI 依据复盘结果生成结构化 JSON，用户点击采纳后，自动调用 `TodoRepository.create()` 反向生成明天的计划任务

### 4. 🛠️ 图片上传逻辑修复与本地存储防御

- [ ] 彻底废除 Base64 塞入 JSON 备份的 OOM 隐患设计，禁止将图片以 Blob 形式直存 SQLite
- [ ] 引入沙盒模式：图片上传时生成唯一文件名，异步拷贝至 `ApplicationDocumentsDirectory/images/` 目录下
- [ ] 数据库字段仅保留相对路径，UI 层通过全局工具类 `resolveImageFile` 动态拼接绝对路径（已部分完成）
- [ ] 旧数据迁移脚本：将存量 `imagePaths`/`photoPaths` 中的绝对路径批量转换为相对路径

### 5. ⚙️ 基础设施优化

- [ ] APK 体积瘦身：移除 `fl_chart`、审查 `assets/` 目录、定期 `flutter clean`
- [ ] 编写严谨的 Drift Schema `MigrationStrategy`，确保老用户从 v1.0.2 平滑升级
- [ ] 落实 CSV 选择性导出功能，允许用户勾选【待办历史/文玩档案/AI 日志】
- [ ] 完整备份升级：改为将数据库文件与沙盒 `images/` 目录通过 `archive` 库压缩为 `.pabackup` 专有文件
- [ ] 构建脚本升级：双模调试（热重载模式 + 单架构快速打包模式）

### 6. 🧭 代码工程优化

- [ ] 统一错误处理和 `mounted` 检查风格
- [ ] 将常量抽取到独立文件
- [ ] 考虑为共享 Widget 建立公共库
- [ ] 旧版格式编辑兼容提示（`categoryMetadata` 结构变更检测）

---

## 🎯 已完成里程碑 (v1.0.2)

- [x] **Phase 1-6**：脚手架搭建、四大模块（待办/文玩/AI复盘/简历）MVP
- [x] **Phase 7 (v1.0.2)**：逾期逻辑重写、待办软删除、文玩后宫排行榜、简历三模板、子任务架构
- [x] 17 项 Bug 修复与 22 项体验优化（详见 CHANGELOG.md）

---

## 📐 已废弃 / 已合并

| 原计划项 | 处理方式 |
|---------|---------|
| 文玩估值模块（`valuation_records`、`fl_chart`） | v1.1.0 计划移除 |
| 旧版格式编辑提示（P2） | 合并至「代码工程优化」子项 |
| 导出功能扩展（P3） | 合并至「基础设施优化」CSV 导出/专有备份 |

---

## 历史版本

- 2026-06-13：v1.2.0 迭代期，Phase 8-9 规划
- 2026-06-13：v1.0.2 发布，标记 17 项已完成
