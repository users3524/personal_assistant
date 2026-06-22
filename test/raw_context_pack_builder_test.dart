import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/raw_context_clipper.dart';
import 'package:personal_assistant/core/ai/raw_context_pack_builder.dart';
import 'package:personal_assistant/core/ai/raw_context_pack_clipper.dart';
import 'package:personal_assistant/core/database/app_database.dart';

void main() {
  group('RawContextPackBuilder', () {
    late AppDatabase db;
    late RawContextPackBuilder builder;
    final generatedAt = DateTime(2026, 6, 22, 3, 5);

    setUp(() {
      db = AppDatabase.createInMemory();
      builder = RawContextPackBuilder(db, now: () => generatedAt);
    });

    tearDown(() async {
      await db.close();
    });

    test('builds an empty pack with target-date metadata', () async {
      final pack = await builder.build(DateTime(2026, 6, 21, 18));
      final json = pack.toJson();

      expect(pack.targetDate, '2026-06-21');
      expect(pack.generatedAt, generatedAt);
      expect(pack.timezoneOffsetMinutes, generatedAt.timeZoneOffset.inMinutes);
      expect(pack.todos, isEmpty);
      expect(pack.chatTurns, isEmpty);
      expect(pack.dailyReviewDraft, isNull);
      expect(pack.pattingLogs, isEmpty);
      expect(json, containsPair('target_date', '2026-06-21'));
      expect(jsonDecode(pack.toJsonString()), json);
    });

    test('loads mixed target-day materials with half-open ranges', () async {
      await _insertTodo(
        db,
        title: 'Done launch',
        status: 'done',
        priority: 5,
        completedAt: DateTime(2026, 6, 21, 10),
        actualMinutes: 45,
        tags: ['ship'],
      );
      await _insertTodo(
        db,
        title: 'Due today',
        priority: 4,
        dueDate: DateTime(2026, 6, 21, 23, 59),
      );
      await _insertTodo(
        db,
        title: 'Overdue active',
        status: 'in_progress',
        priority: 2,
        startedAt: DateTime(2026, 6, 20, 9),
        createdAt: DateTime(2026, 6, 20, 9),
      );
      await _insertTodo(
        db,
        title: 'Done tomorrow boundary',
        status: 'done',
        completedAt: DateTime(2026, 6, 22),
      );
      await _insertTodo(
        db,
        title: 'Deleted today',
        dueDate: DateTime(2026, 6, 21, 12),
        deletedAt: DateTime(2026, 6, 21, 13),
      );
      await _insertTodo(
        db,
        title: 'Cancelled today',
        status: 'cancelled',
        dueDate: DateTime(2026, 6, 21, 14),
        cancelledAt: DateTime(2026, 6, 21, 15),
      );

      await _insertChatTurn(
        db,
        content: 'second',
        createdAt: DateTime(2026, 6, 21, 9, 1),
      );
      await _insertChatTurn(
        db,
        role: 'assistant',
        content: 'first',
        createdAt: DateTime(2026, 6, 21, 9),
      );
      await _insertChatTurn(
        db,
        turnDate: '2026-06-22',
        content: 'other day',
        createdAt: DateTime(2026, 6, 22),
      );

      await _insertDailyReview(
        db,
        date: DateTime(2026, 6, 21, 12),
        summary: 'A steady day',
        highlights: 'Finished launch prep',
        improvements: 'Sleep earlier',
      );

      final itemId = await _insertAntiqueItem(db);
      await _insertPattingLog(
        db,
        itemId: itemId,
        date: DateTime(2026, 6, 21, 8),
        durationMinutes: 40,
        photoPaths: ['relative/a.jpg', 'relative/b.jpg'],
      );
      await _insertPattingLog(
        db,
        itemId: itemId,
        date: DateTime(2026, 6, 21, 20),
        durationMinutes: 15,
        note: 'Surface looked warmer',
      );
      await _insertPattingLog(
        db,
        itemId: itemId,
        date: DateTime(2026, 6, 22),
        durationMinutes: 99,
        note: 'Boundary next day',
      );

      final pack = await builder.build(DateTime(2026, 6, 21, 16));

      expect(pack.todos.map((todo) => todo['title']), [
        'Done launch',
        'Due today',
        'Overdue active',
      ]);
      expect(pack.todos.first['status'], 'done');
      expect(pack.todos.first['actual_minutes'], 45);
      expect(pack.chatTurns.map((turn) => turn['content']), [
        'first',
        'second',
      ]);
      expect(pack.dailyReviewDraft, containsPair('summary', 'A steady day'));
      expect(pack.pattingLogs.map((log) => log['note']), [
        'Surface looked warmer',
        null,
      ]);
      expect(pack.pattingLogs.last['photo_count'], 2);

      final clipperItems = pack.toClipperItems();
      expect(clipperItems, hasLength(8));
      expect(
        clipperItems
            .where((item) => item.source == RawContextSource.todo)
            .first
            .isCompletedTodo,
        true,
      );
      expect(
        clipperItems
            .where((item) => item.source == RawContextSource.chatTurn)
            .last
            .isCoachingTurn,
        true,
      );
      expect(
        clipperItems
            .where((item) => item.source == RawContextSource.pattingLog)
            .first
            .hasPattingNote,
        true,
      );
    });

    test('redacts privacy-sensitive fields from serialized pack', () async {
      final base64Blob = List.filled(96, 'Q').join();
      final imageDataUrl =
          'data:image/png;base64,${List.filled(96, 'A').join()}';
      const apiKey = 'sk-testSecretKeyValue123456';
      const backupPath =
          r'C:\Users\me\AppData\Roaming\personal assistant\backup.json';
      const secureStorageRef = 'secure_storage:ai_api_key';

      await _insertTodo(
        db,
        title: 'Rotate $apiKey',
        status: 'done',
        completedAt: DateTime(2026, 6, 21, 10),
        tags: [base64Blob],
      );
      await _insertChatTurn(
        db,
        content: 'image=$imageDataUrl backup=$backupPath',
        createdAt: DateTime(2026, 6, 21, 9),
      );
      await _insertDailyReview(
        db,
        date: DateTime(2026, 6, 21),
        summary:
            'Do not keep /tmp/nightly-backup-2026.json or $secureStorageRef',
      );
      final itemId = await _insertAntiqueItem(db);
      await _insertPattingLog(
        db,
        itemId: itemId,
        date: DateTime(2026, 6, 21, 20),
        durationMinutes: 20,
        note: 'Photo path must stay private',
        photoPaths: [imageDataUrl, backupPath],
      );

      final pack = await builder.build(DateTime(2026, 6, 21));
      final dump = pack.toJsonString();

      expect(dump, contains('[redacted_api_key]'));
      expect(dump, contains('[redacted_image_base64]'));
      expect(dump, contains('[redacted_base64]'));
      expect(dump, contains('[redacted_backup_path]'));
      expect(dump, contains('[redacted_secure_storage_ref]'));
      expect(dump, isNot(contains(apiKey)));
      expect(dump, isNot(contains(imageDataUrl)));
      expect(dump, isNot(contains(base64Blob)));
      expect(dump, isNot(contains('backup.json')));
      expect(dump, isNot(contains(secureStorageRef)));
      expect(dump, isNot(contains('photoPaths')));
      expect(dump, contains('"photo_count":2'));
    });
  });

  group('RawContextPackClipper', () {
    late AppDatabase db;
    final generatedAt = DateTime(2026, 6, 22, 3, 5);

    setUp(() {
      db = AppDatabase.createInMemory();
    });

    tearDown(() async {
      await db.close();
    });

    test('clips real raw pack into semantic JSON with metadata', () async {
      await _insertTodo(
        db,
        title: 'High completed',
        status: 'done',
        priority: 5,
        completedAt: DateTime(2026, 6, 21, 10),
      );
      await _insertChatTurn(
        db,
        content: 'cloud user turn',
        consumesCloudTurn: true,
        createdAt: DateTime(2026, 6, 21, 9),
      );
      await _insertChatTurn(
        db,
        role: 'assistant',
        content: List.filled(600, 'x').join(),
        consumesCloudTurn: false,
        createdAt: DateTime(2026, 6, 21, 9, 1),
      );
      final itemId = await _insertAntiqueItem(db);
      await _insertPattingLog(
        db,
        itemId: itemId,
        date: DateTime(2026, 6, 21, 20),
        durationMinutes: 15,
        note: 'Surface looked warmer',
      );

      final packBuilder = RawContextPackBuilder(db, now: () => generatedAt);
      final fullPack = await packBuilder.build(DateTime(2026, 6, 21));
      final inputItems = fullPack.toClipperItems();
      final keepBudget = inputItems
          .where(
            (item) =>
                item.isCompletedTodo ||
                item.isCoachingTurn ||
                item.hasPattingNote,
          )
          .fold<int>(0, (total, item) => total + item.charCount);
      final clipped = await RawContextPackClipper(
        packBuilder: packBuilder,
        clipper: RawContextClipper(budgetChars: keepBudget),
      ).build(DateTime(2026, 6, 21));

      final encoded = clipped.toJsonString();
      final json = jsonDecode(encoded) as Map<String, Object?>;
      final clip = json['clip'] as Map<String, Object?>;
      final droppedItems = clip['dropped_items'] as List<Object?>;

      expect(json['target_date'], '2026-06-21');
      expect(clip['input_chars'], greaterThan(clip['kept_chars'] as int));
      expect(clip['kept_count'], 3);
      expect(clip['dropped_count'], 1);
      expect(droppedItems.single, containsPair('reason', 'budget_exceeded'));
      expect(
        (json['todos'] as List<Object?>).single,
        containsPair('title', 'High completed'),
      );
      expect(
        (json['chat_turns'] as List<Object?>).single,
        containsPair('content', 'cloud user turn'),
      );
      expect(
        (json['patting_logs'] as List<Object?>).single,
        containsPair('note', 'Surface looked warmer'),
      );
      expect(encoded, isNot(contains(List.filled(120, 'x').join())));
    });
  });
}

Future<int> _insertTodo(
  AppDatabase db, {
  required String title,
  String status = 'pending',
  int priority = 3,
  DateTime? dueDate,
  DateTime? startedAt,
  DateTime? completedAt,
  DateTime? cancelledAt,
  DateTime? deletedAt,
  int? actualMinutes,
  List<String> tags = const [],
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2026, 6, 21, 8);
  return db
      .into(db.todos)
      .insert(
        TodosCompanion.insert(
          title: title,
          priority: Value(priority),
          dueDate: Value(dueDate),
          status: Value(status),
          tags: Value(tags),
          startedAt: Value(startedAt),
          completedAt: Value(completedAt),
          cancelledAt: Value(cancelledAt),
          deletedAt: Value(deletedAt),
          actualMinutes: Value(actualMinutes),
          createdAt: Value(created),
          updatedAt: Value(created),
        ),
      );
}

Future<int> _insertChatTurn(
  AppDatabase db, {
  String turnDate = '2026-06-21',
  String role = 'user',
  required String content,
  bool isOffline = false,
  bool consumesCloudTurn = true,
  required DateTime createdAt,
}) {
  return db
      .into(db.chatTurns)
      .insert(
        ChatTurnsCompanion.insert(
          turnDate: turnDate,
          role: role,
          content: content,
          isOffline: Value(isOffline),
          consumesCloudTurn: Value(consumesCloudTurn),
          createdAt: Value(createdAt),
        ),
      );
}

Future<int> _insertDailyReview(
  AppDatabase db, {
  required DateTime date,
  required String summary,
  String? highlights,
  String? improvements,
}) {
  return db
      .into(db.dailyReviews)
      .insert(
        DailyReviewsCompanion.insert(
          date: date,
          summary: summary,
          highlights: Value(highlights),
          improvements: Value(improvements),
          energyLevel: 3,
          moodLevel: 4,
          pattingMinutes: const Value(55),
          updatedAt: Value(DateTime(2026, 6, 21, 23)),
        ),
      );
}

Future<int> _insertAntiqueItem(AppDatabase db) {
  return db
      .into(db.antiqueItems)
      .insert(
        AntiqueItemsCompanion.insert(
          name: 'Olive bracelet',
          category: 'wood',
          acquiredDate: DateTime(2026, 1, 1),
        ),
      );
}

Future<int> _insertPattingLog(
  AppDatabase db, {
  required int itemId,
  required DateTime date,
  required int durationMinutes,
  String? note,
  List<String> photoPaths = const [],
}) {
  return db
      .into(db.pattingLogs)
      .insert(
        PattingLogsCompanion.insert(
          itemId: itemId,
          date: date,
          durationMinutes: durationMinutes,
          method: 'bare_hand',
          note: Value(note),
          photoPaths: Value(photoPaths),
        ),
      );
}
