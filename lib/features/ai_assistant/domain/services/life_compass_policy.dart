import '../../../todo/domain/entities/todo_entity.dart';

class LifeCompassDimensionIds {
  LifeCompassDimensionIds._();

  static const career = 'career';
  static const health = 'health';
  static const learning = 'learning';
  static const relationship = 'relationship';
  static const life = 'life';
}

class LifeCompassDimension {
  final String id;
  final String label;
  final int order;

  const LifeCompassDimension({
    required this.id,
    required this.label,
    required this.order,
  });
}

class LifeCompassEditCooldownDecision {
  final bool canEdit;
  final DateTime? nextEditableAt;
  final Duration remaining;

  const LifeCompassEditCooldownDecision({
    required this.canEdit,
    required this.nextEditableAt,
    required this.remaining,
  });
}

class LifeCompassDimensionSuggestion {
  final String dimensionId;
  final int confidence;
  final bool needsUserReview;
  final List<String> matchedSignals;

  const LifeCompassDimensionSuggestion({
    required this.dimensionId,
    required this.confidence,
    required this.needsUserReview,
    this.matchedSignals = const [],
  });
}

class LifeCompassMigrationCandidate {
  final int todoId;
  final String title;
  final String suggestedDimensionId;
  final int confidence;
  final bool needsUserReview;
  final List<String> matchedSignals;

  const LifeCompassMigrationCandidate({
    required this.todoId,
    required this.title,
    required this.suggestedDimensionId,
    required this.confidence,
    required this.needsUserReview,
    this.matchedSignals = const [],
  });
}

class LifeCompassMigrationPlan {
  final List<LifeCompassMigrationCandidate> candidates;
  final int ignoredSubtaskCount;
  final int ignoredDeletedCount;
  final int ignoredUnsavedCount;

  const LifeCompassMigrationPlan({
    required this.candidates,
    required this.ignoredSubtaskCount,
    required this.ignoredDeletedCount,
    required this.ignoredUnsavedCount,
  });
}

class LifeCompassPolicy {
  static const editCooldown = Duration(days: 30);

  static const fixedDimensions = [
    LifeCompassDimension(
      id: LifeCompassDimensionIds.career,
      label: '事业',
      order: 0,
    ),
    LifeCompassDimension(
      id: LifeCompassDimensionIds.health,
      label: '健康',
      order: 1,
    ),
    LifeCompassDimension(
      id: LifeCompassDimensionIds.learning,
      label: '学习',
      order: 2,
    ),
    LifeCompassDimension(
      id: LifeCompassDimensionIds.relationship,
      label: '关系',
      order: 3,
    ),
    LifeCompassDimension(
      id: LifeCompassDimensionIds.life,
      label: '生活',
      order: 4,
    ),
  ];

  static const _dimensionIds = {
    LifeCompassDimensionIds.career,
    LifeCompassDimensionIds.health,
    LifeCompassDimensionIds.learning,
    LifeCompassDimensionIds.relationship,
    LifeCompassDimensionIds.life,
  };

  const LifeCompassPolicy();

  static bool isFixedDimensionId(String id) {
    return _dimensionIds.contains(id.trim());
  }

  LifeCompassEditCooldownDecision evaluateEditCooldown({
    required DateTime now,
    DateTime? lastEditedAt,
  }) {
    if (lastEditedAt == null) {
      return const LifeCompassEditCooldownDecision(
        canEdit: true,
        nextEditableAt: null,
        remaining: Duration.zero,
      );
    }

    final nextEditableAt = lastEditedAt.add(editCooldown);
    if (!now.isBefore(nextEditableAt)) {
      return LifeCompassEditCooldownDecision(
        canEdit: true,
        nextEditableAt: nextEditableAt,
        remaining: Duration.zero,
      );
    }

    return LifeCompassEditCooldownDecision(
      canEdit: false,
      nextEditableAt: nextEditableAt,
      remaining: nextEditableAt.difference(now),
    );
  }

  LifeCompassMigrationPlan planTodoMigration(List<TodoEntity> todos) {
    var ignoredSubtaskCount = 0;
    var ignoredDeletedCount = 0;
    var ignoredUnsavedCount = 0;
    final candidates = <LifeCompassMigrationCandidate>[];

    for (final todo in todos) {
      if (todo.isDeleted) {
        ignoredDeletedCount++;
        continue;
      }
      if (todo.isSubtask) {
        ignoredSubtaskCount++;
        continue;
      }
      if (todo.id == null) {
        ignoredUnsavedCount++;
        continue;
      }

      final suggestion = suggestDimensionForTodo(todo);
      candidates.add(
        LifeCompassMigrationCandidate(
          todoId: todo.id!,
          title: todo.title.trim(),
          suggestedDimensionId: suggestion.dimensionId,
          confidence: suggestion.confidence,
          needsUserReview: suggestion.needsUserReview,
          matchedSignals: suggestion.matchedSignals,
        ),
      );
    }

    return LifeCompassMigrationPlan(
      candidates: List.unmodifiable(candidates),
      ignoredSubtaskCount: ignoredSubtaskCount,
      ignoredDeletedCount: ignoredDeletedCount,
      ignoredUnsavedCount: ignoredUnsavedCount,
    );
  }

  LifeCompassDimensionSuggestion suggestDimensionForTodo(TodoEntity todo) {
    final category = todo.category.trim();
    final categoryDimension = _dimensionForCategory(category);
    if (categoryDimension != null) {
      return LifeCompassDimensionSuggestion(
        dimensionId: categoryDimension,
        confidence: 90,
        needsUserReview: false,
        matchedSignals: ['category:$category'],
      );
    }

    final text = _searchableText(todo);
    final matched = <String>[];
    final scores = <String, int>{};

    for (final entry in _keywordsByDimension.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          scores.update(entry.key, (score) => score + 1, ifAbsent: () => 1);
          matched.add('${entry.key}:$keyword');
        }
      }
    }

    if (scores.isEmpty) {
      return const LifeCompassDimensionSuggestion(
        dimensionId: LifeCompassDimensionIds.life,
        confidence: 20,
        needsUserReview: true,
      );
    }

    final dimensionId = _bestScoredDimension(scores);
    return LifeCompassDimensionSuggestion(
      dimensionId: dimensionId,
      confidence: scores[dimensionId]! >= 2 ? 75 : 65,
      needsUserReview: scores[dimensionId]! < 2,
      matchedSignals: List.unmodifiable(
        matched.where((signal) => signal.startsWith('$dimensionId:')),
      ),
    );
  }

  String _bestScoredDimension(Map<String, int> scores) {
    return fixedDimensions
        .map((dimension) => dimension.id)
        .where(scores.containsKey)
        .reduce((best, current) {
          final scoreCompare = scores[current]!.compareTo(scores[best]!);
          if (scoreCompare > 0) return current;
          return best;
        });
  }

  String _searchableText(TodoEntity todo) {
    return [
      todo.title,
      todo.description ?? '',
      todo.category,
      ...todo.tags,
    ].join(' ').trim().toLowerCase();
  }

  String? _dimensionForCategory(String category) {
    return switch (category) {
      '工作' || '事业' || '职业' => LifeCompassDimensionIds.career,
      '健康' || '运动' || '身体' => LifeCompassDimensionIds.health,
      '学习' || '成长' || '读书' => LifeCompassDimensionIds.learning,
      '关系' || '家庭' || '朋友' || '亲密关系' => LifeCompassDimensionIds.relationship,
      '生活' => LifeCompassDimensionIds.life,
      _ => null,
    };
  }

  static const _keywordsByDimension = {
    LifeCompassDimensionIds.career: [
      '工作',
      '项目',
      '交付',
      '简历',
      '面试',
      '职业',
      '事业',
      '客户',
      '代码',
      '产品',
      '会议',
    ],
    LifeCompassDimensionIds.health: [
      '健康',
      '运动',
      '锻炼',
      '跑步',
      '睡眠',
      '体检',
      '饮食',
      '冥想',
      '健身',
    ],
    LifeCompassDimensionIds.learning: [
      '学习',
      '读书',
      '课程',
      '考试',
      '英语',
      '论文',
      '研究',
      '复习',
      '训练',
    ],
    LifeCompassDimensionIds.relationship: [
      '关系',
      '家庭',
      '家人',
      '朋友',
      '伴侣',
      '沟通',
      '约会',
      '陪伴',
      '社交',
    ],
    LifeCompassDimensionIds.life: [
      '生活',
      '整理',
      '家务',
      '旅行',
      '财务',
      '预算',
      '房间',
      '证件',
      '购物',
    ],
  };
}
