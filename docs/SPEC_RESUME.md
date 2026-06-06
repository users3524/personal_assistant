# 动态简历生成模块 — 详细规格说明

## 一、数据模型

### 1.1 个人资料表（单例）

```dart
// features/resume/data/datasources/resume_profile_table.dart
import 'package:drift/drift.dart';

class ResumeProfile extends Table {
  @override
  String get tableName => 'resume_profile';

  IntColumn get id => integer().autoIncrement()();    // 始终 id=1（单例模式）
  TextColumn get fullName => text()();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get personalSummary => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get jobTitle => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime())();
}
```

### 1.2 工作经历表

```dart
class WorkExperiences extends Table {
  @override
  String get tableName => 'work_experiences';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get company => text()();
  TextColumn get position => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();    // null = 至今
  TextColumn get description => text().nullable()();        // Markdown 格式描述
  TextColumn get techStack => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime())();
}
```

### 1.3 教育经历表

```dart
class Educations extends Table {
  @override
  String get tableName => 'educations';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get school => text()();
  TextColumn get major => text()();
  TextColumn get degree => text()();                       // 博士 / 硕士 / 本科 / 大专
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
```

### 1.4 技能表

```dart
class SkillItems extends Table {
  @override
  String get tableName => 'skill_items';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();                     // language | framework | tool | soft
  IntColumn get proficiency => integer()();                // 1-5
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
```

### 1.5 项目经历表

```dart
class ProjectExperiences extends Table {
  @override
  String get tableName => 'project_experiences';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get role => text()();
  TextColumn get description => text().nullable()();       // Markdown 格式
  TextColumn get techStack => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get link => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
```

## 二、简历引擎设计

### 2.1 数据聚合

```dart
class ResumeData {
  final ResumeProfile profile;
  final List<WorkExperience> workExperiences;    // 已按 sortOrder 排序，仅 isVisible
  final List<Education> educations;
  final List<SkillItem> skills;
  final List<ProjectExperience> projects;
}

class ResumeEngine {
  /// 收集所有可见条目，按 sortOrder 排序
  Future<ResumeData> buildResumeData({
    required ResumeProfileDao profileDao,
    required WorkExperienceDao workDao,
    required EducationDao eduDao,
    required SkillItemDao skillDao,
    required ProjectExperienceDao projectDao,
  }) async {
    return ResumeData(
      profile: (await profileDao.get())!,
      workExperiences: (await workDao.getAllVisible()),
      educations: (await eduDao.getAllVisible()),
      skills: (await skillDao.getAllVisible()),
      projects: (await projectDao.getAllVisible()),
    );
  }
}
```

### 2.2 模板系统

每个模板是一个接收 `ResumeData` 并返回 Widget 的 StatelessWidget：

```dart
abstract class ResumeTemplate {
  String get name;
  String get description;
  Widget build(BuildContext context, ResumeData data);
}

// 模板 1：简洁经典
class ClassicTemplate extends StatelessWidget implements ResumeTemplate {
  // 单栏布局，黑白灰配色，适合传统行业
}

// 模板 2：现代卡片
class ModernCardTemplate extends StatelessWidget implements ResumeTemplate {
  // 双栏布局，彩色强调色，适合设计/产品岗
}

// 模板 3：技术极简
class TechMinimalTemplate extends StatelessWidget implements ResumeTemplate {
  // 单栏布局，等宽字体，适合程序员/技术岗
}
```

## 三、功能列表

### 3.1 编辑页（ResumeEditPage）

| 区域 | 内容 |
|------|------|
| 个人信息 | 姓名、头像、邮箱、电话、简介、网站、地点、职位 |
| 工作经历 Tab | 列表 + 新增/编辑/删除/拖拽排序/可见性开关 |
| 教育经历 Tab | 同上 |
| 技能 Tab | 同上，含分类下拉和熟练度星级 |
| 项目经历 Tab | 同上，含「从周报导入」按钮 |

### 3.2 预览页（ResumePreviewPage）

| 功能 | 说明 |
|------|------|
| 实时预览 | 全屏展示当前选中模板的渲染效果 |
| 模板切换 | 底部按钮切换 3 套模板，实时重渲染 |
| 导出 PDF | 点击后生成 A4 PDF，调用系统分享面板 |
| 复制 Markdown | 一键复制 Markdown 格式简历到剪贴板 |
| 切换可见性 | 直接在预览页可勾选/取消某个条目 |

### 3.3 一键导入周报亮点

在项目经历列表 → 点击「从周报导入」→ 弹出周报选择器（仅显示有 `highlights` 的周报）→ 选择要导入的高亮条目 → 自动创建 `ProjectExperience`。

## 四、PDF 导出方案

### 4.1 技术选型

| 包 | 用途 |
|----|------|
| `pdf` | 在 Dart 侧生成 PDF 文档（布局、字体、样式） |
| `printing` | 调用系统打印/分享面板，或直接保存文件 |

### 4.2 中文字体体积优化

**问题**：完整 Noto Sans SC 字体包约 15-20 MB，直接打包会导致 APK/IPA 体积翻倍。

**解决方案（三选一）**：

| 方案 | 优点 | 缺点 |
|------|------|------|
| **A. 字体子集化（推荐）** | 仅保留简历常用的 3000+ 汉字，体积约 1-2 MB | 需要预处理工具 |
| **B. 系统字体 fallback** | 零额外体积 | PDF 渲染效果不可控 |
| **C. 首次在线下载** | 不影响安装包体积 | 需要网络，首次生成有延迟 |

**推荐方案 A 实现步骤**：

1. 使用 `fonttools`（Python）或在线工具对 Noto Sans SC 进行子集化
2. 保留：常用汉字（3500 字）+ 英文字母 + 数字 + 标点
3. 产出体积约 1.5 MB 的 `.ttf` 文件
4. 放入 `assets/fonts/` 目录
5. 在 PDF 生成时注册该字体

```dart
// PDF 生成示例
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final font = pw.Font.ttf(
  await rootBundle.load('assets/fonts/noto_sans_sc_subset.ttf')
);

final pdf = pw.Document();
pdf.addPage(
  pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (context) => pw.DefaultTextStyle(
      style: pw.TextStyle(font: font, fontSize: 12),
      child: _buildContent(data),
    ),
  ),
);
```

## 五、DAO 接口概要

```dart
class ResumeProfileDao {
  Future<ResumeProfile?> get();             // 查询单例
  Future<void> upsert(ResumeProfile profile); // 插入或更新
}

class WorkExperienceDao {
  Future<WorkExperience> insert(WorkExperiencesCompanion entry);
  Future<WorkExperience> update(int id, WorkExperiencesCompanion entry);
  Future<void> delete(int id);
  Future<List<WorkExperience>> getAllVisible();  // isVisible = true, 按 sortOrder 排序
  Future<List<WorkExperience>> getAll();
  Future<void> updateSortOrder(int id, int newOrder);
}

// EducationDao, SkillItemDao, ProjectExperienceDao 类似结构
```
