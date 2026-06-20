import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/todo/data/datasources/todos_table.dart';
import 'package:drift/native.dart';

void main() {
  group('AppDatabase migrations', () {
    test('new schema contains todo indexes', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(db.close);

      expect(await _todoIndexNames(db), _expectedTodoIndexNames);
    });

    test('upgrades v6 databases with todo indexes', () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute(_createV6TodosTableSql);
            rawDb.execute('PRAGMA user_version = 6');
          },
        ),
      );
      addTearDown(db.close);

      expect(await _todoIndexNames(db), _expectedTodoIndexNames);
    });
  });
}

final _expectedTodoIndexNames = todoIndexStatements.map(_indexNameOf).toSet();

String _indexNameOf(String createIndexStatement) {
  final match = RegExp(
    r'CREATE INDEX IF NOT EXISTS ([^\s]+)',
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
