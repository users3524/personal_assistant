import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/chat_turns_table.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/review_generation_jobs_table.dart';
import 'package:personal_assistant/features/collection/data/datasources/patting_logs_table.dart';
import 'package:personal_assistant/features/todo/data/datasources/todos_table.dart';
import 'package:drift/native.dart';

void main() {
  group('AppDatabase migrations', () {
    test('new schema contains query indexes', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(db.close);

      expect(await _todoIndexNames(db), _expectedTodoIndexNames);
      expect(await _pattingLogIndexNames(db), _expectedPattingLogIndexNames);
      expect(await _chatTurnIndexNames(db), _expectedChatTurnIndexNames);
      expect(
        await _reviewGenerationJobIndexNames(db),
        _expectedReviewGenerationJobIndexNames,
      );
    });

    test('upgrades v6 databases with query indexes', () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute(_createV6UserPreferencesTableSql);
            rawDb.execute(_createV6TodosTableSql);
            rawDb.execute(_createV6PattingLogsTableSql);
            rawDb.execute('PRAGMA user_version = 6');
          },
        ),
      );
      addTearDown(db.close);

      expect(await _todoIndexNames(db), _expectedTodoIndexNames);
      expect(await _pattingLogIndexNames(db), _expectedPattingLogIndexNames);
    });

    test('upgrades v8 user preferences with ai config column', () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute(_createV8UserPreferencesTableSql);
            rawDb.execute('''
INSERT INTO user_preferences (
  id, theme_mode, language, notification_enabled, ai_provider, ai_api_key,
  ai_base_url, ai_model, daily_review_time, weekly_report_day,
  resume_template_id, todo_categories, created_at, updated_at
) VALUES (
  1, 'system', 'zh', 1, 'OpenAI', NULL, 'https://api.openai.com/v1',
  'gpt-4o-mini', '21:00', 'sunday', 0, '[]',
  strftime('%s', 'now'), strftime('%s', 'now')
);
''');
            rawDb.execute('PRAGMA user_version = 8');
          },
        ),
      );
      addTearDown(db.close);

      final columns = await _columnNames(db, 'user_preferences');
      final prefs = await db.select(db.userPreferences).getSingle();

      expect(columns, contains('ai_config'));
      expect(prefs.aiProvider, 'OpenAI');
      expect(prefs.aiConfig, null);
    });

    test('upgrades v9 databases with chat turns table and indexes', () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute(_createV9UserPreferencesTableSql);
            rawDb.execute('PRAGMA user_version = 9');
          },
        ),
      );
      addTearDown(db.close);

      final columns = await _columnNames(db, 'chat_turns');

      expect(columns, containsAll(['turn_date', 'consumes_cloud_turn']));
      expect(await _chatTurnIndexNames(db), _expectedChatTurnIndexNames);
      expect(
        await _reviewGenerationJobIndexNames(db),
        _expectedReviewGenerationJobIndexNames,
      );
    });

    test('upgrades v10 databases with review generation jobs table', () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute(_createV10UserPreferencesTableSql);
            rawDb.execute(_createV10ChatTurnsTableSql);
            rawDb.execute('PRAGMA user_version = 10');
          },
        ),
      );
      addTearDown(db.close);

      final columns = await _columnNames(db, 'review_generation_jobs');

      expect(
        columns,
        containsAll([
          'target_date',
          'status',
          'raw_assets_dump',
          'attempt_count',
          'failure_reason',
          'processed_at',
          'created_at',
        ]),
      );
      expect(
        await _reviewGenerationJobIndexNames(db),
        _expectedReviewGenerationJobIndexNames,
      );
    });
  });
}

final _expectedTodoIndexNames = todoIndexStatements.map(_indexNameOf).toSet();
final _expectedPattingLogIndexNames = pattingLogIndexStatements
    .map(_indexNameOf)
    .toSet();
final _expectedChatTurnIndexNames = chatTurnIndexStatements
    .map(_indexNameOf)
    .toSet();
final _expectedReviewGenerationJobIndexNames =
    reviewGenerationJobIndexStatements.map(_indexNameOf).toSet();

String _indexNameOf(String createIndexStatement) {
  final match = RegExp(
    r'CREATE (?:UNIQUE )?INDEX IF NOT EXISTS ([^\s]+)',
  ).firstMatch(createIndexStatement);
  if (match == null) {
    throw StateError('Invalid index statement: $createIndexStatement');
  }
  return match.group(1)!;
}

Future<Set<String>> _todoIndexNames(AppDatabase db) async {
  final rows = await db.customSelect('''
SELECT name FROM sqlite_master
WHERE type = 'index' AND tbl_name = 'todos'
AND name LIKE 'idx_todos_%'
''').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _pattingLogIndexNames(AppDatabase db) async {
  final rows = await db.customSelect('''
SELECT name FROM sqlite_master
WHERE type = 'index' AND tbl_name = 'patting_logs'
AND name LIKE 'idx_patting_logs_%'
''').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _chatTurnIndexNames(AppDatabase db) async {
  final rows = await db.customSelect('''
SELECT name FROM sqlite_master
WHERE type = 'index' AND tbl_name = 'chat_turns'
AND name LIKE 'idx_chat_turns_%'
''').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _reviewGenerationJobIndexNames(AppDatabase db) async {
  final rows = await db.customSelect('''
SELECT name FROM sqlite_master
WHERE type = 'index' AND tbl_name = 'review_generation_jobs'
AND name LIKE 'idx_review_generation_jobs_%'
''').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _columnNames(AppDatabase db, String tableName) async {
  final rows = await db.customSelect('PRAGMA table_info($tableName)').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

const _createV6TodosTableSql = '''
CREATE TABLE todos (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  list_id INTEGER NULL,
  parent_id INTEGER NULL,
  recurrence_rule TEXT NULL,
  description TEXT NULL,
  category TEXT NOT NULL DEFAULT 'life',
  priority INTEGER NOT NULL DEFAULT 3,
  due_date INTEGER NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  tags TEXT NOT NULL DEFAULT '[]',
  is_starred INTEGER NOT NULL DEFAULT 0 CHECK (is_starred IN (0, 1)),
  started_at INTEGER NULL,
  completed_at INTEGER NULL,
  cancelled_at INTEGER NULL,
  deleted_at INTEGER NULL,
  actual_minutes INTEGER NULL,
  delay_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
''';

const _createV6UserPreferencesTableSql = '''
CREATE TABLE user_preferences (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  theme_mode TEXT NOT NULL DEFAULT 'system',
  language TEXT NOT NULL DEFAULT 'zh',
  notification_enabled INTEGER NOT NULL DEFAULT 1 CHECK (notification_enabled IN (0, 1)),
  ai_provider TEXT NOT NULL DEFAULT 'openai',
  ai_api_key TEXT NULL,
  ai_base_url TEXT NULL,
  ai_model TEXT NULL,
  daily_review_time TEXT NOT NULL DEFAULT '21:00',
  weekly_report_day TEXT NOT NULL DEFAULT 'sunday',
  resume_template_id INTEGER NOT NULL DEFAULT 0,
  todo_categories TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
''';

const _createV6PattingLogsTableSql = '''
CREATE TABLE patting_logs (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  item_id INTEGER NOT NULL,
  date INTEGER NOT NULL,
  duration_minutes INTEGER NOT NULL,
  method TEXT NOT NULL,
  note TEXT NULL,
  photo_paths TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
''';

const _createV8UserPreferencesTableSql = '''
CREATE TABLE user_preferences (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  theme_mode TEXT NOT NULL DEFAULT 'system',
  language TEXT NOT NULL DEFAULT 'zh',
  notification_enabled INTEGER NOT NULL DEFAULT 1 CHECK (notification_enabled IN (0, 1)),
  ai_provider TEXT NOT NULL DEFAULT 'openai',
  ai_api_key TEXT NULL,
  ai_base_url TEXT NULL,
  ai_model TEXT NULL,
  daily_review_time TEXT NOT NULL DEFAULT '21:00',
  weekly_report_day TEXT NOT NULL DEFAULT 'sunday',
  resume_template_id INTEGER NOT NULL DEFAULT 0,
  todo_categories TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
''';

const _createV9UserPreferencesTableSql = '''
CREATE TABLE user_preferences (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  theme_mode TEXT NOT NULL DEFAULT 'system',
  language TEXT NOT NULL DEFAULT 'zh',
  notification_enabled INTEGER NOT NULL DEFAULT 1 CHECK (notification_enabled IN (0, 1)),
  ai_provider TEXT NOT NULL DEFAULT 'openai',
  ai_api_key TEXT NULL,
  ai_base_url TEXT NULL,
  ai_model TEXT NULL,
  ai_config TEXT NULL,
  daily_review_time TEXT NOT NULL DEFAULT '21:00',
  weekly_report_day TEXT NOT NULL DEFAULT 'sunday',
  resume_template_id INTEGER NOT NULL DEFAULT 0,
  todo_categories TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
''';

const _createV10UserPreferencesTableSql = _createV9UserPreferencesTableSql;

const _createV10ChatTurnsTableSql = '''
CREATE TABLE chat_turns (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  turn_date TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  is_offline INTEGER NOT NULL DEFAULT 0 CHECK (is_offline IN (0, 1)),
  consumes_cloud_turn INTEGER NOT NULL DEFAULT 0 CHECK (consumes_cloud_turn IN (0, 1)),
  source TEXT NOT NULL DEFAULT 'daily_review_chat',
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
''';
