/// 文玩包列表页 — 网格/月历双视图 + 每日翻牌推荐。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';
import '../widgets/antique_grid_card.dart';
import '../../../settings/presentation/providers/category_management_providers.dart';

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
    final aspectRatio = gridColumns == 2 ? 0.78 : (gridColumns == 3 ? 0.85 : 0.9);

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
          data: (items) {
            // 分类筛选
            final filter = ref.watch(categoryDisplayFilterProvider);
            final filtered = filter.isEmpty
                ? items
                : items.where((i) => i.category == filter).toList();

            if (filtered.isEmpty) {
              return const SliverFillRemaining(child: Center(child: Text('该分类暂无藏品')));
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
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = filtered[index];
                    return _buildGridCard(context, ref, item);
                  },
                  childCount: filtered.length,
                ),
              ),
            );
          },
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
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      ref.invalidate(dailyPickProvider);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.replay, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 2),
                          Text('换一换', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
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

    // 建立 itemId → itemName 映射
    final itemsAsync = ref.watch(antiqueListProvider);
    final itemNames = <int, String>{};
    if (itemsAsync.valueOrNull != null) {
      for (final item in itemsAsync.valueOrNull!) {
        if (item.id != null) itemNames[item.id!] = item.name;
      }
    }

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
                      onTap: () => hasPhoto ? _onDayTap(context, date, logs) : null,
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
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.file(
                                        File(logs.first.photoPaths.first),
                                        fit: BoxFit.cover, width: double.infinity,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 16, color: Colors.grey),
                                      ),
                                    ),
                                    // 物品名称叠加
                                    Positioned(
                                      bottom: 0, left: 0, right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(4),
                                            bottomRight: Radius.circular(4),
                                          ),
                                        ),
                                        child: Text(
                                          itemNames[logs.first.itemId] ?? '',
                                          style: const TextStyle(color: Colors.white, fontSize: 8),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _buildRankTab('💰 财富榜', 0),
              _buildRankTab('💆 侍寝榜', 1),
              _buildRankTab('🥜 核桃榜', 2),
              _buildRankTab('🏆 老炮榜', 3),
              _buildRankTab('📈 潜力榜', 4),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        // 用 tabIndex 切换
        _buildRankContent(context, items, month),
      ],
    );
  }

  int _rankTabIndex = 0;
  Widget _buildRankTab(String label, int index) {
    final selected = _rankTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _rankTabIndex = index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : null)),
      ),
    );
  }

  Widget _buildRankContent(BuildContext context, List<AntiqueEntity> items, DateTime month) {
    switch (_rankTabIndex) {
      case 1: return _buildPattingRank(context, items);
      case 2: return _buildSizeRank(context, items);
      case 3: return _buildVeteranRank(context, items);
      case 4: return _buildPotentialRank(context, items);
      default: return _buildWealthRank(context, items);
    }
  }

  Widget _buildWealthRank(BuildContext context, List<AntiqueEntity> items) {
    final ranked = List<AntiqueEntity>.from(items)
      ..sort((a, b) => (b.currentValuation ?? b.acquiredPrice ?? 0)
          .compareTo(a.currentValuation ?? a.acquiredPrice ?? 0));
    final top = ranked.where((i) => (i.currentValuation ?? i.acquiredPrice ?? 0) > 0).take(10).toList();
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
      future: ref.read(monthlyPattingFrequencyProvider.future),
      builder: (context, snapshot) {
        final freq = snapshot.data ?? {};
        final ranked = List<AntiqueEntity>.from(items)
          ..sort((a, b) => (freq[b.id] ?? 0).compareTo(freq[a.id] ?? 0));
        final top = ranked.where((i) => (freq[i.id] ?? 0) > 0).take(10).toList();
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
    // 只考虑核桃品类
    final walnutItems = items.where((i) => i.category == '核桃').toList();
    final withSize = walnutItems.where((i) =>
        i.categoryMetadata != null &&
        i.categoryMetadata!.keys.any((k) => k.contains('边宽') || k.contains('尺寸'))).toList();
    withSize.sort((a, b) => _extractSize(b.categoryMetadata!, '边宽')
        .compareTo(_extractSize(a.categoryMetadata!, '边宽')));

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
                Text('暂无核桃尺寸数据，请在藏品详情中添加尺寸信息',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
        return double.tryParse(entry.value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
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

  Widget _buildPotentialRank(BuildContext context, List<AntiqueEntity> items) {
    final withPrice = items.where((i) =>
        i.acquiredPrice != null && i.acquiredPrice! > 0 &&
        i.currentValuation != null && i.currentValuation! > 0).toList();
    withPrice.sort((a, b) {
      final aRate = (b.currentValuation! - b.acquiredPrice!) / b.acquiredPrice!;
      final bRate = (a.currentValuation! - a.acquiredPrice!) / a.acquiredPrice!;
      return aRate.compareTo(bRate);
    });
    final top = withPrice.take(5).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return _buildRankCard(
      title: '📈 潜力榜',
      subtitle: '按升值幅度排序',
      items: top,
      label: (i) {
        final rate = ((i.currentValuation! - i.acquiredPrice!) / i.acquiredPrice! * 100);
        return '${rate.toStringAsFixed(0)}%';
      },
      icon: Icons.trending_up,
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
            const SizedBox(height: 10),
            // 前三名阶梯展示：2左 1中 3右
            if (top3.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 第2名（左）
                  if (top3.length >= 2)
                    Expanded(child: _buildPodiumItem(top3[1], 2, label)),
                  const SizedBox(width: 6),
                  // 第1名（中）
                  Expanded(child: _buildPodiumItem(top3[0], 1, label)),
                  const SizedBox(width: 6),
                  // 第3名（右）
                  if (top3.length >= 3)
                    Expanded(child: _buildPodiumItem(top3[2], 3, label)),
                  if (top3.length < 3) const Expanded(child: SizedBox.shrink()),
                ],
              ),
            // 4-10名列表
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              ...rest.asMap().entries.map((entry) {
                final rank = entry.key + 4;
                final item = entry.value;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: Text('$rank.', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  title: Text(item.name, style: const TextStyle(fontSize: 12)),
                  subtitle: Text(item.subtype ?? item.category, style: const TextStyle(fontSize: 10)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label(item), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.green)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: () => context.push('/collection/${item.id}'),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumItem(AntiqueEntity item, int rank, String Function(AntiqueEntity) label) {
    final medals = ['🥇', '🥈', '🥉'];
    final colors = [Colors.amber.shade200, Colors.grey.shade300, Colors.brown.shade200];
    final cover = item.imagePaths.isNotEmpty ? item.imagePaths.first : null;
    final photosAsync = ref.watch(latestPattingPhotosProvider);
    final latestPhoto = photosAsync.valueOrNull?[item.id];
    final displayImage = latestPhoto ?? cover;

    return GestureDetector(
      onTap: () => context.push('/collection/${item.id}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 50x50 图片
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: rank == 1 ? 56 : 50,
              height: 50,
              color: colors[rank - 1].withValues(alpha: 0.3),
              child: displayImage != null
                  ? Image.file(File(displayImage), width: 50, height: 50, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        rank == 1 ? Icons.emoji_events : Icons.diamond, size: 24, color: colors[rank - 1]))
                  : Icon(rank == 1 ? Icons.emoji_events : Icons.diamond, size: 24, color: colors[rank - 1]),
            ),
          ),
          const SizedBox(height: 3),
          Text(medals[rank - 1], style: const TextStyle(fontSize: 14)),
          Text(item.name,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label(item),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
        ],
      ),
    );
  }

  void _onDayTap(BuildContext context, DateTime date, List<PattingLogEntity> logs) {
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dateStr 打卡记录',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...logs.take(10).map((log) {
              final days = log.date.difference(DateTime(log.date.year, log.date.month, log.date.day)).inDays;
              final dayLabel = days == 0 ? '入手当天' : '第$days天';
              return ListTile(
                dense: true,
                leading: log.photoPaths.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(log.photoPaths.first),
                            width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 24, color: Colors.grey)),
                      )
                    : const Icon(Icons.touch_app, color: Colors.grey),
                title: Text(dayLabel, style: const TextStyle(fontSize: 13)),
                subtitle: Text(log.note ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/collection/${log.itemId}?highlightLog=${log.id ?? ''}');
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text('🏛️ 共${categoryCount.values.fold(0, (a, b) => a + b)}件',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
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
        ...categories.map((c) => PopupMenuItem(
          value: c.name,
          child: Text(c.name),
        )),
      ],
      child: Chip(
        label: Text(selectedFilter.isEmpty ? '筛选' : selectedFilter, style: const TextStyle(fontSize: 11)),
        avatar: const Icon(Icons.filter_list, size: 14),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
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
