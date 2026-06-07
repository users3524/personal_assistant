/// 设置页面 — 主题/AI配置/通知/备份/关于。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app.dart';
import '../../../../l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ---- 外观 ----
          _sectionHeader(context, '外观'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('跟随系统'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (v) {
                    if (v != null) ref.read(themeModeProvider.notifier).state = v;
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('浅色模式'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (v) {
                    if (v != null) ref.read(themeModeProvider.notifier).state = v;
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('深色模式'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (v) {
                    if (v != null) ref.read(themeModeProvider.notifier).state = v;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---- 语言 ----
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                RadioListTile<Locale>(
                  title: const Text('中文'),
                  value: const Locale('zh', 'CN'),
                  groupValue: locale,
                  onChanged: (v) =>
                      ref.read(localeProvider.notifier).state = v!,
                ),
                RadioListTile<Locale>(
                  title: const Text('English'),
                  value: const Locale('en', 'US'),
                  groupValue: locale,
                  onChanged: (v) =>
                      ref.read(localeProvider.notifier).state = v!,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- AI 配置 ----
          _sectionHeader(context, 'AI 配置'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('API Key'),
                  subtitle: const Text('已配置' ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showApiKeyDialog(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.dns),
                  title: const Text('API 地址'),
                  subtitle: const Text('https://api.openai.com/v1'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.model_training),
                  title: const Text('模型'),
                  subtitle: const Text('gpt-3.5-turbo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- 通知 ----
          _sectionHeader(context, '通知'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('每日复盘提醒'),
                  subtitle: const Text('默认 21:00'),
                  value: true,
                  onChanged: (v) {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('每周周报提醒'),
                  subtitle: const Text('每周日 20:00'),
                  value: true,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- 数据 ----
          _sectionHeader(context, '数据'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('导出备份'),
                  subtitle: const Text('导出全部数据为加密文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('导入备份'),
                  subtitle: const Text('从备份文件恢复数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- 关于 ----
          _sectionHeader(context, '关于'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('版本'),
                  subtitle: Text('v1.0.0'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('开源许可'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          )),
    );
  }

  void _showApiKeyDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Key'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '输入 OpenAI API Key',
            helperText: 'Key 将加密存储在本地',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('保存')),
        ],
      ),
    );
  }
}
