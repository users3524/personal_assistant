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
    final gridColumns = ref.watch(gridColumnsProvider).valueOrNull ?? 2;
    final aspectRatio = gridColumns == 2 ? 0.78 : (gridColumns == 3 ? 0.85 : 0.9);

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
            : _buildGridView(context, ref, listAsync, categoryCount, gridColumns, aspectRatio),
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
          data: (items) => items.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState(context))
              : SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridColumns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: aspectRatio,
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
    final photosAsync = ref.watch(latestPattingPhotosProvider);
    final latestPhoto = photosAsync.valueOrNull?[item.id];
    final cover = latestPhoto ?? (item.imagePaths.isNotEmpty ? item.imagePaths.first : null);

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
                height: 300, child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SizedBox(
                height: 300, child: Center(child: Text('加载失败: $err')),
              ),
            ),
            const Divider(height: 24),
            // 趣味排行
            listAsync.when(
              data: (items) => _buildRankings(context, items, month),
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
      BuildContext context, DateTime month, Map<int, List<PattingLogEntity>> dayLogs) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday - 1;
    final daysInMonth = lastDay.day;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells + 6) ~/ 7;
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
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
        // 星期标签
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['一','二','三','四','五','六','日'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(d, style: TextStyle(fontSize: 12,
                      color: (d == '六' || d == '日') ? Colors.grey : null)),
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
                                    fit: BoxFit.cover, width: double.infinity,
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

  // ===== 趣味排行 =====

  Widget _buildRankings(BuildContext context, List<AntiqueEntity> items, DateTime month) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, size: 18, color: Colors.amber),
              const SizedBox(width: 6),
              Text('🏆 趣味排行',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 财富榜
        _buildWealthRank(context, items),
        const SizedBox(height: 8),
        // 侍寝榜
        _buildPattingRank(context, items),
        const SizedBox(height: 8),
        // 尺度榜
        _buildSizeRank(context, items),
      ],
    );
  }

  Widget _buildWealthRank(BuildContext context, List<AntiqueEntity> items) {
    final ranked = List<AntiqueEntity>.from(items)
      ..sort((a, b) => (b.currentValuation ?? b.acquiredPrice ?? 0)
          .compareTo(a.currentValuation ?? a.acquiredPrice ?? 0));
    final top = ranked.where((i) => (i.currentValuation ?? i.acquiredPrice ?? 0) > 0).take(5).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return _buildRankCard(
      title: '💰 财富榜',
      subtitle: '按当前估价排序',
      items: top,
      label: (i) => '¥${(i.currentValuation ?? i.acquiredPrice ?? 0).toStringAsFixed(0)}',
      icon: Icons.monetization_on,
    );
  }

  Widget _buildPattingRank(BuildContext context, List<AntiqueEntity> items) {
    return FutureBuilder<Map<int, int>>(
      future: ref.read(pattingFrequencyProvider.future),
      builder: (context, snapshot) {
        final freq = snapshot.data ?? {};
        final ranked = List<AntiqueEntity>.from(items)
          ..sort((a, b) => (freq[b.id] ?? 0).compareTo(freq[a.id] ?? 0));
        final top = ranked.where((i) => (freq[i.id] ?? 0) > 0).take(5).toList();
        if (top.isEmpty) return const SizedBox.shrink();

        return _buildRankCard(
          title: '💆 侍寝榜',
          subtitle: '按本月打卡次数排序',
          items: top,
          label: (i) => '${freq[i.id] ?? 0}次',
          icon: Icons.touch_app,
        );
      },
    );
  }

  Widget _buildSizeRank(BuildContext context, List<AntiqueEntity> items) {
    // 核桃按边宽、手串按尺寸分别排行
    final walnuts = items.where((i) => i.category == '核桃').toList();
    final bracelets = items.where((i) => i.category == '手串').toList();

    if (walnuts.isEmpty && bracelets.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.straighten, size: 16, color: Colors.brown),
              const SizedBox(width: 6),
              Text('📏 尺度榜', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.brown.shade700)),
              const Spacer(),
              Text('按尺寸大小排序', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 8),
            if (walnuts.isNotEmpty) ...[
              Text('🥜 核桃', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.brown)),
              _buildSizeList(context, walnuts, '边宽'),
            ],
            if (walnuts.isNotEmpty && bracelets.isNotEmpty) const SizedBox(height: 8),
            if (bracelets.isNotEmpty) ...[
              Text('📿 手串', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
              _buildSizeList(context, bracelets, '尺寸'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSizeList(BuildContext context, List<AntiqueEntity> items, String fieldKey) {
    // 从 categoryMetadata 中提取尺寸信息
    final withSize = items.where((i) =>
        i.categoryMetadata != null &&
        i.categoryMetadata!.keys.any((k) => k.contains(fieldKey))).toList();
    withSize.sort((a, b) => _extractSize(b.categoryMetadata!, fieldKey)
        .compareTo(_extractSize(a.categoryMetadata!, fieldKey)));

    if (withSize.isEmpty) return const Padding(
      padding: EdgeInsets.all(8),
      child: Text('暂无尺寸数据', style: TextStyle(fontSize: 11, color: Colors.grey)),
    );

    return Column(
      children: withSize.take(5).map((item) {
        final size = _extractSize(item.categoryMetadata!, fieldKey);
        return ListTile(
          dense: true,
          leading: Text('${withSize.indexOf(item) + 1}.',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          title: Text(item.name, style: const TextStyle(fontSize: 13)),
          trailing: Text(size > 0 ? '$size mm' : '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        );
      }).toList(),
    );
  }

  double _extractSize(Map<String, String> metadata, String fieldKey) {
    for (final entry in metadata.entries) {
      if (entry.key.contains(fieldKey)) {
        return double.tryParse(entry.value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      }
    }
    return 0;
  }

  Widget _buildRankCard({
    required String title,
    required String subtitle,
    required List<AntiqueEntity> items,
    required String Function(AntiqueEntity) label,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
              const Spacer(),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(
              dense: true,
              leading: Text('${items.indexOf(item) + 1}.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade700)),
              title: Text(item.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(item.subtype ?? item.category, style: const TextStyle(fontSize: 11)),
              trailing: Text(label(item),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            )),
          ],
        ),
      ),
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
