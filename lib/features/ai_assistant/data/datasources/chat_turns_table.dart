import 'package:drift/drift.dart';

const String createChatTurnsDateCloudIndex =
    'CREATE INDEX IF NOT EXISTS idx_chat_turns_date_cloud '
    'ON chat_turns(turn_date, consumes_cloud_turn)';
const String createChatTurnsDateCreatedIndex =
    'CREATE INDEX IF NOT EXISTS idx_chat_turns_date_created '
    'ON chat_turns(turn_date, created_at)';

const chatTurnIndexStatements = [
  createChatTurnsDateCloudIndex,
  createChatTurnsDateCreatedIndex,
];

@TableIndex.sql(createChatTurnsDateCloudIndex)
@TableIndex.sql(createChatTurnsDateCreatedIndex)
class ChatTurns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get turnDate => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  BoolColumn get isOffline => boolean().withDefault(const Constant(false))();
  BoolColumn get consumesCloudTurn =>
      boolean().withDefault(const Constant(false))();
  TextColumn get source =>
      text().withDefault(const Constant('daily_review_chat'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
