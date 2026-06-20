/// App root widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database_provider.dart';
import '../core/database/user_preferences_dao.dart';
import '../core/notification_service.dart';
import '../l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';

/// 主题模式 Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// 语言 Provider
final localeProvider = StateProvider<Locale>((ref) => const Locale('zh', 'CN'));

/// 应用是否已初始化
final appInitializedProvider = FutureProvider<bool>((ref) async {
  // 触发数据库初始化
  final db = await ref.watch(appDatabaseProvider.future);
  // 从数据库加载主题
  try {
    final dao = UserPreferencesDao(db);
    final prefs = await dao.getOrCreate();
    final themeModeStr = prefs.themeMode;
    switch (themeModeStr) {
      case 'light':
        ref.read(themeModeProvider.notifier).state = ThemeMode.light;
        break;
      case 'dark':
        ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
        break;
      default:
        ref.read(themeModeProvider.notifier).state = ThemeMode.system;
    }
  } catch (_) {}
  // 通知初始化放后台，不阻塞启动
  NotificationService().init();
  return true;
});

class PersonalAssistantApp extends ConsumerWidget {
  const PersonalAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '寸积',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      routerConfig: createRouter(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
        Locale('zh'),
        Locale('en'),
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale?.languageCode) {
            return supported;
          }
        }
        return supportedLocales.first;
      },
    );
  }
}

/// 启动页 — 等待数据库初始化
class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initState = ref.watch(appInitializedProvider);

    return initState.when(
      data: (_) => const PersonalAssistantApp(),
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/brand/cunji_logo.jpg',
                    width: 128,
                    height: 128,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '寸积',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('正在初始化...'),
              ],
            ),
          ),
        ),
      ),
      error: (err, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('初始化失败: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(appInitializedProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
