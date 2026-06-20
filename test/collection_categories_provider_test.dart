import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/settings/presentation/providers/category_management_providers.dart';

void main() {
  group('CollectionCategoriesNotifier', () {
    test('includes long-string as a default collection category', () {
      final notifier = CollectionCategoriesNotifier();

      expect(notifier.state.map((c) => c.name), contains('长串'));
      final longString = notifier.state.singleWhere((c) => c.name == '长串');
      expect(longString.subtypes, containsAll(['星月', '金刚']));
      expect(longString.metadataFields, containsAll(['颗数', '尺寸(mm)']));
    });

    test('merges missing default categories when restoring legacy json', () {
      final notifier = CollectionCategoriesNotifier();
      final legacyJson = jsonEncode([
        {
          'name': '核桃',
          'subtypes': ['白狮子'],
          'metadataFields': ['边宽(mm)'],
          'sortOrder': 0,
        },
        {
          'name': '手串',
          'subtypes': ['星月'],
          'metadataFields': ['尺寸(mm)'],
          'sortOrder': 1,
        },
        {
          'name': '把件',
          'subtypes': ['葫芦'],
          'metadataFields': ['重量(g)'],
          'sortOrder': 2,
        },
      ]);

      notifier.fromJson(legacyJson);

      expect(notifier.state.map((c) => c.name), contains('长串'));
      expect(notifier.state.singleWhere((c) => c.name == '核桃').subtypes, [
        '白狮子',
      ]);
    });

    test('does not force every default category back into restored json', () {
      final notifier = CollectionCategoriesNotifier();
      final customOnlyJson = jsonEncode([
        {
          'name': '自定义',
          'subtypes': <String>[],
          'metadataFields': <String>[],
          'sortOrder': 0,
        },
      ]);

      notifier.fromJson(customOnlyJson);

      expect(notifier.state.map((c) => c.name), containsAll(['自定义', '长串']));
      expect(notifier.state.map((c) => c.name), isNot(contains('核桃')));
    });
  });
}
