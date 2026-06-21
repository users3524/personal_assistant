import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/life_compass_policy.dart';
import 'package:personal_assistant/features/todo/domain/entities/todo_entity.dart';

void main() {
  group('LifeCompassPolicy', () {
    const policy = LifeCompassPolicy();

    test('defines five fixed dimensions with stable ids and order', () {
      expect(
        LifeCompassPolicy.fixedDimensions.map((dimension) => dimension.id),
        [
          LifeCompassDimensionIds.career,
          LifeCompassDimensionIds.health,
          LifeCompassDimensionIds.learning,
          LifeCompassDimensionIds.relationship,
          LifeCompassDimensionIds.life,
        ],
      );
      expect(
        LifeCompassPolicy.fixedDimensions.map((dimension) => dimension.label),
        ['事业', '健康', '学习', '关系', '生活'],
      );
      expect(
        LifeCompassPolicy.fixedDimensions.map((dimension) => dimension.order),
        [0, 1, 2, 3, 4],
      );
      expect(LifeCompassPolicy.isFixedDimensionId('career'), true);
      expect(LifeCompassPolicy.isFixedDimensionId(' career '), true);
      expect(LifeCompassPolicy.isFixedDimensionId('finance'), false);
    });

    test('allows first edit when there is no previous edit time', () {
      final decision = policy.evaluateEditCooldown(now: DateTime(2026, 6, 21));

      expect(decision.canEdit, true);
      expect(decision.nextEditableAt, isNull);
      expect(decision.remaining, Duration.zero);
    });

    test('blocks edits before the 30 day cooldown expires', () {
      final decision = policy.evaluateEditCooldown(
        now: DateTime(2026, 6, 21, 9),
        lastEditedAt: DateTime(2026, 6, 1, 9),
      );

      expect(decision.canEdit, false);
      expect(decision.nextEditableAt, DateTime(2026, 7, 1, 9));
      expect(decision.remaining, const Duration(days: 10));
    });

    test('allows edits once the 30 day cooldown is reached', () {
      final decision = policy.evaluateEditCooldown(
        now: DateTime(2026, 7, 1, 9),
        lastEditedAt: DateTime(2026, 6, 1, 9),
      );

      expect(decision.canEdit, true);
      expect(decision.nextEditableAt, DateTime(2026, 7, 1, 9));
      expect(decision.remaining, Duration.zero);
    });

    test(
      'plans migration only for persisted root todos that are not deleted',
      () {
        final plan = policy.planTodoMigration([
          _todo(id: 1, title: '  项目交付  ', category: '工作'),
          _todo(id: 2, title: '子任务不单独迁移', parentId: 1, category: '工作'),
          _todo(
            id: 3,
            title: '软删除任务不迁移',
            category: '健康',
            deletedAt: DateTime(2026, 6, 20),
          ),
          _todo(title: '未落库任务不迁移', category: '学习'),
        ]);

        expect(plan.candidates, hasLength(1));
        expect(plan.candidates.single.todoId, 1);
        expect(plan.candidates.single.title, '项目交付');
        expect(
          plan.candidates.single.suggestedDimensionId,
          LifeCompassDimensionIds.career,
        );
        expect(plan.ignoredSubtaskCount, 1);
        expect(plan.ignoredDeletedCount, 1);
        expect(plan.ignoredUnsavedCount, 1);
      },
    );

    test('uses category as the strongest dimension signal', () {
      final suggestion = policy.suggestDimensionForTodo(
        _todo(id: 1, title: '跑步和睡眠计划', category: '工作', tags: const ['健康']),
      );

      expect(suggestion.dimensionId, LifeCompassDimensionIds.career);
      expect(suggestion.confidence, 90);
      expect(suggestion.needsUserReview, false);
      expect(suggestion.matchedSignals, ['category:工作']);
    });

    test(
      'falls back to title and tag keyword signals for custom categories',
      () {
        final suggestion = policy.suggestDimensionForTodo(
          _todo(id: 1, title: '跑步和睡眠复盘', category: '自定义', tags: const ['健身']),
        );

        expect(suggestion.dimensionId, LifeCompassDimensionIds.health);
        expect(suggestion.confidence, 75);
        expect(suggestion.needsUserReview, false);
        expect(suggestion.matchedSignals, contains('health:跑步'));
        expect(suggestion.matchedSignals, contains('health:睡眠'));
        expect(suggestion.matchedSignals, contains('health:健身'));
      },
    );

    test('marks weak keyword matches for user review', () {
      final suggestion = policy.suggestDimensionForTodo(
        _todo(id: 1, title: '准备面试', category: '自定义'),
      );

      expect(suggestion.dimensionId, LifeCompassDimensionIds.career);
      expect(suggestion.confidence, 65);
      expect(suggestion.needsUserReview, true);
    });

    test('defaults unknown tasks to life and requires user review', () {
      final suggestion = policy.suggestDimensionForTodo(
        _todo(id: 1, title: '想一想下一步', category: '自定义'),
      );

      expect(suggestion.dimensionId, LifeCompassDimensionIds.life);
      expect(suggestion.confidence, 20);
      expect(suggestion.needsUserReview, true);
      expect(suggestion.matchedSignals, isEmpty);
    });
  });
}

TodoEntity _todo({
  int? id,
  required String title,
  String category = '生活',
  List<String> tags = const [],
  int? parentId,
  DateTime? deletedAt,
}) {
  final now = DateTime(2026, 6, 21, 9);
  return TodoEntity(
    id: id,
    title: title,
    category: category,
    tags: tags,
    parentId: parentId,
    deletedAt: deletedAt,
    createdAt: now,
    updatedAt: now,
  );
}
