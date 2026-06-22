/// Builds the nightly raw context pack from local hot tables.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'raw_context_clipper.dart';

class RawContextPack {
  const RawContextPack({
    required this.targetDate,
    required this.generatedAt,
    required this.timezoneOffsetMinutes,
    required this.todos,
    required this.chatTurns,
    required this.dailyReviewDraft,
    required this.pattingLogs,
  });

  final String targetDate;
  final DateTime generatedAt;
  final int timezoneOffsetMinutes;
  final List<Map<String, Object?>> todos;
  final List<Map<String, Object?>> chatTurns;
  final Map<String, Object?>? dailyReviewDraft;
  final List<Map<String, Object?>> pattingLogs;

  Map<String, Object?> toJson() {
    return {
      'target_date': targetDate,
      'generated_at': generatedAt.toIso8601String(),
      'timezone_offset_minutes': timezoneOffsetMinutes,
      'todos': todos,
      'chat_turns': chatTurns,
      'daily_review_draft': dailyReviewDraft,
      'patting_logs': pattingLogs,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  List<RawContextItem> toClipperItems() {
    return [
      ...todos.map(
        (todo) => RawContextItem(
          source: RawContextSource.todo,
          content: jsonEncode(todo),
          createdAt:
              _parseDateTime(todo['completed_at']) ??
              _parseDateTime(todo['due_date']) ??
              generatedAt,
          priority: todo['priority'] as int? ?? 3,
          isCompletedTodo: todo['status'] == 'done',
        ),
      ),
      ...chatTurns.map(
        (turn) => RawContextItem(
          source: RawContextSource.chatTurn,
          content: jsonEncode(turn),
          createdAt: _parseDateTime(turn['created_at']) ?? generatedAt,
          isCoachingTurn:
              turn['role'] == 'user' && turn['consumes_cloud_turn'] == true,
          isOfflineNote: turn['is_offline'] == true,
        ),
      ),
      if (dailyReviewDraft != null)
        RawContextItem(
          source: RawContextSource.dailyReviewDraft,
          content: jsonEncode(dailyReviewDraft),
          createdAt:
              _parseDateTime(dailyReviewDraft!['updated_at']) ?? generatedAt,
        ),
      ...pattingLogs.map(
        (log) => RawContextItem(
          source: RawContextSource.pattingLog,
          content: jsonEncode(log),
          createdAt: _parseDateTime(log['date']) ?? generatedAt,
          hasPattingNote: (log['note'] as String?)?.trim().isNotEmpty == true,
        ),
      ),
    ];
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class RawContextPackBuilder {
  const RawContextPackBuilder(this._db, {DateTime Function()? now})
    : _now = now;

  final AppDatabase _db;
  final DateTime Function()? _now;

  Future<RawContextPack> build(DateTime targetDate) async {
    final dayStart = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final targetDateKey = _dateKey(dayStart);
    final generatedAt = _now?.call() ?? DateTime.now();

    return RawContextPack(
      targetDate: targetDateKey,
      generatedAt: generatedAt,
      timezoneOffsetMinutes: generatedAt.timeZoneOffset.inMinutes,
      todos: await _loadTodos(dayStart, dayEnd),
      chatTurns: await _loadChatTurns(targetDateKey),
      dailyReviewDraft: await _loadDailyReviewDraft(dayStart, dayEnd),
      pattingLogs: await _loadPattingLogs(dayStart, dayEnd),
    );
  }

  Future<List<Map<String, Object?>>> _loadTodos(
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    final rows = await (_db.select(
      _db.todos,
    )..where((t) => t.deletedAt.isNull())).get();
    final related = rows.where(
      (todo) => _isTodoRelated(todo, dayStart, dayEnd),
    );
    final ordered = related.toList()
      ..sort((a, b) {
        final doneCompare = _isDone(
          b,
        ).toString().compareTo(_isDone(a).toString());
        if (doneCompare != 0) return doneCompare;
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return _todoSortTime(b).compareTo(_todoSortTime(a));
      });

    return List.unmodifiable(
      ordered.map(
        (todo) => {
          'id': todo.id,
          'title': _redactSensitiveText(todo.title),
          'status': todo.status,
          'priority': todo.priority,
          'due_date': _dateTimeOrNull(todo.dueDate),
          'completed_at': _dateTimeOrNull(todo.completedAt),
          'actual_minutes': todo.actualMinutes,
          'tags': todo.tags.map(_redactSensitiveText).toList(),
        },
      ),
    );
  }

  bool _isTodoRelated(Todo todo, DateTime dayStart, DateTime dayEnd) {
    if (_isInHalfOpenRange(todo.completedAt, dayStart, dayEnd)) {
      return true;
    }
    if (todo.status == 'cancelled') {
      return false;
    }
    if (_isInHalfOpenRange(todo.dueDate, dayStart, dayEnd)) {
      return true;
    }
    if (_isDone(todo) || todo.status == 'cancelled') {
      return false;
    }
    final relevantActiveDate = todo.dueDate ?? todo.startedAt ?? todo.createdAt;
    return relevantActiveDate.isBefore(dayEnd);
  }

  bool _isDone(Todo todo) => todo.status == 'done';

  DateTime _todoSortTime(Todo todo) {
    return todo.completedAt ?? todo.dueDate ?? todo.startedAt ?? todo.updatedAt;
  }

  Future<List<Map<String, Object?>>> _loadChatTurns(
    String targetDateKey,
  ) async {
    final rows =
        await (_db.select(_db.chatTurns)
              ..where((t) => t.turnDate.equals(targetDateKey))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();

    return List.unmodifiable(
      rows.map(
        (turn) => {
          'role': turn.role,
          'content': _redactSensitiveText(turn.content),
          'is_offline': turn.isOffline,
          'consumes_cloud_turn': turn.consumesCloudTurn,
          'source': _redactSensitiveText(turn.source),
          'created_at': turn.createdAt.toIso8601String(),
        },
      ),
    );
  }

  Future<Map<String, Object?>?> _loadDailyReviewDraft(
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    final row =
        await (_db.select(_db.dailyReviews)..where(
              (review) =>
                  review.date.isBiggerOrEqualValue(dayStart) &
                  review.date.isSmallerThanValue(dayEnd),
            ))
            .getSingleOrNull();
    if (row == null) return null;

    return {
      'summary': _redactSensitiveText(row.summary),
      'highlights': _redactSensitiveText(row.highlights),
      'improvements': _redactSensitiveText(row.improvements),
      'energy_level': row.energyLevel,
      'mood_level': row.moodLevel,
      'patting_minutes': row.pattingMinutes,
      'updated_at': row.updatedAt.toIso8601String(),
    };
  }

  Future<List<Map<String, Object?>>> _loadPattingLogs(
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    final rows =
        await (_db.select(_db.pattingLogs)..where(
              (log) =>
                  log.date.isBiggerOrEqualValue(dayStart) &
                  log.date.isSmallerThanValue(dayEnd),
            ))
            .get();
    final ordered = rows.toList()
      ..sort((a, b) {
        final noteCompare = _hasText(
          b.note,
        ).toString().compareTo(_hasText(a.note).toString());
        if (noteCompare != 0) return noteCompare;
        final durationCompare = b.durationMinutes.compareTo(a.durationMinutes);
        if (durationCompare != 0) return durationCompare;
        return b.date.compareTo(a.date);
      });

    return List.unmodifiable(
      ordered.map(
        (log) => {
          'id': log.id,
          'item_id': log.itemId,
          'date': log.date.toIso8601String(),
          'duration_minutes': log.durationMinutes,
          'method': log.method,
          'note': _redactSensitiveText(log.note),
          'photo_count': log.photoPaths.length,
        },
      ),
    );
  }

  bool _isInHalfOpenRange(DateTime? value, DateTime start, DateTime end) {
    if (value == null) return false;
    return !value.isBefore(start) && value.isBefore(end);
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? _dateTimeOrNull(DateTime? value) => value?.toIso8601String();

  bool _hasText(String? value) => value?.trim().isNotEmpty == true;

  String? _redactSensitiveText(String? text) {
    if (text == null) return null;
    return text
        .replaceAll(RegExp(r'sk-[A-Za-z0-9_-]{12,}'), '[redacted_api_key]')
        .replaceAll(
          RegExp(r'data:image/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=\r\n]+'),
          '[redacted_image_base64]',
        )
        .replaceAll(
          RegExp(
            r'(?<![A-Za-z0-9+/])[A-Za-z0-9+/]{80,}={0,2}(?![A-Za-z0-9+/])',
          ),
          '[redacted_base64]',
        )
        .replaceAll(
          RegExp(
            r'\b[A-Z]:\\(?:[^\\/:*?"<>|\r\n]+\\)*'
            r'[^\\/:*?"<>|\r\n]+\.(?:json|zip|db|sqlite|bak)',
            caseSensitive: false,
          ),
          '[redacted_backup_path]',
        )
        .replaceAll(
          RegExp(
            r'/[^\r\n]*(?:backup|备份)[^\r\n]*'
            r'\.(?:json|zip|db|sqlite|bak)',
            caseSensitive: false,
          ),
          '[redacted_backup_path]',
        )
        .replaceAll(
          RegExp(
            r'\b(?:flutter_secure_storage|secure_storage|android_keystore|'
            r'ios_keychain|keychain|keystore)\s*[:=]\s*'
            r'[A-Za-z0-9_.:/\\-]+',
            caseSensitive: false,
          ),
          '[redacted_secure_storage_ref]',
        );
  }
}
