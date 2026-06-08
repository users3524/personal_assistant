/// 应用路由配置。
///
/// 使用 go_router 的 StatefulShellRoute 实现底部导航，
/// 每个 Tab 拥有独立的 Navigator 栈，切换 Tab 时保持状态。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';
import '../../features/todo/presentation/pages/todo_list_page.dart';
import '../../features/todo/presentation/pages/todo_form_page.dart';
import '../../features/todo/presentation/pages/todo_detail_page.dart';
import '../../features/collection/presentation/pages/antique_list_page.dart';
import '../../features/collection/presentation/pages/antique_form_page.dart';
import '../../features/collection/presentation/pages/antique_detail_page.dart';
import '../../features/ai_assistant/presentation/pages/daily_review_chat_page.dart';
import '../../features/ai_assistant/presentation/pages/daily_review_detail_page.dart';
import '../../features/ai_assistant/presentation/pages/weekly_report_page.dart';
import '../../features/resume/presentation/pages/resume_home_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

/// 主壳 - 底部导航（带切换动画）
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.diamond_outlined, selectedIcon: Icons.diamond, label: '盘串'),
      (icon: Icons.check_circle_outline, selectedIcon: Icons.check_circle, label: '待办'),
      (icon: Icons.description_outlined, selectedIcon: Icons.description, label: '简历'),
    ];

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final isSelected = navigationShell.currentIndex == index;
                final item = items[index];

                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      );
                    },
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              key: ValueKey('${index}_$isSelected'),
                              size: isSelected ? 28 : 24,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            style: TextStyle(
                              fontSize: isSelected ? 13 : 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            child: Text(item.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// 创建路由配置
GoRouter createRouter() {
  return GoRouter(
    initialLocation: RouteNames.todoList,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(
            key: state.pageKey,
            navigationShell: navigationShell,
          );
        },
        branches: [
          // Tab 0: 盘串
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.collectionList,
                builder: (context, state) => const AntiqueListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const AntiqueFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      final highlightLogId = int.tryParse(state.uri.queryParameters['highlightLog'] ?? '');
                      return AntiqueDetailPage(itemId: id, highlightLogId: highlightLogId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final id = int.parse(state.pathParameters['id']!);
                          return AntiqueFormPage(editId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Tab 1: 待办（含复盘入口）
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.todoList,
                builder: (context, state) => const TodoListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const TodoFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return TodoDetailPage(todoId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final id = int.parse(state.pathParameters['id']!);
                          return TodoFormPage(editId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: 简历
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.resumeHome,
                builder: (context, state) => const ResumeHomePage(),
              ),
            ],
          ),
        ],
      ),
      // 设置页面（全屏，不显示底部导航）
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      // 复盘页面（全屏，不显示底部导航）
      GoRoute(
        path: RouteNames.dailyReviewNew,
        builder: (context, state) => const DailyReviewChatPage(),
      ),
      GoRoute(
        path: RouteNames.dailyReviewEdit,
        builder: (context, state) {
          final date = state.pathParameters['date']!;
          return DailyReviewChatPage(dateStr: date);
        },
      ),
      GoRoute(
        path: RouteNames.dailyReviewDetail,
        builder: (context, state) {
          final date = state.pathParameters['date']!;
          return DailyReviewDetailPage(dateStr: date);
        },
      ),
      GoRoute(
        path: RouteNames.weeklyReportDetail,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return WeeklyReportPage(weekNumber: id);
        },
      ),
    ],
  );
}
