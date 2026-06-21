import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/core/database/app_database_provider.dart';
import 'package:personal_assistant/features/resume/presentation/providers/resume_providers.dart';

void main() {
  group('resume providers', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.createInMemory();
    });

    tearDown(() async {
      await db.close();
    });

    ProviderContainer createContainer() => ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
    );

    test('persists selected resume template id', () async {
      final firstContainer = createContainer();
      addTearDown(firstContainer.dispose);

      expect(await firstContainer.read(selectedTemplateIdProvider.future), 0);

      await firstContainer.read(selectedTemplateIdProvider.notifier).select(2);

      final secondContainer = createContainer();
      addTearDown(secondContainer.dispose);

      expect(await secondContainer.read(selectedTemplateIdProvider.future), 2);
    });
  });
}
