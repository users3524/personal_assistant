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

    test(
      'saves todo lists in creation order and keeps task list links',
      () async {
        final firstCreatedAt = DateTime(2026, 6, 20, 9);
        final secondCreatedAt = DateTime(2026, 6, 21, 9);

        final later = await dao.saveList(
          TodoListEntity(
            name: 'Later',
            category: '工作',
            createdAt: secondCreatedAt,
          ),
        );
        final earlier = await dao.saveList(
          TodoListEntity(
            name: 'Earlier',
            category: '生活',
            createdAt: firstCreatedAt,
          ),
        );
        await dao.insert(
          _todo(
            'Listed task',
            firstCreatedAt,
            listId: earlier.id,
            category: '生活',
          ),
        );

        final lists = await dao.getLists();
        final tasks = await dao.getTree();

        expect(lists.map((list) => list.name), ['Earlier', 'Later']);
        expect(later.id, isNotNull);
        expect(tasks.single.listId, earlier.id);
        expect(tasks.single.category, '生活');
      },
    );

    test('deleting todo list keeps tasks and clears list id', () async {
      final now = DateTime(2026, 6, 20, 9);
      final list = await dao.saveList(
        TodoListEntity(name: 'Focus', category: '工作', createdAt: now),
      );
      final task = await dao.insert(_todo('Listed task', now, listId: list.id));

      await dao.deleteList(list.id!);

      expect(await dao.getLists(), isEmpty);
      final reloaded = await dao.getById(task.id!);
      expect(reloaded, isNotNull);
      expect(reloaded!.listId, null);
    });

    test(
      'counts today total from parent tasks only with half-open day',
      () async {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayNoon = todayStart.add(const Duration(hours: 12));
        final yesterday = todayStart.subtract(const Duration(days: 1));
        final tomorrowStart = todayStart.add(const Duration(days: 1));

        await dao.insert(
          _todo('Active today', todayNoon, startedAt: todayNoon),
        );
        await dao.insert(
          _todo('Rolled over active', yesterday, startedAt: yesterday),
        );
        await dao.insert(
          _todo(
            'Completed today',
            yesterday,
            status: TodoStatus.done,
            completedAt: todayNoon,
          ),
        );
        await dao.insert(
          _todo(
            'Completed tomorrow boundary',
            todayNoon,
            status: TodoStatus.done,
            completedAt: tomorrowStart,
          ),
        );
        await dao.insert(
          _todo('Future active', tomorrowStart, startedAt: tomorrowStart),
        );
        await dao.insert(
          _todo('Deleted active', todayNoon, deletedAt: todayNoon),
        );
        await dao.insert(
          _todo('Cancelled today', todayNoon, status: TodoStatus.cancelled),
        );

        final parent = await dao.insert(_todo('Parent', todayNoon));
        await dao.addSubtask(
          parent.id!,
          _todo('Child active today', todayNoon, startedAt: todayNoon),
        );
        await dao.addSubtask(
          parent.id!,
          _todo(
            'Child completed today',
            todayNoon,
            status: TodoStatus.done,
            completedAt: todayNoon,
          ),
        );

        expect(await dao.countTodayCompleted(), 1);
        expect(await dao.countTodayTotal(), 4);
      },
    );

    test(
      'calculates weekly completion rate from current week parent tasks',
      () async {
        final now = DateTime.now();
        final weekStartRaw = now.subtract(Duration(days: now.weekday - 1));
        final weekStart = DateTime(
          weekStartRaw.year,
          weekStartRaw.month,
          weekStartRaw.day,
        );
        final weekMid = weekStart.add(const Duration(days: 2));
        final weekEnd = weekStart.add(const Duration(days: 7));
        final previousWeek = weekStart.subtract(const Duration(days: 1));

        await dao.insert(
          _todo('Done this week', weekMid, status: TodoStatus.done),
        );
        await dao.insert(_todo('Pending this week', weekMid));
        await dao.insert(
          _todo('Done previous week', previousWeek, status: TodoStatus.done),
        );
        await dao.insert(
          _todo('Done next week boundary', weekEnd, status: TodoStatus.done),
        );
        await dao.insert(
          _todo(
            'Deleted done this week',
            weekMid,
            status: TodoStatus.done,
            deletedAt: weekMid,
          ),
        );

        final parent = await dao.insert(_todo('Parent', weekMid));
        await dao.addSubtask(
          parent.id!,
          _todo('Child done this week', weekMid, status: TodoStatus.done),
        );

        expect(await dao.weeklyCompletionRate(), 1 / 3);
      },
    );

    test('calculates delay rate from completed parent tasks only', () async {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterday = todayStart.subtract(const Duration(days: 1));
      final todayNoon = todayStart.add(const Duration(hours: 12));

      await dao.insert(
        _todo(
          'Delayed done',
          yesterday,
          status: TodoStatus.done,
          dueDate: yesterday,
          completedAt: todayNoon,
        ),
      );
      await dao.insert(
        _todo(
          'On time done',
          todayStart,
          status: TodoStatus.done,
          dueDate: todayNoon,
          completedAt: todayNoon,
        ),
      );
      await dao.insert(
        _todo('Done without due date', todayStart, status: TodoStatus.done),
      );
      await dao.insert(
        _todo(
          'Deleted delayed done',
          yesterday,
          status: TodoStatus.done,
          dueDate: yesterday,
          completedAt: todayNoon,
          deletedAt: todayNoon,
        ),
      );
      await dao.insert(
        _todo(
          'Pending overdue',
          yesterday,
          dueDate: yesterday,
          completedAt: todayNoon,
        ),
      );

      final parent = await dao.insert(_todo('Parent', todayStart));
      await dao.addSubtask(
        parent.id!,
        _todo(
          'Delayed child done',
          yesterday,
          status: TodoStatus.done,
          dueDate: yesterday,
          completedAt: todayNoon,
        ),
      );

      expect(await dao.delayRate(), 1 / 3);
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
  DateTime? deletedAt,
  int? actualMinutes,
  String? recurrenceRule,
  int? listId,
  String category = '工作',
}) {
  return TodoEntity(
    title: title,
    category: category,
    status: status,
    dueDate: dueDate,
    startedAt: startedAt ?? now,
    completedAt: completedAt,
    cancelledAt: cancelledAt,
    deletedAt: deletedAt,
    actualMinutes: actualMinutes,
    recurrenceRule: recurrenceRule,
    listId: listId,
    createdAt: now,
    updatedAt: now,
  );
}
