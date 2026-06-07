# Changelog — 个人全能助手

> 自动构建 APK 下载地址：
> [GitHub Releases](https://github.com/users3524/personal_assistant/releases)

---

## v1.0.1 (2026-06-07)

### 🐛 Bug 修复

#### 文玩打卡记录
- **拍照/选图后灰屏**：修复 `content://` URI 无法被 `Image.file` 读取的布局约束问题；图片保存统一走 `XFile.readAsBytes()` → 写入 app 私有目录 → `Image.file` 的标准管道
- **打卡弹窗卡死/闪退**：移除对话框内的 `FutureBuilder` 异步加载和 `ref.invalidate(FutureProvider)` 导致的全局重建，改为 state 变量 `_itemFuture` + `_refreshPage()` 局部刷新
- **保存后闪退**：不再 invalidate `FutureProvider`，改为替换 Future 触发局部重建，对话框关闭与页面渲染不再冲突
- **日期选择无效**：`ValueNotifier<DateTime>` 从 `StatefulBuilder` 内部移到外部，避免每次 setState 重置为当前时间

#### Banner 图片轮播
- **图片无法调整位置**：每张照片右下角添加「全屏」按钮，点击可缩放拖动查看
- **全屏不覆盖/关闭无响应**：`showDialog`→`Navigator.push`+全黑 `Scaffold`，关闭按钮改用 `Material`+`InkWell(CircleBorder)`
- **页码指示器**：Banner 下方添加圆点指示器（当前页高亮）和数字标签（1/N）
- **Banner 同步打卡照片**：Banner 优先展示最新打卡记录的照片，左上角标注「最新打卡」/「藏品照片」

#### 盘玩时间线
- 左侧改为「第N天」距离入手天数，右侧卡片改为 `26/03/05 16:38` 格式
- 打卡照片从「X张照片」文字改为 56×56 缩略图网格，点击全屏查看
- 最早一条打卡记录的圆点用深色突出标识

#### 列表页封面
- 网格卡片优先展示最新打卡记录的照片，右上角显示「N天」入手天数
- 下拉刷新同步更新封面
- 类别旁显示细分品类标签（橙色）+ 天数（灰色）

#### AI 复盘
- 对话式复盘重构：引入状态机（_flowStep 0-5），支持自然语言多轮对话
- 周报生成改用统一 `aiServiceProvider` 而非硬编码
- 可改进点在首页置顶显示（📌）
- AI 配置未设置时给出详细引导

#### 设置页面
- AI 配置持久化到数据库（新建 `UserPreferencesDao`）
- 通知开关实际生效
- 备份导出改为纯 JSON 明文，无需密码
- 导入支持选择 `.json` 文件直接恢复
- 开源许可调用 Flutter 内置 `showLicensePage`
- 主题模式持久化到数据库

#### 构建脚本
- `build_and_run.bat` 全面重写：ASCII 英文避免 GBK 乱码、goto 标签替代深层嵌套、ADB 路径检测、设备连接检测

### ✨ 新增功能

#### 打卡对比（新功能）
- 右上角菜单新增「对比」：选择两条打卡记录的照片并排展示
- 全屏对比页：左右照片+分割线+入手天数 VS+天数差值+当时/现在备注

#### 分类体系重构
- 三大类：**核桃**（白狮子/苹果园/鸡心/官帽/虎头/四座楼/南将石/磨盘/蛤蟆头/满天星）、**手串**（百香籽/牛骨/南红/紫金鼠/星月/金刚/凤眼/猴头/紫檀/木患子）、**把件**（葫芦/贝壳/折扇/竹雕/核雕/玉牌/铜件/牙角）
- 每类支持细分品类选择（ChoiceChip + 自定义输入）
- 分类专属字段：核桃（边宽/肚厚/桩高/重量）、手串（尺寸/串型/重量）、把件（长宽高/重量）
- 详情页展示「详细参数」行
- 数据库 schema v1→v2 自动迁移

#### 新建藏品自动创建首条打卡
- 新建时自动创建入手当天打卡记录（备注「入手」），照片同步到打卡记录

### 🔧 数据模型变更
- `antique_items` 表新增 `category_metadata` 列（JSON 存储分类专属字段）
- `AntiqueEntity` 新增 `categoryMetadata`（Map<String,String>?）
- 数据库 schemaVersion: 1 → 2（含自动迁移）
- 所有 DAO 的 Row 类型名对齐 drift 2.33 生成的 `.g.dart`

---

## v1.0.0 (2026-06-07)

**里程碑：首次成功编译 APK，可在 Android 16 真机运行**

### 新增功能
- 待办事项管理（Todo）：创建、编辑、分类、优先级、生命周期追踪
- 文玩藏品管理（Collection）：藏品录入/盘玩日志/估价记录/图片管理
- AI 日报/周报（AI Assistant）：日报复盘、周报汇总、AI 评语生成
- 动态简历（Resume）：多模板 PDF 导出、个人资料/工作/教育/技能/项目模块
- 用户设置：主题切换（浅色/深色）、AI 配置、通知、备份
- SQLite 本地持久化（drift 框架），13 张表的完整 CRUD

### 构建相关
- Flutter 3.44.1 / Dart 3.12.1 / JDK 17
- Gradle 9.5.1 / AGP 9.1.0
- 首次编译验证通过 ✅（APK debug 包）
