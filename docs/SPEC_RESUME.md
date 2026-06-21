# 动态简历模块规格

最后更新：2026-06-20

本文记录当前简历模块现状。STAR AI 润色、PDF 导出、里程碑素材池尚未实现。

## 1. 当前页面与入口

| 路由 | 页面 | 当前功能 |
| --- | --- | --- |
| `/resume` | `ResumeHomePage` | 默认简历预览，可编辑、切换模板、导出分享图片。 |

`RouteNames` 中存在 `/resume/preview`、`/resume/templates` 常量，但当前路由未注册独立页面。

## 2. 数据表

### `resume_profile`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `full_name` | 姓名。 |
| `avatar_path` | 头像路径，实体有字段，当前页面使用有限。 |
| `email` | 邮箱。 |
| `phone` | 电话。 |
| `personal_summary` | 个人简介。 |
| `website` | 网站。 |
| `location` | 地点。 |
| `job_title` | 求职/职位标题。 |
| `updated_at` | 更新时间。 |

### `work_experiences`

| 字段 | 当前用途 |
| --- | --- |
| `company` | 公司。 |
| `position` | 职位。 |
| `start_date` / `end_date` | 时间范围。 |
| `description` | 描述。 |
| `responsibilities` | 职责列表，`StringListConverter`。 |
| `tech_stack` | 技术栈列表，`StringListConverter`。 |
| `is_visible` | 是否在简历中展示。 |
| `sort_order` | 排序。 |
| `created_at` / `updated_at` | 时间戳。 |

### `educations`

| 字段 | 当前用途 |
| --- | --- |
| `school` | 学校。 |
| `major` | 专业。 |
| `degree` | 学历。 |
| `start_date` / `end_date` | 时间范围。 |
| `description` | 描述。 |
| `is_visible` | 是否展示。 |
| `sort_order` | 排序。 |

### `skill_items`

| 字段 | 当前用途 |
| --- | --- |
| `name` | 技能名称。 |
| `category` | 技能分类。 |
| `proficiency` | 熟练度整数 1-5，不是 `expert/good/fair` 之类的文本枚举。 |
| `is_visible` | 是否展示。 |
| `sort_order` | 排序。 |

### `project_experiences`

| 字段 | 当前用途 |
| --- | --- |
| `name` | 项目名称。 |
| `role` | 角色，Drift 字段可空。 |
| `description` | 描述。 |
| `tech_stack` | 技术栈列表。 |
| `key_deliverables` | 关键交付列表，模板会展示；编辑页支持按行编辑。 |
| `badges` | 标签列表，模板会展示；当前编辑页尚未完整编辑该字段。 |
| `link` | 链接。 |
| `start_date` / `end_date` | 时间范围。 |
| `is_visible` | 是否展示。 |
| `sort_order` | 排序。 |

## 3. 当前仓库与数据组装

| 能力 | 当前实现 |
| --- | --- |
| 个人资料 | `getProfile()`、`saveProfile()`。 |
| 工作经历 | 查询全部/可见、保存、删除、重排接口。 |
| 教育经历 | 查询全部/可见、保存、删除。 |
| 技能 | 查询全部/可见、保存、删除。 |
| 项目经历 | 查询全部/可见、保存、删除。 |
| 简历组装 | `buildResumeData()` 只取可见记录。 |
| 刷新 | 保存后递增 `resumeRefreshProvider`。 |

## 4. 当前预览功能

来源：`ResumeHomePage`、`resume_templates.dart`

| 功能 | 当前实现 |
| --- | --- |
| 默认预览 | `/resume` 直接显示当前模板。 |
| 模板切换 | AppBar 菜单切换 0/1/2。 |
| 模板 0 | `ClassicResumeTemplate`，简洁经典，单栏。 |
| 模板 1 | `ModernResumeTemplate`，现代卡片，双栏侧边栏。 |
| 模板 2 | `TechResumeTemplate`，技术极简，类 Markdown/等宽风格。 |
| 技术栈 | `buildTechStack()` 使用小徽章展示。 |
| 项目 badges | 模板支持展示。 |
| 项目 keyDeliverables | 模板支持 bullet 展示。 |

## 5. 当前编辑功能

来源：`_ResumeEditPage`

| 区域 | 当前实现 |
| --- | --- |
| 个人信息 | 姓名、职位、邮箱、电话、地点、网站、个人简介。 |
| 工作经历 | ReorderableListView，支持可见性开关、公司、职位、描述、技术栈。 |
| 教育背景 | ReorderableListView，支持可见性开关、学校、专业、学历、描述。 |
| 技能 | ReorderableListView，支持可见性开关、技能名、分类、熟练度。 |
| 项目经历 | ReorderableListView，支持可见性开关、项目名、角色、描述、技术栈、关键交付。 |
| 保存 | 一次性保存所有编辑项到 Repository。 |

当前编辑页使用逗号分隔文本解析技术栈。

## 6. 当前导出能力

| 能力 | 当前实现 |
| --- | --- |
| 图片导出 | 使用 `RepaintBoundary` 截图当前预览；`_exportAsImage()` 已 `await boundary.toImage()` 和 `toByteData()`。 |
| 分享 | 使用 `share_plus` 分享 PNG 图片。 |
| 临时文件 | 当前写入 `Directory.systemTemp`。 |
| 导出依赖 | 当前 `pubspec.yaml` 只有 `share_plus`，没有 `pdf` / `printing`。 |
| PDF 导出 | 当前未实现。 |
| Markdown 导出 | 当前未实现。 |

当前 PNG 导出仍在页面方法中完成，尚未抽成独立服务；也没有显式等待 `debugNeedsPaint` 结束，分享前没有再次检查页面是否仍 mounted。后续若继续保留图片导出，应补齐绘制状态等待、生命周期检查、临时目录策略和失败降级。

## 7. 当前数据债

| 问题 | 代码事实 | 后续处理 |
| --- | --- | --- |
| 备份恢复列清单滞后 | `BackupService._restoreData()` 的 `work_experiences` 导入列缺 `responsibilities`。 | 补齐导入字段，并增加导出-导入镜像测试。 |
| 备份恢复列清单滞后 | `BackupService._restoreData()` 的 `project_experiences` 导入列缺 `key_deliverables` / `badges`。 | 补齐导入字段，并覆盖 `StringListConverter` 字段。 |
| 模板未持久化 | `selectedTemplateIdProvider` 是内存 `StateProvider<int>`；`user_preferences.resume_template_id` 字段存在但当前未接入。 | 切换模板时写入偏好，初始化时读取。 |
| 项目成果编辑缺口 | 模板可展示 `keyDeliverables` / `badges`，编辑页已支持 `keyDeliverables`，尚未支持 `badges`。 | 增加 badges 编辑控件。 |

## 8. 当前未实现

1. STAR AI 叙事润色。
2. 从日报/周报高光导入项目经历。
3. 里程碑素材池。
4. PDF 生成与打印。
5. 项目 `badges` 的完整编辑 UI。
6. 简历模板持久化到 `user_preferences.resume_template_id`。

## 9. 未来 AI 简历规划原则

以下原则来自新的智能化白皮书，只作为后续方向，不代表当前已经实现。

| 原则 | 规划口径 |
| --- | --- |
| 高光门槛 | 自动高光不收录普通打卡和低价值流水账；必须能对应复杂问题、作品、交付或阶段成果。 |
| 单日上限 | 单篇日报自动高光最多 2 条；没有重大突破时允许为 0。 |
| 事实约束 | STAR 润色只能使用本地传入的高光摘要、待办描述、项目上下文，不得编造百分比、用户量、公司主体或工具链。 |
| Bullet 上限 | 单个项目经历 AI 生成 bullet 最多 3 条，持久化时仍应代码层截断。 |
| 纯文本输出 | AI 只输出纯文本或 `List<String>`，状态层过滤 HTML、Markdown 样式和布局指令。 |
| 排版隔离 | 简历页面、图片导出和未来 PDF 排版全部由 Flutter 模板控制，AI 不参与字号、间距、分页和样式。 |
| 高光解耦 | 在把高光绑定到项目经历前，应先设计 `milestones` 主表和 `milestone_relations` 多源关联表。 |
| 多源追溯 | `milestone_relations.sourceType/sourceId` 首版可指向 `todo`、`daily_review`、`patting_log`、`manual` 等来源，便于反查证据。 |
| 多态清理 | 多态关联无法由 SQLite 外键保障；Todo、Review、Collection 的物理删除必须在事务内清理对应 `milestone_relations`。 |
| 项目关联 | 项目经历不要只放单个 `milestoneId`；应新增 `project_milestone_relations` 支持项目和高光多对多。 |
| PDF 前置条件 | 当前无 PDF；未来 PDF 需要确定性模板、TextPainter 文本测量、分页保护和 golden/integration 测试。 |
| 极端文本测试 | PDF/图片导出前应覆盖超长姓名、长 URL、无空格英文、中文长句、3 条 bullet 临界长度等案例。 |
| 测试容差 | Golden 测试不做 1 像素绝对比对；采用合理像素容差、关键区域布局断言和语义树文本完整性检查。 |
