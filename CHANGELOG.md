# Changelog — 个人全能助手

> 自动构建 APK 下载地址：
> [GitHub Releases](https://github.com/users3524/personal_assistant/releases)

> 说明：本文件保留历史版本记录。当前功能、路由、数据库表和模块边界以 `README.md` 与 `docs/` 下的规格文档为准；例如当前简历导出为 PNG 分享而非 PDF，数据库为 `schemaVersion = 6`、14 张表，文玩估值代码仍存在但后续不作为保留模块。

---

## Unreleased

### 📝 文档

- 基于 2026-06-20 代码现状重整 README 与 docs，全局区分“已实现事实”和“后续规划”
- 明确文玩记录保留、估值模块后续移除、复盘与简历智能化的阶段化取舍
- 补齐待办、文玩、AI 复盘、动态简历、备份安全与路线图的模块边界说明

---

## v1.0.2 (2026-06-13)

### 🏗️ 待办模块大重构

- **逾期逻辑彻底重写**：纯日期比对（抹平时分秒），截止日当天不逾期；无截止日期时按 startedAt 判定
- **displayDate 动态漂移**：未完成任务自动漂移到当天展示，数据在底层不变，UI 层过滤
- **shouldShowInToday 属性**：统一"挪到当天"逻辑，`countTodayTotal` 统计口径对齐
- **软删除/回收站**：新增 `deletedAt` 字段，删除不再永久清除，可恢复
- **分段查询**：`getActive()`/`getOverdue()`/`getArchived()`/`getTrashed()`
- **Dismissible 闪退修复**：key 改为稳定值 `todo.id`，乐观更新 `deleteTodoLocal`
- **TodoListView 组件**：双向滑动（右滑完成 + 左滑删除）+ HapticFeedback 震动反馈
- **TodoStatsCard 仪表盘**：今日完成 / 本周达成 / 历史拖延，等宽字体数值，周视图展示
- **数据库 schema 3→5**：新增 `todos.deletedAt`、`work_experiences.responsibilities`、`project_experiences.keyDeliverables` 和 `badges` 列

### 🏺 文玩模块娱乐化升级

- **后宫排行榜大扩充**：财富榜→贵妃榜→核桃榜→老炮榜→串串榜→缘分榜→冷宫幽怨→夜猫子→劳模→端水大师，共 10 个榜单
- **每日随机开盲盒**：每天随机展示 3 个榜单，每日一刷有新鲜感
- **文玩老道今日批注**：宜/忌双列布局，冷宫怨气值实时提醒
- **拟真立体领奖台**：阶梯高度差（🥇105px / 🥈85px / 🥉75px）+ 渐变色台座 + 头像圈
- **冷宫幽怨榜**：基于实际打卡时间计算冷落天数，非入手日期
- **月历照片闪高亮**：跳转后 amber 底色闪烁 3 次

### 📄 简历模块工业级重构

- **三套模板**：简洁经典（单栏商务风）、现代卡片（双栏深绿侧边栏）、技术极简（等宽字体 MD 风格）
- **实体字段升级**：`WorkExperienceEntity` 新增 `responsibilities`；`ProjectExperienceEntity` 新增 `keyDeliverables` + `badges`
- **排版工具函数**：`buildBulletPoints`（换行→• 列表）+ `buildTechStack`（蓝色技术栈徽章）
- **编辑页改造**：新增技术栈输入框（逗号分隔），保存时自动拆分入库
- **图片导出**：`RepaintBoundary.toImage()` → PNG → `Share.shareXFiles()` 直接分享简历图片

### 🐛 Bug 修复

- **图片保存到系统相册**：替换 `image_gallery_saver` 为 `gal`，写入系统 MediaStore
- **图片路径持久化**：改为存储相对路径，新建 `resolveImageFile` 兼容新旧
- **侧滑返回逻辑**：`PopScope` 拦截后退事件，优先路由内 pop，非首页切回第一 Tab
- **文玩分类计数联动**：筛选分类时统计条同步显示该分类件数
- **核桃表单字段兜底**：分类模型未加载时使用硬编码默认字段
- **分类管理拖拽**：大类使用 `reorder()` 方法正真实体重排；子分类/字段长按拖拽 + key 修复
- **日报删除缓存刷新**：`_confirmDelete` 同时 invalidate 所有相关 Provider 防重启才刷新
- **对比图背景**：`RepaintBoundary` 内加 `Container` 渐变背景，保存时背景一致
- **月历打卡 BOTTOM OVERFLOW**：弹窗 Column→SingleChildScrollView 包裹防溢出
- **排行榜溢出**：4-10 名区 Flexible+ConstrainedBox+可滚动

### 🧹 代码清理

- 删除 9 个空目录（`core/utils/`、`data/models/`、`domain/usecases/`、`presentation/widgets/`）
- 移除 11 个未使用依赖（`cached_network_image`、`encrypt`、`crypto`、`pointycastle`、`uuid`、`device_info_plus`、`collection`、`pdf`、`printing`、`intl`、`mocktail`）
- 简化 `analysis_options.yaml`，移除 7 条重复 lint 规则
- 清理死代码（`_fullscreenButton`、`_buildEmptyState`、`_showReviewEntry`、`_decodeList`、`_encodeList`、3 个多余 `!` 操作符）
- 删除未使用 import 3 处（`dart:convert`）
- 删除冗余 `todo_usecases.dart`（含遗留的 `2` 后缀重复 Provider）

### 🔧 新增 Provider

- `coldPalaceRankProvider` — 冷宫天数
- `nightOwlRankProvider` — 深夜打卡计数
- `costPerPlayProvider` — 单次盘玩成本
- `recentVarietyProvider` — 近两周活跃度
- `totalPattingDurationProvider` — 累计盘玩时长
- `sortedSkillsProvider` — 技能按分类聚合排序

---

## v1.0.1 (2026-06-07)

### 🐛 Bug 修复

#### 文玩打卡记录
- **拍照/选图后灰屏**：修复 `content://` URI 无法被 `Image.file` 读取的布局约束问题
- **打卡弹窗卡死/闪退**：移除对话框内的 `FutureBuilder` 异步加载和 `ref.invalidate(FutureProvider)` 导致的全局重建
- **保存后闪退**：不再 invalidate `FutureProvider`，改为替换 Future 触发局部重建
- **日期选择无效**：`ValueNotifier<DateTime>` 从 `StatefulBuilder` 内部移到外部

#### Banner 图片轮播
- 每张照片右下角添加「全屏」按钮，点击可缩放拖动查看
- 全屏展示改为 `Navigator.push` + 全黑 Scaffold
- Banner 下方添加圆点指示器（当前页高亮）和数字标签（1/N）
- Banner 优先展示最新打卡记录的照片

#### 盘玩时间线
- 左侧改为「第N天」距离入手天数，右侧卡片改为 `26/03/05 16:38` 格式
- 打卡照片从「X张照片」文字改为 56×56 缩略图网格

#### 列表页封面
- 网格卡片优先展示最新打卡记录的照片
- 类别旁显示细分品类标签（橙色）+ 天数（灰色）

#### AI 复盘
- 对话式复盘重构：引入状态机（_flowStep 0-5），支持自然语言多轮对话
- 周报生成改用统一 `aiServiceProvider` 而非硬编码
- 可改进点在首页置顶显示（📌）

#### 设置页面
- AI 配置持久化到数据库（新建 `UserPreferencesDao`）
- 通知开关实际生效
- 备份导出改为纯 JSON 明文
- 导入支持选择 `.json` 文件直接恢复
- 主题模式持久化到数据库

### ✨ 新增功能

- **打卡对比**：选择两条打卡记录的照片并排展示
- **分类体系重构**：三大类（核桃/手串/把件），每类含细分品类 + 专属字段
- **新建藏品自动创建首条打卡**：入手当天打卡记录（备注「入手」），照片同步到打卡记录
- **数据库 schema v1→v2 自动迁移**

---

## v1.0.0 (2026-06-07)

**里程碑：首次成功编译 APK，可在 Android 16 真机运行**

### 新增功能
- 待办事项管理（Todo）：创建、编辑、分类、优先级、生命周期追踪
- 文玩藏品管理（Collection）：藏品录入/盘玩日志/估价记录/图片管理
- AI 日报/周报（AI Assistant）：日报复盘、周报汇总、AI 评语生成
- 动态简历（Resume）：个人资料/工作/教育/技能/项目模块；当前代码最终演进为多模板预览和 PNG 分享导出
- 用户设置：主题切换（浅色/深色）、AI 配置、通知、备份
- SQLite 本地持久化（drift 框架）

### 构建相关
- Flutter 3.44.1 / Dart 3.12.1 / JDK 17
- Gradle 9.5.1 / AGP 9.1.0
- 首次编译验证通过 ✅（APK debug 包）
