/// Application routes and the main tab shell.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/presentation/pages/daily_review_chat_page.dart';
import '../../features/ai_assistant/presentation/pages/daily_review_detail_page.dart';
import '../../features/ai_assistant/presentation/pages/review_home_page.dart';
import '../../features/ai_assistant/presentation/pages/weekly_report_page.dart';
import '../../features/collection/presentation/pages/antique_detail_page.dart';
import '../../features/collection/presentation/pages/antique_form_page.dart';
import '../../features/collection/presentation/pages/antique_list_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/resume/presentation/pages/resume_home_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/todo/presentation/pages/todo_detail_page.dart';
import '../../features/todo/presentation/pages/todo_form_page.dart';
import '../../features/todo/presentation/pages/todo_list_page.dart';
import '../theme/app_colors.dart';
import 'route_names.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(
        icon: Icons.diamond_outlined,
        selectedIcon: Icons.diamond,
        label: '盘串',
      ),
      _NavItem(
        icon: Icons.check_circle_outline,
        selectedIcon: Icons.check_circle,
        label: '待办',
      ),
      _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: '今天',
      ),
      _NavItem(
        icon: Icons.auto_awesome_outlined,
        selectedIcon: Icons.auto_awesome,
        label: '复盘',
      ),
      _NavItem(
        icon: Icons.description_outlined,
        selectedIcon: Icons.description,
        label: '简历',
      ),
    ];

    return Scaffold(
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
            return;
          }
          if (navigationShell.currentIndex != 2) {
            navigationShell.goBranch(2);
          }
        },
        child: navigationShell,
      ),
      bottomNavigationBar: _BottomNav(
        items: items,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = currentIndex == index;
              final color = selected ? AppColors.primary : AppColors.muted;

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryLight.withValues(alpha: 0.45)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: selected ? 27 : 23,
                          color: color,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: selected ? 12 : 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: color,
                          ),
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
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

GoRouter createRouter({String initialLocation = RouteNames.dashboard}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(
            key: state.pageKey,
            navigationShell: navigationShell,
          );
        },
        branches: [
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
                      final highlightLogId = int.tryParse(
                        state.uri.queryParameters['highlightLog'] ?? '',
                      );
                      return AntiqueDetailPage(
                        itemId: id,
                        highlightLogId: highlightLogId,
                      );
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.todoList,
                builder: (context, state) => const TodoListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) {
                      final initialListId = int.tryParse(
                        state.uri.queryParameters['listId'] ?? '',
                      );
                      final initialCategory =
                          state.uri.queryParameters['category'];
                      return TodoFormPage(
                        initialListId: initialListId,
                        initialCategory: initialCategory,
                      );
                    },
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.dashboard,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.reviewHome,
                builder: (context, state) => const ReviewHomePage(),
              ),
            ],
          ),
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
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),
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
          final year = int.tryParse(state.uri.queryParameters['year'] ?? '');
          return WeeklyReportPage(year: year, weekNumber: id);
        },
      ),
    ],
  );
}
