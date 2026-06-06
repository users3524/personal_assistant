# 文玩记录模块 — 详细规格说明

## 一、数据模型

### 1.1 藏品主表

```dart
// features/collection/data/datasources/antique_items_table.dart
import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';

class AntiqueItems extends Table {
  @override
  String get tableName => 'antique_items';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();  // 松石 | 南红 | 菩提 | 翡翠 | 和田玉 | 紫砂 | 书画 | 杂项 | 自定义
  TextColumn get subtype => text().nullable()();  // 子类，如 "高瓷" "绿松"
  TextColumn get description => text().nullable()();
  DateTimeColumn get acquiredDate => dateTime()();
  RealColumn get acquiredPrice => real().nullable()();
  TextColumn get sourceSeller => text().nullable()();
  TextColumn get condition => text().withDefault(const Constant('good'))();  // perfect | good | fair | poor
  RealColumn get currentValuation => real().nullable()();

  // ✅ 图片存储：只存相对路径，如 "antiques/item_3_0.jpg"
  // 渲染时通过 path_provider 获取 ApplicationDocumentsDirectory 拼接
  TextColumn get imagePaths => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  // 指纹特征（JSON），用于记录特定纹理、朱砂点、铁线等防伪特征
  TextColumn get fingerprints => text().nullable()();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime())();
}
```

### 1.2 估值记录表

```dart
class ValuationRecords extends Table {
  @override
  String get tableName => 'valuation_records';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(AntiqueItems, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  TextColumn get remark => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
}
```

### 1.3 盘玩日志表

```dart
class PattingLogs extends Table {
  @override
  String get tableName => 'patting_logs';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(AntiqueItems, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  IntColumn get durationMinutes => integer()();           // 盘玩时长（分钟）
  TextColumn get method => text()();                      // bare_hand | glove
  TextColumn get note => text().nullable()();
  TextColumn get photoPaths => text().map(const StringListConverter()).withDefault(const Constant('[]'))(); // 盘玩后拍照（相对路径）
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
}
```

## 二、图片存储方案（重点）

### 2.1 iOS 沙盒路径问题

在 iOS 中，App 沙盒目录的绝对路径在应用更新后可能改变。如果数据库存储的是绝对路径，会导致图片加载失败。

### 2.2 解决方案：相对路径 + 动态拼接

```dart
// 存储时（在 AntiqueService 中）
String saveAntiqueImage(Uint8List imageData, int itemId, int index) async {
  final dir = await getApplicationDocumentsDirectory();
  final relativePath = 'antiques/item_${itemId}_$index.jpg';
  final file = File('${dir.path}/$relativePath');
  await file.writeAsBytes(imageData);
  return relativePath;  // 只存相对路径
}

// 读取时（在 UI 层或 ImageProvider 中）
Future<File> getAntiqueImageFile(String relativePath) async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$relativePath');
}

// 使用 cached_network_image 的替代：
// 使用 Image.file(File) 加载，配合 CachedMemoryImage 优化性能
```

### 2.3 图片处理流程

1. 用户拍照/从相册选取（`image_picker`）
2. 压缩图片至合理尺寸（最大 1920px，质量 80%）
3. 生成相对路径文件名：`antiques/item_{id}_{index}.jpg`
4. 写入 `ApplicationDocumentsDirectory/antiques/` 目录
5. 将相对路径存入数据库 `imagePaths` 字段
6. 渲染时通过 `path_provider` 获取当前沙盒路径，动态拼接绝对路径

## 三、功能列表

### 3.1 藏品管理

| 功能 | 说明 |
|------|------|
| 新增藏品 | 填写表单 + 拍照/选取多图 |
| 编辑藏品 | 修改任意字段，增减图片 |
| 删除藏品 | 级联删除估值记录 + 盘玩日志 + 图片文件 |
| 分类管理 | 预置分类，支持自定义添加 |

### 3.2 浏览与查看

| 视图 | 说明 |
|------|------|
| 网格视图 | 2 列网格，封面大图 + 名称 + 当前估值 |
| 详情页 | 大图轮播 + 信息卡片 + 估值折线图 |
| 筛选面板 | 底部弹出：分类勾选、年份范围、品相选择 |

### 3.3 盘玩日志

| 功能 | 说明 |
|------|------|
| 每日打卡 | 选择藏品 → 填写盘玩时长 + 方式 → 可选拍照 |
| 时间线 | 按日期排列所有盘玩记录 |
| 盘玩进化录 | 选取多个时间点的照片生成前后对比图 |

### 3.4 估值追踪

| 功能 | 说明 |
|------|------|
| 记录估值 | 每次重估时新增 `ValuationRecords` 记录 |
| 走势图 | fl_chart 折线图展示估值变化趋势 |
| 当前估值 | 在列表页和详情页展示最新估值 |

### 3.5 保养提醒

| 提醒类型 | 间隔 | 说明 |
|----------|------|------|
| 清理 | 每月 | 提醒清理藏品表面灰尘 |
| 上油 | 每季 | 提醒对特定材质上油保养 |
| 静置 | 按需 | 提醒长时间盘玩后静置 |
| 湿度检查 | 每周 | 检查存放环境湿度 |

## 四、数据访问层（DAO）

```dart
class AntiqueDao {
  // 基础 CRUD
  Future<AntiqueItem> insert(AntiqueItemsCompanion entry);
  Future<AntiqueItem> update(int id, AntiqueItemsCompanion entry);
  Future<void> delete(int id);
  Future<AntiqueItem?> getById(int id);
  Future<List<AntiqueItem>> getAll();

  // 查询与筛选
  Future<List<AntiqueItem>> getByCategory(String category);
  Future<List<AntiqueItem>> getByYearRange(int startYear, int endYear);
  Future<List<AntiqueItem>> getByCondition(String condition);
  Future<List<AntiqueItem>> search(String keyword);       // 全文搜索 name + description

  // 估值记录
  Future<List<ValuationRecord>> getValuations(int itemId);
  Future<ValuationRecord> addValuation(ValuationRecordsCompanion entry);

  // 盘玩日志
  Future<List<PattingLog>> getPattingLogs(int itemId);
  Future<List<PattingLog>> getPattingLogsByDate(DateTime date);
  Future<PattingLog> addPattingLog(PattingLogsCompanion entry);

  // 统计
  Future<int> countByCategory();
  Future<double> totalValuation();
}
```

## 五、预置分类

```
松石 → 高瓷 / 普通
南红 → 柿子红 / 樱桃红 / 冰飘
菩提 → 金刚 / 星月 / 凤眼
翡翠 → 玻璃种 / 冰种 / 糯种
和田玉 → 羊脂 / 青玉 / 碧玉
紫砂 → 朱泥 / 紫泥 / 段泥
书画
杂项 → 核桃 / 葫芦 / 折扇 / 印章
自定义
```
