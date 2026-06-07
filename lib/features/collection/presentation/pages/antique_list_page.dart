/// 盘串列表页 — 网格视图。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';
import '../widgets/antique_grid_card.dart';

class AntiqueListPage extends ConsumerWidget {
  const AntiqueListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(antiqueListProvider);
    final categoryCount = ref.watch(categoryCountProvider).valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的盘串'),
        actions: [
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
      body: Column(
        children: [
          // 统计摘要条
          _buildStatsBar(context, categoryCount),
          // 藏品网格
          Expanded(
            child: listAsync.when(
              data: (items) => items.isEmpty
                  ? _buildEmptyState(context)
                  : _buildGridView(context, ref, items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('加载失败: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/collection/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatsBar(
    BuildContext context,
    Map<String, int> categoryCount,
  ) {
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

  Widget _buildGridView(
    BuildContext context,
    WidgetRef ref,
    List<AntiqueEntity> items,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.read(antiqueListProvider.notifier).refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return AntiqueGridCard(
            item: item,
            onTap: () => context.push('/collection/${item.id}'),
          );
        },
      ),
    );
  }

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
