## ✅ 已完成

> 以下功能已在历次迭代中完成。

- [x] 简历编辑 — 拖拽排序（已实现，含 ☰ 手柄）
- [x] 分类管理 — 子分类与专属字段拖拽排序（已实现）
- [x] 图片保存到系统相册（使用 image_gallery_saver）
- [x] 排行榜新增趣味维度（串串榜、缘分榜、把玩王）

---

# 待实现功能清单（TODO）

> 以下功能因复杂度或依赖关系暂未实现。  
> 优先级 P0 = 高（影响核心体验），P1 = 中，P2 = 低（增强功能）。

---

## 简历编辑 — 拖拽排序（P1）

**需求**：简历编辑页面中，工作经历/教育背景/技能/项目等列表项应支持通过拖拽手柄（☰ 三道杠图标）调整排序。用户长按拖拽后，条目顺序改变并持久化到数据库的 `sortOrder` 字段。

**涉及文件**：
- `lib/features/resume/presentation/pages/resume_home_page.dart` — `_ResumeEditPage` 中的 `_buildWorkCard` / `_buildEduCard` / `_buildSkillCard` / `_buildProjectCard`
- 各实体已存在 `sortOrder` 字段

**实现思路**：
1. 将四个 `Column` 改为 `ReorderableListView.builder` 或手动 `ReorderableColumn`
2. 每项左侧添加拖拽手柄图标（`Icons.drag_handle`）
3. 保存时根据新索引更新 `sortOrder`
4. saveAll 时按 sortOrder 写入数据库

✅ **已完成**（2026-06 迭代）

---

## 分类管理 — 子分类拖拽排序（P1）

**需求**：设置 → 分类管理中，文玩类别的子类型和专属字段应支持通过拖拽排序。当前以 `Wrap` + `Chip` 展示，无法调整顺序。

**涉及文件**：
- `lib/features/settings/presentation/pages/category_management_page.dart` — `_buildSubtypesSection` 和 `_buildMetadataFieldsSection`
- `lib/core/models/collection_category.dart` — 实体本身无字段顺序，需要设计排序存储方案

**实现思路**：
1. 将 `Wrap` 改为纵向 `Column` 或带排序的 `ListView`
2. 每个 `Chip` 添加拖拽手柄
3. 排序结果写入 `CategoryMetadata.subtypes` 或 `metadataFields` 的列表索引中

✅ **已完成**（2026-06 迭代，使用 ReorderableListView + drag handle）

---

## 排行榜新增更多趣味维度（P2）

**需求**：当前已有财富榜、侍寝榜、核桃榜、老炮榜、潜力榜。可继续增加：
- **串串榜**：手串/长串按尺寸排序
- **缘分榜**：按入手渠道/卖家聚类展示
- **💪 把玩王**：累计盘玩时间最长

**涉及文件**：
- `lib/features/collection/presentation/pages/antique_list_page.dart` — `_buildRankings` 区域

---

## 月历照片闪高亮（P1）

**需求**：点击月历照片后跳转到对应打卡记录，高亮闪烁 3 次（间隔 0.5s）。

**当前状态**：路由参数 `highlightLog` 已传递到 `AntiqueDetailPage`，点击单条记录时带参跳转。多条记录时先展开列表再跳转。高亮动画因结构复杂度暂未实现。

**涉及文件**：
- `lib/features/collection/presentation/pages/antique_list_page.dart` — `_onDayTap`
- `lib/features/collection/presentation/pages/antique_detail_page.dart` — `_buildTimelineList`

---

## 图片路径持久化（P2）

**需求**：App 更新后部分图片消失。原因：`Image.file()` 读取应用私有目录路径，更新后目录路径可能变化。

**当前状态**：图片存储路径为 `getApplicationDocumentsDirectory()/antique_images/` 或 `patting_images/`，这些路径在应用更新后理论上应保持稳定，但如果存在跨版本迁移或系统清理，图片会丢失。

**解决方案选项**：
1. 在数据库 SQLite 中同时存储图片的 Base64 副本（代价：数据库膨胀）
2. 迁移到 `getApplicationSupportDirectory()` 并在启动时做路径修复检查（推荐）
3. 引入 `gallery_saver` 等插件保存到系统相册（需额外权限）

**涉及文件**：
- `lib/features/collection/presentation/pages/antique_form_page.dart` — `_saveImageToAppDir`
- `lib/features/collection/presentation/pages/antique_detail_page.dart` — `_saveImageToAppDir`
- `lib/core/database/backup_service.dart` — `_decodeAndSaveImage`

---

## 旧版格式编辑提示（P2）

**需求**：如果导入了旧版 JSON 数据（`categoryMetadata` 结构不同），编辑界面应检测并提示用户数据格式已变更，展示旧版数据但不可编辑，只有保存更新后才能编辑。

**当前状态**：`categoryMetadata` 为 `Map<String, String>`，核桃类键值形如 `"边宽(mm)": "35.5,36"`（逗号分隔左右值）。旧版可能键名或格式不同。

**涉及文件**：
- `lib/features/collection/presentation/pages/antique_form_page.dart` — `_loadExisting`

---

## 图片保存到系统相册（P2）

✅ **已完成**（2026-06，使用 image_gallery_saver 写入系统 MediaStore）

---

## 核桃编辑表单保存失败排查（P1 — 需复现后修复）

**需求**：用户反馈核桃表单填写后保存有一定概率失败。怀疑原因：
- `_metaCtrls` 中 "左XX"/"右XX" 键的处理存在边界情况
- `_category == '核桃'` 时 `_currentFields` 为空
- 自定义分类输入框 `onChanged` 与已有 `ChoiceChip` 冲突

**当前状态**：代码已梳理，但未在真实设备上复现。需用户在异常时提供截图或日志。

---

## 代码结构整理（P3 — 持续优化）

- 移除未使用的 `import` 声明
- 合并部分冗余的 Provider/future 调用
- 统一错误处理和 `mounted` 检查风格
- 将常量抽取到独立文件
- 考虑为共享 Widget 建立公共库

---

## 导出功能扩展（P3）

**当前**：导出为 JSON（含 Base64 内嵌图片）。
**未来考虑**：
- CSV 导出待办/藏品统计
- 导出同时附带 `export.md` 说明文档
- 选择性导出（仅导出/导入某个模块）
- 云备份（iCloud / Google Drive）

---

## 历史版本
- 2026-06-09：创建，记录 v1.0.1 迭代后剩余待实现项
