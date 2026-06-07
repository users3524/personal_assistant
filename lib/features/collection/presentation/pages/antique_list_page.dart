/// 文玩包列表页 — 网格/月历双视图 + 每日翻牌推荐。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';
import '../widgets/antique_grid_card.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('文玩包'),
        actions: [
          // 月历切换
          IconButton(
            icon: Icon(viewMode == CollectionViewMode.grid
                ? Icons.calendar_month
                : Icons.grid_view),
            tooltip: viewMode == CollectionViewMode.grid ? '月历' : '网格',
            onPressed: () {
              ref.read(collectionViewModeProvider.notifier).state =
                  viewMode == CollectionViewMode.grid
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
                CheckedPopupMenuItem(value: '', checked: cur == '', child: const Text('默认排序')),
                CheckedPopupMenuItem(value: 'acquired_desc', checked: cur == 'acquired_desc', child: const Text('入手时间 ↓')),
                CheckedPopupMenuItem(value: 'acquired_asc', checked: cur == 'acquired_asc', child: const Text('入手时间 ↑')),
                CheckedPopupMenuItem(value: 'price_desc', checked: cur == 'price_desc', child: const Text('入手价格 ↓')),
                CheckedPopupMenuItem(value: 'price_asc', checked: cur == 'price_asc', child: const Text('入手价格 ↑')),
                CheckedPopupMenuItem(value: 'patting', checked: cur == 'patting', child: const Text('最近盘玩')),
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
            : _buildGridView(context, ref, listAsync, categoryCount),
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
  ) {
    return CustomScrollView(
      slivers: [
        // 每日翻牌推荐
        SliverToBoxAdapter(child: _buildDailyPick(context)),
        // 统计摘要条
        SliverToBoxAdapter(child: _buildStatsBar(context, categoryCount)),
        // 藏品网格
        listAsync.when(
          data: (items) => items.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState(context))
              : SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        return _buildGridCard(context, ref, item);
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => SliverFillRemaining(
            child: Center(child: Text('加载失败: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(BuildContext context, WidgetRef ref, AntiqueEntity item) {
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
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('今日伴手推荐',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800)),
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
    final cover = item.imagePaths.isNotEmpty ? item.imagePaths.first : null;

    return GestureDetector(
      onTap: () => context.push('/collection/${item.id}'),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: cover != null
                  ? Image.file(File(cover),
                      width: 100, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPickIcon(item.category))
                  : _buildPickIcon(item.category),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(item.name,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(item.subtype ?? item.category,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildPickIcon(String category) {
    return Container(
      width: 100, height: 72,
      color: Colors.grey.shade200,
      child: Icon(
        category == '核桃' ? Icons.circle : Icons.grain,
        size: 32, color: Colors.grey.shade400,
      ),
    );
  }

  // ===== 月历视图 =====

  Widget _buildCalendarView(BuildContext context) {
    final month = ref.watch(calendarMonthProvider);
    final filter = ref.watch(calendarFilterProvider);
    final calendarData = ref.watch(pattingCalendarProvider(month));

    return calendarData.when(
      data: (dayLogs) => _buildCalendarContent(context, month, dayLogs, filter),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('加载失败: $err')),
    );
  }

  Widget _buildCalFilterChip(String label, String? filterValue) {
    final current = ref.watch(calendarFilterProvider);
    final selected = current == filterValue;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        ref.read(calendarFilterProvider.notifier).state =
            selected ? null : filterValue;
      },
      visualDensity: VisualDensity.compact,
      selectedColor: Colors.orange.shade100.withValues(alpha: 0.5),
      checkmarkColor: Colors.orange,
    );
  }

  Widget _buildCalendarContent(
      BuildContext context, DateTime month, Map<int, List<PattingLogEntity>> dayLogs, [String? filter]) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday - 1; // Mon=0
    final daysInMonth = lastDay.day;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells + 6) ~/ 7;
    final today = DateTime.now();
    final monthNames = ['一月','二月','三月','四月','五月','六月','七月','八月','九月','十月','十一月','十二月'];

    return Column(
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
                  ref.read(calendarMonthProvider.notifier).state =
                      DateTime(month.year, month.month - 1, 1);
                },
              ),
              Text('${month.year}年${monthNames[month.month - 1]}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  ref.read(calendarMonthProvider.notifier).state =
                      DateTime(month.year, month.month + 1, 1);
                },
              ),
            ],
          ),
        ),
        // 分类趣味筛选
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCalFilterChip('🌸 全部', null),
                const SizedBox(width: 6),
                _buildCalFilterChip('🥜 核桃', '核桃'),
                const SizedBox(width: 6),
                _buildCalFilterChip('📿 手串', '手串'),
                const SizedBox(width: 6),
                _buildCalFilterChip('🎯 把件', '把件'),
                const SizedBox(width: 6),
                _buildCalFilterChip('🔥 最勤', 'most'),
                const SizedBox(width: 6),
                _buildCalFilterChip('💤 摸鱼', 'least'),
              ],
            ),
          ),
        ),
        // 星期标签
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['一','二','三','四','五','六','日'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(d,
                      style: TextStyle(fontSize: 12,
                          color: (d == '六' || d == '日') ? Colors.grey : null)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        // 日期网格
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Table(
              children: List.generate(rows, (weekIndex) {
                return TableRow(
                  children: List.generate(7, (colIndex) {
                    final dayNum = weekIndex * 7 + colIndex - startWeekday + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const SizedBox(height: 72);
                    }
                    final date = DateTime(month.year, month.month, dayNum);
                    final isToday = _isSameDay(date, today);
                    final logs = dayLogs[dayNum] ?? [];
                    final hasPhoto = logs.any((l) => l.photoPaths.isNotEmpty);

                    return GestureDetector(
                      onTap: () => hasPhoto ? _showDayPhotos(context, date, logs) : null,
                      child: Container(
                        height: 72,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: isToday
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: hasPhoto
                              ? Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 1)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text('$dayNum',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isToday ? FontWeight.bold : null,
                                  color: isToday ? Theme.of(context).colorScheme.primary : null,
                                )),
                            if (hasPhoto && logs.first.photoPaths.isNotEmpty)
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.file(
                                    File(logs.first.photoPaths.first),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 16, color: Colors.grey),
                                  ),
                                ),
                              )
                            else if (logs.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.touch_app, size: 14, color: Colors.grey),
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

  void _showDayPhotos(BuildContext context, DateTime date, List<PattingLogEntity> logs) {
    final photos = logs
        .expand((l) => l.photoPaths)
        .where((p) => p.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${date.month}月${date.day}日 打卡记录',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (photos.isEmpty)
              const Text('当天有打卡但无照片', style: TextStyle(color: Colors.grey))
            else
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(photos[i]),
                        width: 150, height: 200, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 150, height: 200,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        )),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text('共 ${logs.length} 条记录',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ===== 统计摘要条 =====

  Widget _buildStatsBar(BuildContext context, Map<String, int> categoryCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.diamond, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            '共 ${categoryCount.values.fold(0, (a, b) => a + b)} 件宝贝',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const Spacer(),
          Text(
            '${categoryCount.length} 个分类',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ===== 空状态 =====

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.diamond_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('还没有宝贝',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('点击右下角 + 添加第一件宝贝'),
        ],
      ),
    );
  }

  // ===== 搜索 =====

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(
      context: context,
      delegate: _AntiqueSearchDelegate(ref),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _AntiqueSearchDelegate extends SearchDelegate<AntiqueEntity?> {
  final WidgetRef ref;

  _AntiqueSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
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
      future: ref.read(antiqueRepositoryProvider.future).then((r) => r.search(query)),
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
