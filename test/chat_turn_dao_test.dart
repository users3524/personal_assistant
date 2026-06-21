import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/chat_turn_dao.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/chat_turn_entity.dart';

void main() {
  group('ChatTurnDao', () {
    late AppDatabase db;
    late ChatTurnDao dao;

    setUp(() {
      db = AppDatabase.createInMemory();
      dao = ChatTurnDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('counts only online user turns for the requested day', () async {
      await dao.insert(
        _turn(
          turnDate: '2026-06-21',
          role: 'user',
          content: 'cloud user turn',
          consumesCloudTurn: true,
        ),
      );
      await dao.insert(
        _turn(
          turnDate: '2026-06-21',
          role: 'assistant',
          content: 'assistant reply',
          consumesCloudTurn: true,
        ),
      );
      await dao.insert(
        _turn(
          turnDate: '2026-06-21',
          role: 'user',
          content: 'offline note',
          isOffline: true,
        ),
      );
      await dao.insert(
        _turn(
          turnDate: '2026-06-20',
          role: 'user',
          content: 'previous day',
          consumesCloudTurn: true,
        ),
      );

      expect(await dao.countCloudTurns('2026-06-21'), 1);
      expect(await dao.countCloudTurns('2026-06-20'), 1);
    });

    test('returns turns for a day in creation order', () async {
      await dao.insert(
        _turn(
          turnDate: '2026-06-21',
          role: 'user',
          content: 'second',
          createdAt: DateTime(2026, 6, 21, 9, 1),
        ),
      );
      await dao.insert(
        _turn(
          turnDate: '2026-06-21',
          role: 'assistant',
          content: 'first',
          createdAt: DateTime(2026, 6, 21, 9),
        ),
      );
      await dao.insert(
        _turn(
          turnDate: '2026-06-22',
          role: 'user',
          content: 'other day',
          createdAt: DateTime(2026, 6, 22),
        ),
      );

      final turns = await dao.getByDate('2026-06-21');

      expect(turns.map((turn) => turn.content), ['first', 'second']);
      expect(turns.every((turn) => turn.turnDate == '2026-06-21'), true);
    });
  });
}

ChatTurnEntity _turn({
  required String turnDate,
  required String role,
  required String content,
  bool isOffline = false,
  bool consumesCloudTurn = false,
  DateTime? createdAt,
}) {
  return ChatTurnEntity(
    turnDate: turnDate,
    role: role,
    content: content,
    isOffline: isOffline,
    consumesCloudTurn: consumesCloudTurn,
    createdAt: createdAt ?? DateTime(2026, 6, 21, 9),
  );
}
