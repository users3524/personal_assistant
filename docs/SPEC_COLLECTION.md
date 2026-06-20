# 文玩/盘串模块规格

最后更新：2026-06-20

本文记录当前代码中的文玩模块实现。注意：文玩记录功能保留；估值模块已完成应用层下线，schema v6 中的遗留表/列暂时保留为旧数据库和旧备份兼容壳。

## 1. 当前页面与入口

| 路由 | 页面 | 当前功能 |
| --- | --- | --- |
| `/collection` | `AntiqueListPage` | 文玩包列表，网格/月历双视图，每日翻牌，排序，趣味榜单。 |
| `/collection/new` | `AntiqueFormPage` | 新增藏品。 |
| `/collection/:id` | `AntiqueDetailPage` | 藏品详情、盘玩时间线、打卡、编辑/删除打卡、照片分享/保存、照片对比。 |
| `/collection/:id/edit` | `AntiqueFormPage(editId)` | 编辑藏品。 |

## 2. 数据表

### `antique_items`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `name` | 藏品名称。 |
| `category` | 文玩大类。 |
| `subtype` | 子类型。 |
| `description` | 描述。 |
| `acquired_date` | 入手日期，数据库层非空；表单默认当前日期。 |
| `acquired_price` | 入手价格，可空；用于排序和单次成本榜。 |
| `source_seller` | 来源/卖家。 |
| `condition` | `perfect` / `good` / `fair` / `poor`。 |
| `current_valuation` | 遗留估值兼容列；应用层不再读取或维护，新保存时写空。 |
| `image_paths` | 藏品照片路径列表，`StringListConverter`；Drift 字段非空，默认 `[]`。 |
| `category_metadata` | 分类专属字段 JSON 字符串。 |
| `fingerprints` | 特征记录。 |
| `notes` | 备注。 |
| `created_at` / `updated_at` | 时间戳。 |

### `patting_logs`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `item_id` | 外键，关联 `antique_items.id`，藏品删除时级联删除。 |
| `date` | 打卡时间。 |
| `duration_minutes` | 盘玩时长。 |
| `method` | `bare_hand` / `glove`，实体展示为“净手盘”/“手套盘”。 |
| `note` | 打卡备注。 |
| `photo_paths` | 打卡照片路径列表，`StringListConverter`；Drift 字段非空，默认 `[]`。 |
| `created_at` | 创建时间。 |

### `valuation_records`

当前 schema v6 仍存在该表：

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `item_id` | 外键，关联 `antique_items.id`，藏品删除时级联删除。 |
| `date` | 估值日期。 |
| `amount` | 估值金额。 |
| `remark` | 备注。 |
| `created_at` | 创建时间。 |

当前口径：不保留估值功能。已移除 `ValuationChart`、`ValuationRecordEntity`、`AntiqueRepository.getValuations()` / `addValuation()`、`totalValuationProvider`、`fl_chart`、财富榜和潜力榜。`BackupService` 新导出的 `valuation_records` 为空；导入旧备份时，`valuation_records.date` / `amount` / `remark` 会按 `item_id` 分组、日期升序追加归档到 `antique_items.notes`，旧 `current_valuation` 也会以“当前估值”文本归档后写空。物理删除表/列留到后续 schema 迁移阶段评估。

## 3. 当前实体与仓库

| 类型 | 当前内容 |
| --- | --- |
| `AntiqueEntity` | 藏品主实体，包含图片路径、分类字段、入手价格、备注。 |
| `PattingLogEntity` | 盘玩日志，包含时长、方式、备注、照片路径。 |
| `AntiqueRepository` | CRUD、分类/品相/年份/搜索、盘玩日志、统计、最新打卡照片。 |
| `AntiqueDao` | Drift 查询与实体转换。 |

## 4. 当前列表页功能

来源：`AntiqueListPage`、`antique_providers.dart`

| 功能 | 当前实现 |
| --- | --- |
| 网格视图 | 默认视图，卡片封面优先使用最新打卡照片，其次藏品照片。 |
| 月历视图 | 按月份展示有照片的盘玩打卡日。 |
| 分类筛选 | `categoryDisplayFilterProvider`。 |
| 排序 | 默认、入手时间升/降、入手价格升/降、最近盘玩。 |
| 每日翻牌 | 按配置从低频盘玩候选池随机推荐。默认核桃 2、手串 4。 |
| 网格列数 | `gridColumnsProvider`，设置页可选 2/3/4 列。 |
| 分类统计 | `categoryCountProvider`。 |
| 最新打卡照片 | `latestPattingPhotosProvider`。 |

## 5. 当前趣味榜单

月历页包含每日随机展示的趣味榜单。当前代码中可选榜单包括：

| 榜单 | 依据 |
| --- | --- |
| 贵妃榜 | 当月打卡次数。 |
| 核桃榜 | 核桃分类的边宽等尺寸字段。 |
| 老炮榜 | 入手时间。 |
| 串串榜 | 手串尺寸/串型字段。 |
| 缘分榜 | 来源/卖家聚类。 |
| 冷宫幽怨榜 | 距离上次打卡天数。 |
| 把玩王 | 累计盘玩时长。 |
| 夜猫子榜 | 23:00-3:00 打卡次数。 |
| 劳模榜 | 入手价 / 累计打卡次数。 |
| 雨露均沾榜 | 近两周盘玩活跃度。 |

当前榜单多数在 Provider/UI 层读取藏品和日志后用 Dart 循环计算，不是 SQLite 聚合查询。后续日志量变大时，可把当月打卡次数、最近打卡时间、夜猫子频次、单次成本等计算下沉到 DAO 层，并结合实际查询计划评估 `patting_logs(item_id, date DESC)` 等索引。

## 6. 当前表单功能

来源：`AntiqueFormPage`

| 功能 | 当前实现 |
| --- | --- |
| 分类 | 使用 `collectionCategoriesProvider`，默认核桃、手串、把件。 |
| 自定义分类 | 表单可输入自定义分类，保存后加入分类 Provider。 |
| 子类型 | 来自分类配置。 |
| 专属字段 | 来自分类配置；核桃有硬编码兜底字段。 |
| 核桃字段 | 左右双输入，保存为逗号分隔值。 |
| 图片 | 拍照/相册选图后保存到应用文档目录下 `antique_images/`，新路径返回相对 token。 |
| 新建首条打卡 | 新建藏品时自动用藏品照片创建入手当天打卡记录。 |

## 7. 当前详情页与打卡功能

来源：`AntiqueDetailPage`

| 功能 | 当前实现 |
| --- | --- |
| 图片查看 | 支持全屏查看。 |
| 图片操作 | 长按可分享或保存到系统相册。 |
| 盘玩打卡 | 支持拍照、相册、仅文字打卡。 |
| 打卡时间 | 可选择日期和时间。 |
| 编辑打卡 | 可修改备注、替换/删除照片。 |
| 删除打卡 | 二次确认后删除。 |
| 照片对比 | 至少两条有照片打卡后，可选择左右照片生成时光对比。 |
| 对比图保存 | 使用 `RepaintBoundary` 生成图片并分享。 |
| 删除藏品 | 二次确认；代码提示会删除图片和盘玩记录，数据库外键会级联盘玩日志和遗留估值记录。 |

## 8. 分类管理

来源：`CategoryManagementPage`、`CollectionCategoriesNotifier`

| 功能 | 当前实现 |
| --- | --- |
| 默认分类 | 当前代码默认核桃、手串、把件；后续新增需求为加入“长串”。 |
| 分类排序 | 文玩分类可拖拽排序。 |
| 子类型管理 | 可增删、拖拽排序；正在被藏品使用的子类型禁止删除。 |
| 专属字段管理 | 可增删、拖拽排序。 |
| 分类删除 | 若分类下有藏品，禁止删除。 |
| 持久化 | 同时使用 `AppSettingsPersistence` 和 `collection_categories` 备份同步。 |

## 9. 图片路径

当前新图片保存函数将文件写入应用文档目录的 `antique_images/` 子目录，并返回 `antique_images/xxx.jpg` 形式的相对路径；旧数据和部分导入数据仍可能是绝对路径。`core/utils/image_utils.dart` 可以解析绝对路径和相对路径，但部分 UI 仍直接使用 `File(path)`，这会让相对路径在某些展示、分享或保存入口中破图。

后续图片路径统一原则：

1. 数据库存储统一收敛为相对路径 token。
2. UI、分享、保存、备份导出统一复用现有 `resolveImageFile()` 或等价单一服务解析路径，避免再造多个路径解析入口。
3. 备份恢复解码 `base64:` 图片时写入应用文档目录，而不是系统临时目录。
4. 迁移旧绝对路径前先校验文件是否存在，能复制到 `antique_images/` 的再转相对路径，不能复制的保留原值并提示用户。

注意：当前 `resolveImageFile()` 是异步函数，返回 `Future<File>`。页面层不能按同步 helper 直接塞给 `Image.file()`；改造时需要在 Provider 中预解析、用 `FutureBuilder` 包裹，或提供统一的异步图片组件。

## 10. 备份与 AI 复盘衔接

当前 `BackupService` 已导出 `antique_items`、`patting_logs` 和 `collection_categories`。`valuation_records` 兼容键仍保留但新导出为空；旧备份导入时估值历史归档到藏品备注，不再回灌估值表。恢复图片会写入系统临时目录，且导出图片时仍直接 `File(path)`，对相对路径不稳定。后续需要让备份服务复用图片解析 helper，保证相对路径和绝对路径都能被正确打包。

AI 复盘侧当前 `DailyReviewChatPage` 生成日报时 `pattingMinutes` 固定传 0。后续深夜素材包应从 `patting_logs` 读取当天 `duration_minutes` 总和、打卡 `note` 和照片路径摘要，把文玩打卡作为“兴趣/放松/情绪调节”事实输入；白天文玩打卡本身不应触发云端请求。

## 11. 后续多态关联清理

未来如果 `milestone_relations` 支持 `source_type = 'patting_log'` 或 `source_type = 'antique_item'`，SQLite 无法对这种多态来源建立真实外键。删除盘玩日志、物理删除藏品或导入覆盖数据时，Repository/DAO 需要在同一个事务中清理对应高光关联，避免留下孤儿高光来源。
