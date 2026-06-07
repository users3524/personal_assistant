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
import '../../features/ai_assistant/presentation/pages/review_home_page.dart';
import '../../features/ai_assistant/presentation/pages/daily_review_chat_page.dart';
import '../../features/ai_assistant/presentation/pages/daily_review_detail_page.dart';
import '../../features/ai_assistant/presentation/pages/weekly_report_page.dart';
import '../../features/resume/presentation/pages/resume_home_page.dart';
import '../../features/resume/presentation/pages/resume_preview_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

/// 主壳 - 底部导航
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.diamond_outlined),
            selectedIcon: Icon(Icons.diamond),
            label: '盘串',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: '待办',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: '复盘',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: '简历',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 创建路由配置
GoRouter createRouter() {
  return GoRouter(
    initialLocation: RouteNames.collectionList,
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
                      return AntiqueDetailPage(itemId: id);
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
          // Tab 1: 待办
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
          // Tab 2: 复盘
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.reviewHome,
                builder: (context, state) => const ReviewHomePage(),
                routes: [
                  GoRoute(
                    path: 'daily/new',
                    builder: (context, state) =>
                        const DailyReviewChatPage(),
                  ),
                  GoRoute(
                    path: 'daily/edit/:date',
                    builder: (context, state) {
                      final date = state.pathParameters['date']!;
                      return DailyReviewChatPage(dateStr: date);
                    },
                  ),
                  GoRoute(
                    path: 'daily/:date',
                    builder: (context, state) {
                      final date =
                          state.pathParameters['date']!;
                      return DailyReviewDetailPage(dateStr: date);
                    },
                  ),
                  GoRoute(
                    path: 'weekly/:id',
                    builder: (context, state) {
                      final id = int.parse(
                          state.pathParameters['id']!);
                      return WeeklyReportPage(weekNumber: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: 简历
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.resumeHome,
                builder: (context, state) => const ResumeHomePage(),
                routes: [
                  GoRoute(
                    path: 'preview',
                    builder: (context, state) =>
                        const ResumePreviewPage(),
                  ),
                  GoRoute(
                    path: 'templates',
                    builder: (context, state) =>
                        const ResumePreviewPage(),
                  ),
                ],
              ),
            ],
          ),
          // Tab 4: 设置
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
