/// 应用国际化 — 手动实现（无需 codegen）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get appName => _t('appName', '寸积', 'Cunji');
  String get todoList => _t('todoList', '待办清单', 'Todo List');
  String get collection => _t('collection', '文玩记录', 'Collection');
  String get review => _t('review', 'AI 复盘', 'AI Review');
  String get resume => _t('resume', '简历', 'Resume');
  String get settings => _t('settings', '设置', 'Settings');
  String get save => _t('save', '保存', 'Save');
  String get cancel => _t('cancel', '取消', 'Cancel');
  String get delete => _t('delete', '删除', 'Delete');
  String get confirm => _t('confirm', '确认', 'Confirm');
  String get search => _t('search', '搜索', 'Search');
  String get loading => _t('loading', '加载中...', 'Loading...');
  String get noData => _t('noData', '暂无数据', 'No Data');
  String get error => _t('error', '加载失败', 'Loading Failed');

  String _t(String key, String zh, String en) {
    if (locale.languageCode == 'en') return en;
    return zh;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
