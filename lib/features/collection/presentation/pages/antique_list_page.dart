/// 文玩包列表页 — 网格/月历双视图 + 每日翻牌推荐。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';
import '../widgets/antique_grid_card.dart';
import '../widgets/resolved_image.dart';
import '../../../settings/presentation/providers/category_management_providers.dart';
import '../../../todo/presentation/providers/todo_providers.dart';

class AntiqueListPage extends ConsumerStatefulWidget {
  const AntiqueListPage({super.key});

  @override
  ConsumerState<AntiqueListPage> createState() => _AntiqueListPageState();
}

class _AntiqueListPageState extends ConsumerState<AntiqueListPage> {
  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(antiqueListProvider);
    final categoryCount = ref.watch(categoryCountProvider).valueOrNull ?? {};
    final viewMode = ref.watch(collectionViewModeProvider);
    final gridColumns = ref.watch(gridColumnsProvider);
    final aspectRatio = gridColumns == 2
        ? 0.78
        : (gridColumns == 3 ? 0.85 : 0.9);

    return Scaffold(
      appBar: AppBar(
        title: const Text('文玩包'),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings'),
        ),
        actions: [
          // 月历切换
          IconButton(
            icon: Icon(
              viewMode == CollectionViewMode.grid
                  ? Icons.calendar_month
                  : Icons.grid_view,
            ),
            tooltip: viewMode == CollectionViewMode.grid ? '月历' : '网格',
            onPressed: () {
              ref
                  .read(collectionViewModeProvider.notifier)
                  .state = viewMode == CollectionViewMode.grid
                  ? CollectionViewMode.calendar
                  : CollectionViewMode.grid;
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            initialValue: ref.watch(antiqueSortModeProvider),
            onSelected: (mode) {
              ref.read(antiqueSortModeProvider.notifier).state = mode;
              ref.read(antiqueListProvider.notifier).sortBySortMode(mode);
            },
            itemBuilder: (context) {
              final cur = ref.watch(antiqueSortModeProvider);
              return [
                CheckedPopupMenuItem(
                  value: '',
                  checked: cur == '',
                  child: const Text('默认排序'),
                ),
                CheckedPopupMenuItem(
                  value: 'acquired_desc',
                  checked: cur == 'acquired_desc',
                  child: const Text('入手时间 ↓'),
                ),
                CheckedPopupMenuItem(
                  value: 'acquired_asc',
                  checked: cur == 'acquired_asc',
                  child: const Text('入手时间 ↑'),
                ),
                CheckedPopupMenuItem(
                  value: 'price_desc',
                  checked: cur == 'price_desc',
                  child: const Text('入手价格 ↓'),
                ),
                CheckedPopupMenuItem(
                  value: 'price_asc',
                  checked: cur == 'price_asc',
                  child: const Text('入手价格 ↑'),
                ),
                CheckedPopupMenuItem(
                  value: 'patting',
                  checked: cur == 'patting',
                  child: const Text('最近盘玩'),
                ),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestPattingPhotosProvider);
          await ref.read(antiqueListProvider.notifier).refresh();
        },
        child: viewMode == CollectionViewMode.calendar
            ? _buildCalendarView(context)
            : _buildGridView(
                context,
                ref,
                listAsync,
                categoryCount,
                gridColumns,
                aspectRatio,
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/collection/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ===== 网格视图 =====

  Widget _buildGridView(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<AntiqueEntity>> listAsync,
    Map<String, int> categoryCount,
    int gridColumns,
    double aspectRatio,
  ) {
    return CustomScrollView(
      slivers: [
        // 每日翻牌推荐
        SliverToBoxAdapter(child: _buildDailyPick(context)),
        // 统计摘要条
        SliverToBoxAdapter(child: _buildStatsBar(context, categoryCount)),
        // 藏品网格
        listAsync.when(
          data: (items) {
            // 分类筛选
            final filter = ref.watch(categoryDisplayFilterProvider);
            final filtered = filter.isEmpty
                ? items
                : items.where((i) => i.category == filter).toList();

            if (filtered.isEmpty) {
              return const SliverFillRemaining(
                child: Center(child: Text('该分类暂无藏品')),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: aspectRatio,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = filtered[index];
                  return _buildGridCard(context, ref, item);
                }, childCount: filtered.length),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) =>
              SliverFillRemaining(child: Center(child: Text('加载失败: $err'))),
        ),
      ],
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    WidgetRef ref,
    AntiqueEntity item,
  ) {
    final photosAsync = ref.watch(latestPattingPhotosProvider);
    final latestPhoto = photosAsync.valueOrNull?[item.id];

    return AntiqueGridCard(
      item: item,
      latestPhoto: latestPhoto,
      onTap: () => context.push('/collection/${item.id}'),
    );
  }

  // ===== 每日翻牌推荐 =====

  Widget _buildDailyPick(BuildContext context) {
    final dailyPickAsync = ref.watch(dailyPickProvider);

    return dailyPickAsync.when(
      data: (picks) {
        if (picks.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '今日伴手推荐',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      ref.invalidate(dailyPickProvider);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.replay,
                            size: 14,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '换一换',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: picks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = picks[index];
                    return _buildPickCard(context, item);
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 50),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPickCard(BuildContext context, AntiqueEntity item) {
    final photosAsync = ref.watch(latestPattingPhotosProvider);
    final latestPhoto = photosAsync.valueOrNull?[item.id];
    final cover =
        latestPhoto ??
        (item.imagePaths.isNotEmpty ? item.imagePaths.first : null);

    return GestureDetector(
      onTap: () => context.push('/collection/${item.id}'),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: cover != null
                  ? ResolvedImage(
                      path: cover,
                      width: 100,
                      height: 72,
                      fit: BoxFit.cover,
                      placeholder: _buildPickIcon(item.category),
                      error: _buildPickIcon(item.category),
                    )
                  : _buildPickIcon(item.category),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              item.subtype ?? item.category,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildPickIcon(String category) {
    return Container(
      width: 100,
      height: 72,
      color: Colors.grey.shade200,
      child: Icon(
        category == '核桃' ? Icons.circle : Icons.grain,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }

  // ===== 月历视图 + 趣味排行 =====

  Widget _buildCalendarView(BuildContext context) {
    final month = ref.watch(calendarMonthProvider);
    final calendarData = ref.watch(pattingCalendarProvider(month));
    final listAsync = ref.watch(antiqueListProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(antiqueListProvider.notifier).refresh(),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 月历部分
            calendarData.when(
              data: (dayLogs) => _buildCalendarGrid(context, month, dayLogs),
              loading: () => const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SizedBox(
                height: 300,
                child: Center(child: Text('加载失败: $err')),
              ),
            ),
            const Divider(height: 24),
            // 趣味排行
            listAsync.when(
              data: (items) => _buildRankings(context, items),
              loading: () => const SizedBox(height: 100),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    DateTime month,
    Map<int, List<PattingLogEntity>> dayLogs,
  ) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday - 1;
    final daysInMonth = lastDay.day;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells + 6) ~/ 7;
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    final monthNames = [
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月',
    ];

    // 建立 itemId → itemName 映射
    final itemsAsync = ref.watch(antiqueListProvider);
    final itemNames = <int, String>{};
    if (itemsAsync.valueOrNull != null) {
      for (final item in itemsAsync.valueOrNull!) {
        if (item.id != null) itemNames[item.id!] = item.name;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 月历头部导航
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  ref.read(calendarMonthProvider.notifier).state = DateTime(
                    month.year,
                    month.month - 1,
                    1,
                  );
                },
              ),
              Text(
                '${month.year}年${monthNames[month.month - 1]}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  ref.read(calendarMonthProvider.notifier).state = DateTime(
                    month.year,
                    month.month + 1,
                    1,
                  );
                },
              ),
            ],
          ),
        ),
        // 星期标签
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['一', '二', '三', '四', '五', '六', '日'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      color: (d == '六' || d == '日') ? Colors.grey : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        // 日期网格
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            height: (rows * 74).toDouble(),
            child: Table(
              children: List.generate(rows, (weekIndex) {
                return TableRow(
                  children: List.generate(7, (colIndex) {
                    final dayNum = weekIndex * 7 + colIndex - startWeekday + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const SizedBox(height: 72);
                    }
                    final date = DateTime(month.year, month.month, dayNum);
                    final isToday = date == now;
                    final logs = dayLogs[dayNum] ?? [];
                    final hasPhoto = logs.any((l) => l.photoPaths.isNotEmpty);

                    return GestureDetector(
                      onTap: () =>
                          hasPhoto ? _onDayTap(context, date, logs) : null,
                      child: Container(
                        height: 72,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.08)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: hasPhoto
                              ? Border.all(
                                  color: Colors.orange.withValues(alpha: 0.4),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday ? FontWeight.bold : null,
                                color: isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            if (hasPhoto && logs.first.photoPaths.isNotEmpty)
                              Expanded(
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: ResolvedImage(
                                        path: logs.first.photoPaths.first,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        placeholder: const Icon(
                                          Icons.image,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        error: const Icon(
                                          Icons.image,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    // 物品名称叠加
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(4),
                                            bottomRight: Radius.circular(4),
                                          ),
                                        ),
                                        child: Text(
                                          itemNames[logs.first.itemId] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (logs.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.touch_app,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ===== 趣味排行 =====

  // ===== 文玩老道今日批注 =====

  Widget _buildFortuneCard(BuildContext context, List<AntiqueEntity> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // 使用 coldPalaceRankProvider 的数据（基于实际打卡时间计算冷宫天数）
    final now = DateTime.now();
    final coldDaysAsync = ref.watch(coldPalaceRankProvider);
    final coldDaysMap = coldDaysAsync.valueOrNull ?? {};
    AntiqueEntity? coldestItem;
    int maxColdDays = 0;
    for (final item in items) {
      if (item.id == null) continue;
      final coldDays = coldDaysMap[item.id] ?? 0;
      if (coldDays > maxColdDays) {
        maxColdDays = coldDays;
        coldestItem = item;
      }
    }

    final yiList = [
      ('🔥 大汗猛盘', '适合出一身汗大力盘刷，包浆进度 +50%'),
      ('🪥 刷子伺候', '缝隙积灰了，今天宜深度清洁'),
      ('🍵 泡茶配盘', '泡一壶好茶，单手揉核桃，偷得半日闲'),
      ('📸 绝美定格', '今日光线极佳，适合给宝贝拍标准照'),
      ('🧼 素手净盘', '洗净双手，不沾油汗，感受最原始的阻尼感'),
      ('🤲 掌中摩挲', '开会追剧时随手盘，今日宜零碎时间利用'),
      ('⚖️ 称重记录', '今天称一称，看看有没有偷偷变重'),
      ('☀️ 晒晒太阳', '温和日光下晒一晒，杀菌又提色'),
      ('📐 测量周径', '盘了这么久，看看尺寸收缩了多少'),
      ('💎 多宝搭配', '今天试试不同材质的搭配组合'),
    ];

    final jiList = [
      ('❄️ 继续吃灰', '再不盘它，宝贝要在冷宫里长毛了'),
      ('🧴 盲目上油', '大力流汗的日子，别瞎上油，容易盘黑'),
      ('🩹 暴力武盘', '核桃尖尖在哭泣，今天动静小点'),
      ('🤡 买新忘旧', '看着手里的，别老想着海鲜市场还没发货的'),
      ('🌊 沾水盘玩', '今天湿气重，别拿宝贝碰水'),
      ('🗑️ 随手乱放', '上次差点坐碎核桃的是不是你？'),
      ('🐶 被狗叼走', '放高点，二哈最近对你的核桃很感兴趣'),
      ('🧊 冷宫放置', '再不开后宫，嫔妃们要发动宫变了'),
    ];

    final seed = now.day + now.month;
    final yi = yiList[seed % yiList.length];
    final ji = jiList[(seed * 3) % jiList.length];

    final todoCount = ref.watch(todayTotalCountProvider).valueOrNull ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.shade100, width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.purple.shade50.withValues(alpha: 0.3),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '🔮 文玩老道今日批注',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  '📅 农历干支玄学',
                  style: TextStyle(fontSize: 10, color: Colors.purple.shade300),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(
                height: 1,
                color: Colors.purple.withValues(alpha: 0.1),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '【 宜 】',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        yi.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        yi.$2,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade200,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '【 忌 】',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ji.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ji.$2,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (coldestItem != null && maxColdDays > 7) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('🥶', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '后宫怨气警告：怨气值 +$maxColdDays％！「${coldestItem.name}」已被打入冷宫 $maxColdDays 天，今晚不摸一把说不过去了吧？',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (todoCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '💡 提示：今日还有 $todoCount 项正事没干。盘串虽爽，可别耽误搬砖买新串！',
                style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===== 随机榜单（每日抽3个） =====
  List<int> _dailySelectedRankIndices = [];
  int _lastDataDay = -1;

  void _initDailyRandomRanks() {
    final today = DateTime.now().day;
    if (_lastDataDay == today && _dailySelectedRankIndices.isNotEmpty) return;
    _lastDataDay = today;
    final allIndices = List.generate(10, (i) => i);
    allIndices.shuffle();
    _dailySelectedRankIndices = allIndices.take(3).toList();
    _rankTabIndex = 0;
  }

  Widget _buildRankings(BuildContext context, List<AntiqueEntity> items) {
    _initDailyRandomRanks();

    const allRankTabs = [
      ('👑 贵妃榜', 0),
      ('🥜 核桃榜', 1),
      ('🏆 老炮榜', 2),
      ('🧵 串串榜', 3),
      ('🤝 缘分榜', 4),
      ('❄️ 冷宫幽怨', 5),
      ('💪 把玩王', 6),
      ('🌙 夜猫子', 7),
      ('🧮 劳模榜', 8),
      ('🌧️ 端水大师', 9),
    ];

    final displayedTabs = allRankTabs
        .where((tab) => _dailySelectedRankIndices.contains(tab.$2))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFortuneCard(context, items),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '✨ 今日限定内卷榜',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(每日随机精选)',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: displayedTabs.asMap().entries.map((entry) {
              final pageIndex = entry.key;
              final tab = entry.value;
              return _buildRankTab(tab.$1, pageIndex);
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        _buildRankContent(items, displayedTabs.map((t) => t.$2).toList()),
      ],
    );
  }

  int _rankTabIndex = 0;
  final _rankPageController = PageController();

  @override
  void dispose() {
    _rankPageController.dispose();
    super.dispose();
  }

  Widget _buildRankTab(String label, int pageIndex) {
    final selected = _rankTabIndex == pageIndex;
    return GestureDetector(
      onTap: () {
        setState(() => _rankTabIndex = pageIndex);
        _rankPageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.decelerate,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : null,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildRankContent(
    List<AntiqueEntity> items,
    List<int> selectedIndices,
  ) {
    final allWidgets = <int, Widget>{
      0: _buildPattingRank(context, items),
      1: _buildSizeRank(context, items),
      2: _buildVeteranRank(context, items),
      3: _buildStringRank(context, items),
      4: _buildSourceRank(context, items),
      5: _buildColdPalaceRank(context, items),
      6: _buildDurationsRank(context, items),
      7: _buildNightOwlRank(context, items),
      8: _buildCostPerPlayRank(context, items),
      9: _buildRecentVarietyRank(context, items),
    };

    final activeWidgets = selectedIndices
        .map((index) => allWidgets[index]!)
        .toList();

    return SizedBox(
      height: 520,
      child: PageView(
        controller: _rankPageController,
        onPageChanged: (i) => setState(() => _rankTabIndex = i),
        children: activeWidgets,
      ),
    );
  }

  Widget _buildPattingRank(BuildContext context, List<AntiqueEntity> items) {
    return FutureBuilder<Map<int, int>>(
      future: ref.read(monthlyPattingFrequencyProvider.future),
      builder: (context, snapshot) {
        final freq = snapshot.data ?? {};
        final ranked = List<AntiqueEntity>.from(items)
          ..sort((a, b) => (freq[b.id] ?? 0).compareTo(freq[a.id] ?? 0));
        final top = ranked
            .where((i) => (freq[i.id] ?? 0) > 0)
            .take(10)
            .toList();
        if (top.isEmpty) return const SizedBox.shrink();

        return _buildRankCard(
          title: '👑 贵妃榜',
          subtitle: '按本月打卡次数排序（专宠）',
          items: top,
          label: (i) => '${freq[i.id] ?? 0}次',
          icon: Icons.touch_app,
        );
      },
    );
  }

  Widget _buildSizeRank(BuildContext context, List<AntiqueEntity> items) {
    // 只考虑核桃品类
    final walnutItems = items.where((i) => i.category == '核桃').toList();
    final withSize = walnutItems
        .where(
          (i) =>
              i.categoryMetadata != null &&
              i.categoryMetadata!.keys.any(
                (k) => k.contains('边宽') || k.contains('尺寸'),
              ),
        )
        .toList();
    withSize.sort(
      (a, b) => _extractSize(
        b.categoryMetadata!,
        '边宽',
      ).compareTo(_extractSize(a.categoryMetadata!, '边宽')),
    );

    if (withSize.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(
                  '暂无核桃尺寸数据，请在藏品详情中添加尺寸信息',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildRankCard(
      title: '🥜 核桃榜',
      subtitle: '按边宽尺寸排序（仅核桃）',
      items: withSize.take(5).toList(),
      label: (i) {
        final size = _extractSize(i.categoryMetadata!, '边宽');
        return size > 0 ? '$size mm' : '';
      },
      icon: Icons.straighten,
    );
  }

  double _extractSize(Map<String, String> metadata, String fieldKey) {
    for (final entry in metadata.entries) {
      if (entry.key.contains(fieldKey)) {
        return double.tryParse(
              entry.value.replaceAll(RegExp(r'[^0-9.]'), ''),
            ) ??
            0;
      }
    }
    return 0;
  }

  Widget _buildVeteranRank(BuildContext context, List<AntiqueEntity> items) {
    final ranked = List<AntiqueEntity>.from(items)
      ..sort((a, b) => a.acquiredDate.compareTo(b.acquiredDate));
    final top = ranked.take(5).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return _buildRankCard(
      title: '🏆 老炮榜',
      subtitle: '按入手时间排序（最久远）',
      items: top,
      label: (i) {
        final days = DateTime.now().difference(i.acquiredDate).inDays;
        return '${days ~/ 365}年${(days % 365) ~/ 30}月';
      },
      icon: Icons.hourglass_bottom,
    );
  }

  Widget _buildStringRank(BuildContext context, List<AntiqueEntity> items) {
    // 手串按尺寸排序
    final braceletItems = items.where((i) => i.category == '手串').toList();
    final withSize = braceletItems
        .where(
          (i) =>
              i.categoryMetadata != null &&
              i.categoryMetadata!.keys.any(
                (k) => k.contains('尺寸') || k.contains('串型'),
              ),
        )
        .toList();
    withSize.sort(
      (a, b) => _extractSize(
        b.categoryMetadata!,
        '尺寸',
      ).compareTo(_extractSize(a.categoryMetadata!, '尺寸')),
    );

    if (withSize.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(
                  '暂无手串尺寸数据',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildRankCard(
      title: '🧵 串串榜',
      subtitle: '按尺寸排序（仅手串）',
      items: withSize.take(5).toList(),
      label: (i) {
        final size = _extractSize(i.categoryMetadata!, '尺寸');
        return size > 0 ? '$size mm' : '';
      },
      icon: Icons.straighten,
    );
  }

  Widget _buildSourceRank(BuildContext context, List<AntiqueEntity> items) {
    // 按入手渠道聚类
    final withSource = items
        .where((i) => i.sourceSeller != null && i.sourceSeller!.isNotEmpty)
        .toList();
    final grouped = <String, List<AntiqueEntity>>{};
    for (final item in withSource) {
      grouped.putIfAbsent(item.sourceSeller!, () => []).add(item);
    }
    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final top = sorted.take(5).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 6),
                Text(
                  '🤝 缘分榜',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  '按来源聚类',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...top.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final source = entry.value.key;
              final items = entry.value.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: rank <= 3
                      ? Colors.amber.shade100
                      : Colors.grey.shade100,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? Colors.amber.shade800 : Colors.grey,
                    ),
                  ),
                ),
                title: Text(
                  source,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Text(
                  '${items.length}件',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationsRank(BuildContext context, List<AntiqueEntity> items) {
    return FutureBuilder<Map<int, int>>(
      future: ref.read(totalPattingDurationProvider.future),
      builder: (context, snapshot) {
        final duration = snapshot.data ?? {};
        final ranked = List<AntiqueEntity>.from(
          items,
        )..sort((a, b) => (duration[b.id] ?? 0).compareTo(duration[a.id] ?? 0));
        final top = ranked
            .where((i) => (duration[i.id] ?? 0) > 0)
            .take(10)
            .toList();
        if (top.isEmpty) return const SizedBox.shrink();

        return _buildRankCard(
          title: '💪 把玩王',
          subtitle: '按累计盘玩时长排序',
          items: top,
          label: (i) {
            final mins = duration[i.id] ?? 0;
            if (mins >= 60) return '${(mins / 60).toStringAsFixed(1)}h';
            return '${mins}m';
          },
          icon: Icons.fitness_center,
        );
      },
    );
  }

  Widget _buildColdPalaceRank(BuildContext context, List<AntiqueEntity> items) {
    return FutureBuilder<Map<int, int>>(
      future: ref.read(coldPalaceRankProvider.future),
      builder: (context, snapshot) {
        final daysMap = snapshot.data ?? {};
        final ranked = List<AntiqueEntity>.from(items)
          ..sort((a, b) => (daysMap[b.id] ?? 0).compareTo(daysMap[a.id] ?? 0));
        final top = ranked
            .where((i) => (daysMap[i.id] ?? 0) > 3)
            .take(10)
            .toList();
        if (top.isEmpty) return const SizedBox.shrink();

        return _buildRankCard(
          title: '❄️ 冷宫幽怨榜',
          subtitle: '按冷落天数排序',
          items: top,
          label: (i) {
            final days = daysMap[i.id] ?? 0;
            if (days >= 365) return '${(days / 365).toStringAsFixed(1)}年';
            return '${days}天';
          },
          icon: Icons.ac_unit,
        );
      },
    );
  }

  Widget _buildNightOwlRank(BuildContext context, List<AntiqueEntity> items) {
    return FutureBuilder<Map<int, int>>(
      future: ref.read(nightOwlRankProvider.future),
      builder: (context, snapshot) {
        final nightCount = snapshot.data ?? {};
        final ranked = List<AntiqueEntity>.from(items)
          ..sort(
            (a, b) => (nightCount[b.id] ?? 0).compareTo(nightCount[a.id] ?? 0),
          );
        final top = ranked
            .where((i) => (nightCount[i.id] ?? 0) > 0)
            .take(10)
            .toList();
        if (top.isEmpty) return const SizedBox.shrink();

        return _buildRankCard(
          title: '🌙 夜猫子榜',
          subtitle: '深夜盘玩次数（23:00-3:00）',
          items: top,
          label: (i) => '${nightCount[i.id] ?? 0}次',
          icon: Icons.nightlight_round,
        );
      },
    );
  }

  Widget _buildCostPerPlayRank(
    BuildContext context,
    List<AntiqueEntity> items,
  ) {
    return FutureBuilder<Map<int, double>>(
      future: ref.read(costPerPlayProvider.future),
      builder: (context, snapshot) {
        final costMap = snapshot.data ?? {};
        // 按单次成本从低到高（劳模）排序
        final ranked = List<AntiqueEntity>.from(items)
          ..sort(
            (a, b) => (costMap[a.id] ?? double.infinity).compareTo(
              costMap[b.id] ?? double.infinity,
            ),
          );
        final top = ranked
            .where((i) => costMap.containsKey(i.id))
            .take(10)
            .toList();
        if (top.isEmpty) return const SizedBox.shrink();

        return _buildRankCard(
          title: '🧮 劳模榜',
          subtitle: '单次盘玩成本（越低越值）',
          items: top,
          label: (i) {
            final cost = costMap[i.id] ?? 0;
            if (cost >= 100) return '¥${cost.toStringAsFixed(0)}/次';
            return '¥${cost.toStringAsFixed(1)}/次';
          },
          icon: Icons.emoji_events,
        );
      },
    );
  }

  Widget _buildRecentVarietyRank(
    BuildContext context,
    List<AntiqueEntity> items,
  ) {
    return FutureBuilder<Map<int, int>>(
      future: ref.read(recentVarietyProvider.future),
      builder: (context, snapshot) {
        final recentCount = snapshot.data ?? {};
        final ranked = List<AntiqueEntity>.from(items)
          ..sort(
            (a, b) =>
                (recentCount[b.id] ?? 0).compareTo(recentCount[a.id] ?? 0),
          );
        final top = ranked
            .where((i) => (recentCount[i.id] ?? 0) > 0)
            .take(10)
            .toList();
        if (top.isEmpty) return const SizedBox.shrink();

        return _buildRankCard(
          title: '🌧️ 雨露均沾榜',
          subtitle: '近两周盘玩活跃度',
          items: top,
          label: (i) => '${recentCount[i.id] ?? 0}次',
          icon: Icons.spa,
        );
      },
    );
  }

  Widget _buildRankCard({
    required String title,
    required String subtitle,
    required List<AntiqueEntity> items,
    required String Function(AntiqueEntity) label,
    required IconData icon,
  }) {
    final top3 = items.take(3).toList();
    final rest = items.length > 3 ? items.sublist(3) : <AntiqueEntity>[];
    final placeholderCount = items.isEmpty ? 10 : 10 - items.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 前三名阶梯展示
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 40,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '虚位以待',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (top3.length >= 2)
                    Expanded(child: _buildPodiumItem(top3[1], 2, 85, label)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPodiumItem(top3[0], 1, 105, label)),
                  const SizedBox(width: 6),
                  if (top3.length >= 3)
                    Expanded(child: _buildPodiumItem(top3[2], 3, 75, label)),
                  if (top3.length < 3) const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ],
            // 4-10名列表
            if (rest.isNotEmpty || placeholderCount > 0) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...rest.asMap().entries.map((entry) {
                          final rank = entry.key + 4;
                          final item = entry.value;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            leading: Text(
                              '$rank.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            subtitle: Text(
                              item.subtype ?? item.category,
                              style: const TextStyle(fontSize: 10),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label(item),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            onTap: () => context.push('/collection/${item.id}'),
                          );
                        }),
                        // 虚位以待占位
                        ...List.generate(placeholderCount, (i) {
                          final rank = items.length + i + 1;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            leading: Text(
                              '$rank.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            title: Text(
                              '—',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            subtitle: Text(
                              '虚位以待',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade300,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumItem(
    AntiqueEntity item,
    int rank,
    double baseHeight,
    String Function(AntiqueEntity) label,
  ) {
    final medals = ['🥇', '🥈', '🥉'];
    final podiumColors = [
      [Colors.amber.shade400, Colors.orange.shade300],
      [Colors.grey.shade300, Colors.grey.shade400],
      [Colors.orange.shade200, Colors.brown.shade300],
    ];
    final cover = item.imagePaths.isNotEmpty ? item.imagePaths.first : null;
    final photosAsync = ref.watch(latestPattingPhotosProvider);
    final latestPhoto = photosAsync.valueOrNull?[item.id];
    final displayImage = latestPhoto ?? cover;

    return GestureDetector(
      onTap: () => context.push('/collection/${item.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: podiumColors[rank - 1][0],
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: rank == 1 ? 52 : 44,
                    height: rank == 1 ? 52 : 44,
                    child: displayImage != null
                        ? ResolvedImage(
                            path: displayImage,
                            fit: BoxFit.cover,
                            placeholder: Center(
                              child: Text(
                                medals[rank - 1],
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            error: Center(
                              child: Text(
                                medals[rank - 1],
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              medals[rank - 1],
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                  ),
                ),
              ),
              if (displayImage != null)
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: podiumColors[rank - 1][0],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      medals[rank - 1],
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label(item),
            style: TextStyle(
              fontSize: 9,
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: baseHeight - 45,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: podiumColors[rank - 1],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDayTap(
    BuildContext context,
    DateTime date,
    List<PattingLogEntity> logs,
  ) {
    if (logs.isEmpty) return;
    // 只有一条记录 → 直接跳转
    if (logs.length == 1) {
      final log = logs.first;
      context.push('/collection/${log.itemId}?highlightLog=${log.id ?? ''}');
      return;
    }
    // 多条记录 → 底部弹出打卡列表，点击照片再跳转
    final dateStr = '${date.month}月${date.day}日';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dateStr 打卡记录',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...logs.take(10).map((log) {
              final days = log.date
                  .difference(
                    DateTime(log.date.year, log.date.month, log.date.day),
                  )
                  .inDays;
              final dayLabel = days == 0 ? '入手当天' : '第$days天';
              return ListTile(
                dense: true,
                leading: log.photoPaths.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ResolvedImage(
                          path: log.photoPaths.first,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: const Icon(
                            Icons.image,
                            size: 24,
                            color: Colors.grey,
                          ),
                          error: const Icon(
                            Icons.image,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : const Icon(Icons.touch_app, color: Colors.grey),
                title: Text(dayLabel, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  log.note ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(
                    '/collection/${log.itemId}?highlightLog=${log.id ?? ''}',
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ===== 统计摘要条 =====

  Widget _buildStatsBar(BuildContext context, Map<String, int> categoryCount) {
    final selectedFilter = ref.watch(categoryDisplayFilterProvider);
    final totalCount = categoryCount.values.fold(0, (a, b) => a + b);
    final displayCount = selectedFilter.isEmpty
        ? totalCount
        : categoryCount[selectedFilter] ?? 0;
    final displayLabel = selectedFilter.isEmpty
        ? '共$totalCount件'
        : '$selectedFilter $displayCount件';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            '🏛️ $displayLabel',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Spacer(),
          _buildCategoryFilter(context),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    final categories = ref.watch(collectionCategoriesProvider);
    final selectedFilter = ref.watch(categoryDisplayFilterProvider);
    return PopupMenuButton<String>(
      initialValue: selectedFilter,
      onSelected: (cat) {
        ref.read(categoryDisplayFilterProvider.notifier).state = cat;
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: '', child: Text('🗂️ 全部分类')),
        ...categories.map(
          (c) => PopupMenuItem(value: c.name, child: Text(c.name)),
        ),
      ],
      child: Chip(
        label: Text(
          selectedFilter.isEmpty ? '筛选' : selectedFilter,
          style: const TextStyle(fontSize: 11),
        ),
        avatar: const Icon(Icons.filter_list, size: 14),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  // ===== 搜索 =====

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(context: context, delegate: _AntiqueSearchDelegate(ref));
  }
}

class _AntiqueSearchDelegate extends SearchDelegate<AntiqueEntity?> {
  final WidgetRef ref;

  _AntiqueSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('输入名称或分类搜索'));
    }
    return FutureBuilder<List<AntiqueEntity>>(
      future: ref
          .read(antiqueRepositoryProvider.future)
          .then((r) => r.search(query)),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('未找到匹配的藏品'));
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final item = snapshot.data![index];
            return ListTile(
              leading: const Icon(Icons.diamond),
              title: Text(item.name),
              subtitle: Text(item.category),
              onTap: () {
                close(context, item);
                context.push('/collection/${item.id}');
              },
            );
          },
        );
      },
    );
  }
}
