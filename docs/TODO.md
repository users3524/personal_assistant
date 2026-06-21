# TODO

最后更新：2026-06-21

本清单是重新整体审视后的下一阶段 backlog。历史已完成事项不再放在这里，避免把 TODO 变成纪念碑。执行规则：每完成一项，必须验证通过并用中文 Conventional Commit 提交。

## P0：复盘生成闭环

- [ ] 实现 `RawContextPackBuilder`，按目标本地日期组装待办、chat_turns、已有日报草稿和 patting_logs。
  - 验收：不包含 API Key、图片 base64、备份路径；日期使用半开区间；有单元测试覆盖空素材、混合素材和隐私字段。
- [ ] 将 `RawContextClipper` 接入真实 raw pack，保留裁剪前后长度、保留项和丢弃原因。
  - 验收：超预算时不拆坏 JSON 语义；高优完成任务、云端 user turn、有备注文玩打卡优先。
- [ ] 增加前台执行 pending `review_generation_jobs` 的服务入口。
  - 验收：可从 App 启动补偿和复盘页手动触发；同一 targetDate 不重复并发执行。
- [ ] 接入 `NightlyStructuredReviewRunner`，把成功输出写入 `daily_reviews`。
  - 验收：成功任务标记 success；失败任务标记 failed；超过 3 次调用上限后设置 `calibration_required`。
- [ ] 在 `ReviewHomePage` 显示生成任务状态和校准入口。
  - 验收：pending、failed、calibrationRequired 三种状态用户可见；不阻塞页面加载。
- [ ] WorkManager 回调复用同一执行入口。
  - 验收：Android 回调不再只是安全空执行；失败可被下次前台补偿。

## P0：备份与安全收口

- [ ] 为 JSON 备份增加 manifest：应用版本、schemaVersion、导出时间、表计数和图片数量。
  - 验收：导入前能展示备份概要；旧备份无 manifest 仍可导入。
- [ ] 增加导入预检和错误报告。
  - 验收：缺表、坏日期、坏 base64、外键顺序异常能给出可读错误，不直接清空现有数据。
- [ ] 设计覆盖导入确认页或二次确认文案。
  - 验收：用户明确知道导入会清空当前业务表和安全存储中的 AI Key。
- [ ] 评估加密备份格式。
  - 验收：明确是否引入密码保护、密钥派生、图片打包格式和兼容策略。

## P1：高光证据池

- [ ] 基于日报/待办/文玩素材生成高光候选，单日最多 2 条，允许 0 条。
  - 验收：低价值流水账不生成；候选包含来源关系草稿。
- [ ] 实现高光收件箱 UI。
  - 验收：支持确认、忽略、编辑标题、描述、重要性。
- [ ] 实现高光来源追溯。
  - 验收：`todo`、`daily_review`、`patting_log` 来源能跳回对应页面或给出清晰降级。
- [ ] 项目经历支持绑定多个高光并排序。
  - 验收：使用 `project_milestone_relations`；删除项目或高光后关系一致。
- [ ] 高光投递到项目关键交付。
  - 验收：未确认高光不能投递；投递前用户可编辑。

## P1：简历输出

- [ ] 接入 `pdf` / `printing`，实现 `ResumePdfExportService`。
  - 验收：生成 A4 PDF 字节；页面尺寸、关键文本和异常处理有测试。
- [ ] 完成 PDF 字体策略。
  - 验收：中文可稳定显示；测试字体来源明确。
- [ ] 在简历页增加 PDF 导出入口，与 PNG 分享分开。
  - 验收：导出状态、错误提示、mounted 检查完整。
- [ ] 接入 STAR bullet 生成入口。
  - 验收：只使用本地事实；最多 3 条；不支持的数字/技术栈声明会被丢弃。
- [ ] 将 `ResumeAiOutputSanitizer` 接入 UI 状态层。
  - 验收：HTML/Markdown/布局指令不会进入持久化数据。

## P1：测试与质量

- [ ] 替换 `test/app_test.dart` 占位测试为真实 App 初始化冒烟测试。
- [ ] 替换 `test/widget_test.dart` 占位测试为真实路由/首页冒烟测试。
- [ ] 为复盘生成闭环增加端到端 service 测试。
- [ ] 为高光收件箱增加 widget 测试。
- [ ] 为 PDF 极端文本增加结构测试。

## P2：RAG 与长期记忆

- [ ] 实现 embedding 生成任务，只索引确认高光、日报摘要和必要项目事实。
- [ ] 增加向量索引状态 UI：missing、mismatch、ready、rebuild required。
- [ ] 增加向量重建入口。
- [ ] 将 Weekly RAG 限窗接入周报生成。
- [ ] 对大候选集启用年份/维度过滤和 Isolate 执行计划。

## P2：待办与人生罗盘

- [ ] 为待办表单补齐标签编辑和重复策略入口。
- [ ] 设计并落地人生罗盘五维目标持久化。
- [ ] 实现 30 天修改冷却 UI。
- [ ] 为存量根任务生成维度迁移建议，用户确认后写入。
- [ ] 增加维度统计视图，继续保持主仪表盘只统计根任务。

## P3：兼容与清理

- [ ] 设计旧绝对图片路径迁移工具。
- [ ] 评估是否物理移除 `valuation_records` 和 `antique_items.current_valuation`。
- [ ] 清理未注册的 `RouteNames.resumePreview` / `RouteNames.resumeTemplates` 或补齐对应路由。
- [ ] 评估 `todoCategoriesProvider` 默认分类与 `TodoEntity.defaultCategories` 的口径差异。
