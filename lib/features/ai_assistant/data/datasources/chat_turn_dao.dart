import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/chat_turn_entity.dart';

class ChatTurnDao {
  final AppDatabase _db;

  ChatTurnDao(this._db);

  ChatTurnEntity _toEntity(ChatTurn row) => ChatTurnEntity(
    id: row.id,
    turnDate: row.turnDate,
    role: row.role,
    content: row.content,
    isOffline: row.isOffline,
    consumesCloudTurn: row.consumesCloudTurn,
    source: row.source,
    createdAt: row.createdAt,
  );

  ChatTurnsCompanion _toCompanion(ChatTurnEntity entity) => ChatTurnsCompanion(
    turnDate: Value(entity.turnDate),
    role: Value(entity.role),
    content: Value(entity.content),
    isOffline: Value(entity.isOffline),
    consumesCloudTurn: Value(entity.consumesCloudTurn),
    source: Value(entity.source),
    createdAt: Value(entity.createdAt),
  );

  Future<ChatTurnEntity> insert(ChatTurnEntity entity) async {
    final id = await _db.into(_db.chatTurns).insert(_toCompanion(entity));
    return entity.copyWith(id: id);
  }

  Future<int> countCloudTurns(String turnDate) async {
    final count = _db.chatTurns.id.count();
    final row =
        await (_db.selectOnly(_db.chatTurns)
              ..addColumns([count])
              ..where(
                _db.chatTurns.turnDate.equals(turnDate) &
                    _db.chatTurns.role.equals('user') &
                    _db.chatTurns.consumesCloudTurn.equals(true),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<List<ChatTurnEntity>> getByDate(String turnDate) async {
    final rows =
        await (_db.select(_db.chatTurns)
              ..where((t) => t.turnDate.equals(turnDate))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows.map(_toEntity).toList();
  }
}
