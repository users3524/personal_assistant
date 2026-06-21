# 动态简历模块规格

最后更新：2026-06-21

本文记录当前简历模块现状。重新规划后，简历模块是个人证据的输出端：当前已有编辑、模板和 PNG 导出；高光底座、STAR 策略、AI 输出清洗和 PDF 布局计划已存在，但高光投递、STAR UI 和真实 PDF 导出尚未完成。

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
| `badges` | 标签列表，模板会展示；编辑页支持逗号或换行分隔编辑。 |
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

项目经历与高光的多对多底座已通过 `project_milestone_relations` 落地，但当前简历 UI 尚未提供选择、排序和投递高光的入口。

## 4. 当前预览功能

来源：`ResumeHomePage`、`resume_templates.dart`

| 功能 | 当前实现 |
| --- | --- |
| 默认预览 | `/resume` 直接显示当前模板。 |
| 模板切换 | AppBar 菜单切换 0/1/2，并持久化到 `user_preferences.resume_template_id`。 |
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
| 项目经历 | ReorderableListView，支持可见性开关、项目名、角色、描述、技术栈、关键交付、标签。 |
| 保存 | 一次性保存所有编辑项到 Repository。 |

当前编辑页使用逗号分隔文本解析技术栈。

## 6. 当前导出能力

| 能力 | 当前实现 |
| --- | --- |
| 图片导出 | `ResumePngExportService` 使用 `RepaintBoundary` 截图当前预览，并等待 `debugNeedsPaint` 结束。 |
| 分享 | 页面导出完成且仍 `mounted` 后，使用 `share_plus` 分享 PNG 图片。 |
| 临时文件 | 写入系统临时目录下 `resume_exports/`，并清理过期 `resume_*.png`。 |
| 导出依赖 | 当前 `pubspec.yaml` 只有 `share_plus`，没有 `pdf` / `printing`。 |
| PDF 导出 | 当前未实现。 |
| Markdown 导出 | 当前未实现。 |

当前 PNG 导出已从页面抽到 `ResumePngExportService`；页面层只负责导出状态、分享前生命周期检查和用户可见错误提示。

## 7. PDF 导出前置方案

PDF 当前仍未实现；后续作为独立交付，不和 PNG 分享混在同一服务中。

| 主题 | 决策 |
| --- | --- |
| 依赖选择 | 使用 `pdf` 生成文档，使用 `printing` 做预览、打印和分享；实现该能力时再写入 `pubspec.yaml`。 |
| 数据来源 | 复用 `ResumeData`，不直接读取页面 widget 树，也不把 AI 输出作为排版输入。 |
| 模板口径 | 首版只做确定性 A4 单页模板，纸张固定 A4，边距、字号、行高、模块间距全部常量化。 |
| 文本测量 | PDF 服务内集中测量标题、段落、技术栈和 bullet；超长文本按规则换行、截断或降级到双页策略。 |
| 分页保护 | 工作经历、项目经历、教育经历等块级内容不可被任意切开；若单块超过剩余高度，应整体换页或触发可见降级。 |
| 字体策略 | 需要显式嵌入可分发中文字体或确认系统字体方案；测试必须固定字体，避免平台渲染差异。 |
| 测试策略 | 覆盖 PDF 字节可生成、A4 页面尺寸、关键文本存在、极端文本不抛错；布局类测试使用语义/结构断言和 golden 容差。 |
| 用户入口 | PDF 能力完成前不新增按钮；完成后与 PNG 分享分开，避免用户误以为当前已有 PDF。 |

下一步实现 PDF 时，先新增 `ResumePdfExportService` 和独立测试，再接入页面按钮。

## 8. 当前数据债

| 问题 | 代码事实 | 后续处理 |
| --- | --- | --- |
| 高光投递缺口 | 高光表和项目高光关系已落地，简历 UI 未接入。 | 项目经历编辑页增加高光选择/排序/投递入口。 |
| STAR 入口缺口 | `ResumeStarBulletPolicy` 已能约束事实和清洗 bullet，但没有 UI/AI 调用链。 | 先从项目事实和确认高光生成候选，再由用户确认写入。 |
| PDF 导出缺口 | `ResumePdfLayoutPlanner` 和测试策略已落地，未接 `pdf` / `printing`。 | 新增 `ResumePdfExportService` 后再开放按钮。 |
| 头像使用有限 | `resume_profile.avatar_path` 已有字段，但页面使用有限。 | 后续决定是否纳入模板和导出。 |

## 9. 当前未实现

1. STAR AI 叙事润色。
2. 从日报/周报高光导入项目经历。
3. 高光选择、排序和投递 UI。
4. PDF 生成与打印。

## 10. 未来 AI 简历规划原则

以下原则来自新的智能化白皮书，只作为后续方向，不代表当前已经实现。

| 原则 | 规划口径 |
| --- | --- |
| 高光门槛 | 自动高光不收录普通打卡和低价值流水账；必须能对应复杂问题、作品、交付或阶段成果。 |
| 单日上限 | 单篇日报自动高光最多 2 条；没有重大突破时允许为 0。 |
| 事实约束 | STAR 润色只能使用本地传入的高光摘要、待办描述、项目上下文，不得编造百分比、用户量、公司主体或工具链。 |
| Bullet 上限 | 单个项目经历 AI 生成 bullet 最多 3 条，持久化时仍应代码层截断。 |
| 纯文本输出 | AI 只输出纯文本或 `List<String>`，状态层过滤 HTML、Markdown 样式和布局指令。 |
| 排版隔离 | 简历页面、图片导出和未来 PDF 排版全部由 Flutter 模板控制，AI 不参与字号、间距、分页和样式。 |
| 高光解耦 | `milestones`、`milestone_relations` 和 `project_milestone_relations` 已落地；UI 必须尊重“未确认不投递”。 |
| 多源追溯 | `milestone_relations.sourceType/sourceId` 首版可指向 `todo`、`daily_review`、`patting_log`、`manual` 等来源，便于反查证据。 |
| 多态清理 | 多态关联无法由 SQLite 外键保障；Todo、Review、Collection 的物理删除必须在事务内清理对应 `milestone_relations`。 |
| 项目关联 | 项目经历通过 `project_milestone_relations` 绑定多个高光；后续 UI 需支持排序和解绑。 |
| PDF 前置条件 | 当前无 PDF；未来 PDF 需要确定性模板、TextPainter 文本测量、分页保护和 golden/integration 测试。 |
| 极端文本测试 | PDF/图片导出前应覆盖超长姓名、长 URL、无空格英文、中文长句、3 条 bullet 临界长度等案例。 |
| 测试容差 | Golden 测试不做 1 像素绝对比对；采用合理像素容差、关键区域布局断言和语义树文本完整性检查。 |

## 11. 下一阶段规划

| 工作 | 原因 | 验收 |
| --- | --- | --- |
| PDF 导出服务 | 当前只有 PNG 输出 | A4 PDF 可生成，关键文本可验证，极端文本不抛错 |
| 高光选择 UI | 高光底座未进入简历工作流 | 项目可绑定多个确认高光并排序 |
| STAR 生成入口 | 策略已有但未接入 | 输出最多 3 条，事实不支持的内容被拒绝 |
| AI 输出清洗接入 | Sanitizer 仍是纯服务 | HTML/Markdown/布局指令不能持久化 |
| PNG/PDF 导出测试补强 | 输出是用户最终交付物 | 覆盖 mounted、临时文件、关键文本和长文本 |
