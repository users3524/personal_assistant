import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/todo/data/datasources/todo_dao.dart';
import 'package:personal_assistant/features/todo/data/repositories/todo_repository_impl.dart';
import 'package:personal_assistant/features/todo/domain/entities/todo_entity.dart';

void main() {
  group('TodoDao', () {
    late AppDatabase db;
    late TodoDao dao;

    setUp(() {
      db = AppDatabase.createInMemory();
      dao = TodoDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('hydrates parent tasks with direct non-deleted subtasks', () async {
      final now = DateTime(2026, 6, 20, 9);
      final parent = await dao.insert(_todo('Parent', now));
      final otherParent = await dao.insert(_todo('Other parent', now));
      final childA = await dao.addSubtask(parent.id!, _todo('Child A', now));
      await dao.addSubtask(parent.id!, _todo('Child B', now));
      await dao.addSubtask(otherParent.id!, _todo('Other child', now));
      await dao.softDelete(childA.id!);

      final tree = await dao.getTree();
      final hydratedParent = tree.singleWhere((todo) => todo.id == parent.id);
      final hydratedOther = tree.singleWhere(
        (todo) => todo.id == otherParent.id,
      );

      expect(tree, hasLength(2));
      expect(hydratedParent.subtasks.map((todo) => todo.title), ['Child B']);
      expect(hydratedOther.subtasks.map((todo) => todo.title), ['Other child']);
    });
  });

  group('TodoRepositoryImpl', () {
    late AppDatabase db;
    late TodoDao dao;
    late TodoRepositoryImpl repository;

    setUp(() {
      db = AppDatabase.createInMemory();
      dao = TodoDao(db);
      repository = TodoRepositoryImpl(dao);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'reopens parent and direct subtasks by clearing finish timestamps',
      () async {
        final now = DateTime(2026, 6, 20, 9);
        final parent = await dao.insert(_todo('Parent', now));
        await dao.addSubtask(parent.id!, _todo('Child', now));

        await repository.complete(parent.id!);
        final completed = await dao.getById(parent.id!);
        expect(completed!.completedAt, isNotNull);
        expect(completed.subtasks.single.completedAt, isNotNull);

        final reopened = await repository.reopen(parent.id!);

        expect(reopened.status, TodoStatus.pending);
        expect(reopened.completedAt, null);
        expect(reopened.cancelledAt, null);
        expect(reopened.subtasks.single.status, TodoStatus.pending);
        expect(reopened.subtasks.single.completedAt, null);
        expect(reopened.subtasks.single.cancelledAt, null);
      },
    );

    test(
      'creates recurring next task without inherited completion fields',
      () async {
        final now = DateTime(2026, 6, 20, 9);
        final recurring = await dao.insert(
          _todo(
            'Daily focus',
            now,
            recurrenceRule: 'daily',
            dueDate: DateTime(2026, 6, 20),
            startedAt: DateTime(2026, 6, 20, 8),
            completedAt: DateTime(2026, 6, 20, 8, 30),
            cancelledAt: DateTime(2026, 6, 20, 8, 45),
            actualMinutes: 30,
            status: TodoStatus.inProgress,
          ),
        );

        final next = await repository.complete(recurring.id!);

        expect(next.status, TodoStatus.pending);
        expect(next.completedAt, null);
        expect(next.cancelledAt, null);
        expect(next.actualMinutes, null);
        expect(next.dueDate, DateTime(2026, 6, 21));
        expect(next.startedAt, DateTime(2026, 6, 21));
      },
    );
  });
}

TodoEntity _todo(
  String title,
  DateTime now, {
  TodoStatus status = TodoStatus.pending,
  DateTime? dueDate,
  DateTime? startedAt,
  DateTime? completedAt,
  DateTime? cancelledAt,
  int? actualMinutes,
  String? recurrenceRule,
}) {
  return TodoEntity(
    title: title,
    category: '工作',
    status: status,
    dueDate: dueDate,
    startedAt: startedAt ?? now,
    completedAt: completedAt,
    cancelledAt: cancelledAt,
    actualMinutes: actualMinutes,
    recurrenceRule: recurrenceRule,
    createdAt: now,
    updatedAt: now,
  );
}
