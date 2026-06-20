import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/app/router/app_router.dart';
import 'package:personal_assistant/app/router/route_names.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/core/database/app_database_provider.dart';

void main() {
  group('app router', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.createInMemory();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('opens review home as a standalone full-screen route', (
      tester,
    ) async {
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
      expect(find.text('盘串'), findsNothing);
      expect(find.text('待办'), findsNothing);
      expect(find.text('简历'), findsNothing);
    });
  });
}
