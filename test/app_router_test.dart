import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/app/router/app_router.dart';
import 'package:personal_assistant/app/router/route_names.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/core/database/app_database_provider.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/review_dao.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/review_entity.dart';

void main() {
  group('app router', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.createInMemory();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('opens review home inside the main tab shell', (tester) async {
      final router = createRouter(initialLocation: RouteNames.reviewHome);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI 复盘'), findsOneWidget);
      expect(find.text('AI 每日复盘'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
      expect(find.text('盘串'), findsOneWidget);
      expect(find.text('待办'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('复盘'), findsOneWidget);
      expect(find.text('简历'), findsOneWidget);
    });

    testWidgets('opens monthly review calendar with existing daily review', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final reviewDate = DateTime(now.year, now.month, now.day);
      await ReviewDao(db).insertDaily(
        DailyReviewEntity(
          date: reviewDate,
          summary: '月度日历测试日报',
          moodLevel: 5,
          energyLevel: 4,
          createdAt: reviewDate,
          updatedAt: reviewDate,
        ),
      );
      final router = createRouter(initialLocation: RouteNames.reviewHome);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '查看全部'));
      await tester.pumpAndSettle();

      expect(find.text('${now.year}年${now.month}月复盘日历'), findsOneWidget);
      for (final label in ['一', '二', '三', '四', '五', '六', '日']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('${reviewDate.day}'), findsOneWidget);
      expect(find.text('😄'), findsWidgets);
    });
  });
}
