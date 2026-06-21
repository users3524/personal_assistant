import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/chat_turns_table.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/milestone_relations_table.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/milestones_table.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/project_milestone_relations_table.dart';
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
      expect(await _milestoneIndexNames(db), _expectedMilestoneIndexNames);
      expect(
        await _milestoneRelationIndexNames(db),
        _expectedMilestoneRelationIndexNames,
      );
      expect(
        await _projectMilestoneRelationIndexNames(db),
        _expectedProjectMilestoneRelationIndexNames,
      );
    });

    test('upgrades v6 databases with query indexes', () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute(_createV6UserPreferencesTableSql);
            rawDb.execute(_createV6TodosTableSql);
            rawDb.execute(_createV6PattingLogsTableSql);
            rawDb.execute(_createV11DailyReviewsTableSql);
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
            rawDb.execute(_createV11DailyReviewsTableSql);
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
            rawDb.execute(_createV11DailyReviewsTableSql);
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
            rawDb.execute(_createV11DailyReviewsTableSql);
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

    test('upgrades v11 daily reviews with calibration flag only', () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute(_createV11DailyReviewsTableSql);
            rawDb.execute('''
INSERT INTO daily_reviews (
  id, date, summary, energy_level, mood_level, completed_todo_ids,
  patting_minutes, is_ai_generated, is_manually_edited, created_at, updated_at
) VALUES (
  1, strftime('%s', '2026-06-20'), 'Needs review', 3, 4, '[]',
  0, 1, 0, strftime('%s', '2026-06-20'), strftime('%s', '2026-06-20')
);
''');
            rawDb.execute('PRAGMA user_version = 11');
          },
        ),
      );
      addTearDown(db.close);

      final tableInfo = await _tableInfo(db, 'daily_reviews');
      final daily = await db.select(db.dailyReviews).getSingle();

      expect(tableInfo['date'], 'INTEGER');
      expect(tableInfo['summary'], 'TEXT');
      expect(tableInfo['calibration_required'], 'INTEGER');
      expect(daily.summary, 'Needs review');
      expect(daily.calibrationRequired, false);
    });

    test(
      'upgrades v12 databases with milestones and source relations',
      () async {
        final db = AppDatabase(
          NativeDatabase.memory(
            setup: (rawDb) {
              rawDb.execute(_createV12DailyReviewsTableSql);
              rawDb.execute('PRAGMA user_version = 12');
            },
          ),
        );
        addTearDown(db.close);

        final milestoneColumns = await _columnNames(db, 'milestones');
        final relationColumns = await _columnNames(db, 'milestone_relations');

        expect(
          milestoneColumns,
          containsAll([
            'title',
            'description',
            'occurred_at',
            'importance_score',
            'is_ai_generated',
            'is_confirmed_by_user',
            'created_at',
            'updated_at',
          ]),
        );
        expect(
          relationColumns,
          containsAll([
            'milestone_id',
            'source_type',
            'source_id',
            'note',
            'created_at',
          ]),
        );
        expect(await _milestoneIndexNames(db), _expectedMilestoneIndexNames);
        expect(
          await _milestoneRelationIndexNames(db),
          _expectedMilestoneRelationIndexNames,
        );

        await db.customStatement('''
INSERT INTO milestones (
  title, occurred_at, importance_score, is_ai_generated,
  is_confirmed_by_user, created_at, updated_at
) VALUES (
  'Delivered schema', strftime('%s', '2026-06-20'), 4, 1, 0,
  strftime('%s', '2026-06-21'), strftime('%s', '2026-06-21')
)
''');
        await db.customStatement('''
INSERT INTO milestone_relations (
  milestone_id, source_type, source_id, note, created_at
) VALUES (
  1, 'daily_review', 1, 'from review', strftime('%s', '2026-06-21')
)
''');

        final milestone = await db.select(db.milestones).getSingle();
        final relation = await db.select(db.milestoneRelations).getSingle();
        expect(milestone.title, 'Delivered schema');
        expect(milestone.isAiGenerated, true);
        expect(milestone.isConfirmedByUser, false);
        expect(relation.sourceType, 'daily_review');
        expect(relation.sourceId, 1);
      },
    );

    test('upgrades v13 databases with project milestone relations', () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute(_createV12DailyReviewsTableSql);
            rawDb.execute(_createV13MilestonesTableSql);
            rawDb.execute(_createV13MilestoneRelationsTableSql);
            rawDb.execute(_createProjectExperiencesTableSql);
            rawDb.execute('PRAGMA user_version = 13');
          },
        ),
      );
      addTearDown(db.close);

      final columns = await _columnNames(db, 'project_milestone_relations');

      expect(
        columns,
        containsAll(['project_id', 'milestone_id', 'sort_order', 'created_at']),
      );
      expect(
        await _projectMilestoneRelationIndexNames(db),
        _expectedProjectMilestoneRelationIndexNames,
      );

      await db.customStatement('''
INSERT INTO project_experiences (
  id, name, tech_stack, key_deliverables, badges, start_date,
  is_visible, sort_order
) VALUES (
  1, 'Personal AI Assistant', '[]', '[]', '[]',
  strftime('%s', '2026-01-01'), 1, 0
)
''');
      await db.customStatement('''
INSERT INTO milestones (
  id, title, occurred_at, created_at, updated_at
) VALUES (
  1, 'Delivered high impact feature', strftime('%s', '2026-06-20'),
  strftime('%s', '2026-06-21'), strftime('%s', '2026-06-21')
)
''');
      await db.customStatement('''
INSERT INTO project_milestone_relations (
  project_id, milestone_id, sort_order, created_at
) VALUES (
  1, 1, 2, strftime('%s', '2026-06-21')
)
''');

      final relation = await db
          .select(db.projectMilestoneRelations)
          .getSingle();
      expect(relation.projectId, 1);
      expect(relation.milestoneId, 1);
      expect(relation.sortOrder, 2);
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
final _expectedMilestoneIndexNames = milestoneIndexStatements
    .map(_indexNameOf)
    .toSet();
final _expectedMilestoneRelationIndexNames = milestoneRelationIndexStatements
    .map(_indexNameOf)
    .toSet();
final _expectedProjectMilestoneRelationIndexNames =
    projectMilestoneRelationIndexStatements.map(_indexNameOf).toSet();

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

Future<Set<String>> _milestoneIndexNames(AppDatabase db) async {
  final rows = await db.customSelect('''
SELECT name FROM sqlite_master
WHERE type = 'index' AND tbl_name = 'milestones'
AND name LIKE 'idx_milestones_%'
''').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _milestoneRelationIndexNames(AppDatabase db) async {
  final rows = await db.customSelect('''
SELECT name FROM sqlite_master
WHERE type = 'index' AND tbl_name = 'milestone_relations'
AND name LIKE 'idx_milestone_relations_%'
''').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _projectMilestoneRelationIndexNames(AppDatabase db) async {
  final rows = await db.customSelect('''
SELECT name FROM sqlite_master
WHERE type = 'index' AND tbl_name = 'project_milestone_relations'
AND name LIKE 'idx_project_milestone_relations_%'
''').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _columnNames(AppDatabase db, String tableName) async {
  final rows = await db.customSelect('PRAGMA table_info($tableName)').get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Map<String, String>> _tableInfo(AppDatabase db, String tableName) async {
  final rows = await db.customSelect('PRAGMA table_info($tableName)').get();
  return {
    for (final row in rows) row.read<String>('name'): row.read<String>('type'),
  };
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

const _createV11DailyReviewsTableSql = '''
CREATE TABLE daily_reviews (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  date INTEGER NOT NULL,
  summary TEXT NOT NULL,
  highlights TEXT NULL,
  improvements TEXT NULL,
  energy_level INTEGER NOT NULL,
  mood_level INTEGER NOT NULL,
  completed_todo_ids TEXT NOT NULL DEFAULT '[]',
  patting_minutes INTEGER NOT NULL DEFAULT 0,
  ai_comment TEXT NULL,
  ai_suggestion TEXT NULL,
  is_ai_generated INTEGER NOT NULL DEFAULT 0 CHECK (is_ai_generated IN (0, 1)),
  is_manually_edited INTEGER NOT NULL DEFAULT 0 CHECK (is_manually_edited IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  UNIQUE(date)
);
''';

const _createV12DailyReviewsTableSql = '''
CREATE TABLE daily_reviews (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  date INTEGER NOT NULL,
  summary TEXT NOT NULL,
  highlights TEXT NULL,
  improvements TEXT NULL,
  energy_level INTEGER NOT NULL,
  mood_level INTEGER NOT NULL,
  completed_todo_ids TEXT NOT NULL DEFAULT '[]',
  patting_minutes INTEGER NOT NULL DEFAULT 0,
  ai_comment TEXT NULL,
  ai_suggestion TEXT NULL,
  is_ai_generated INTEGER NOT NULL DEFAULT 0 CHECK (is_ai_generated IN (0, 1)),
  is_manually_edited INTEGER NOT NULL DEFAULT 0 CHECK (is_manually_edited IN (0, 1)),
  calibration_required INTEGER NOT NULL DEFAULT 0 CHECK (calibration_required IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  UNIQUE(date)
);
''';

const _createV13MilestonesTableSql = '''
CREATE TABLE milestones (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT NULL,
  occurred_at INTEGER NOT NULL,
  importance_score INTEGER NOT NULL DEFAULT 0,
  is_ai_generated INTEGER NOT NULL DEFAULT 0 CHECK (is_ai_generated IN (0, 1)),
  is_confirmed_by_user INTEGER NOT NULL DEFAULT 0 CHECK (is_confirmed_by_user IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
''';

const _createV13MilestoneRelationsTableSql = '''
CREATE TABLE milestone_relations (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  milestone_id INTEGER NOT NULL REFERENCES milestones(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL,
  source_id INTEGER NULL,
  note TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  CHECK (source_type IN ('todo', 'daily_review', 'patting_log', 'manual')),
  CHECK ((source_type = 'manual' AND source_id IS NULL) OR (source_type <> 'manual' AND source_id IS NOT NULL))
);
''';

const _createProjectExperiencesTableSql = '''
CREATE TABLE project_experiences (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  role TEXT NULL,
  description TEXT NULL,
  tech_stack TEXT NOT NULL DEFAULT '[]',
  key_deliverables TEXT NOT NULL DEFAULT '[]',
  badges TEXT NOT NULL DEFAULT '[]',
  link TEXT NULL,
  start_date INTEGER NOT NULL,
  end_date INTEGER NULL,
  is_visible INTEGER NOT NULL DEFAULT 1 CHECK (is_visible IN (0, 1)),
  sort_order INTEGER NOT NULL DEFAULT 0
);
''';
