/// 设置页面 — 主题/AI配置/通知/备份/关于。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app.dart';
import '../../../../core/ai/ai_provider.dart';
import '../../../../core/database/backup_service.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/database/user_preferences_dao.dart';

// AI 供应商预设
const _aiProviders = {
  'OpenAI': {
    'baseUrl': 'https://api.openai.com/v1',
    'models': ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
    'defaultModel': 'gpt-4o-mini',
  },
  'DeepSeek': {
    'baseUrl': 'https://api.deepseek.com',
    'models': ['deepseek-chat', 'deepseek-reasoner'],
    'defaultModel': 'deepseek-chat',
  },
  '通义千问': {
    'baseUrl': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    'models': ['qwen-max', 'qwen-plus', 'qwen-turbo'],
    'defaultModel': 'qwen-plus',
  },
  '硅基流动': {
    'baseUrl': 'https://api.siliconflow.cn/v1',
    'models': ['Qwen/Qwen2.5-7B-Instruct', 'deepseek-ai/DeepSeek-V3'],
    'defaultModel': 'Qwen/Qwen2.5-7B-Instruct',
  },
  '自定义': {
    'baseUrl': '',
    'models': [],
    'defaultModel': '',
  },
};

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // AI 配置控制器
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  String _selectedProvider = 'OpenAI';
  bool _showApiKey = false;
  bool _showKeyInDialog = false;

  // 从数据库加载的配置
  String _savedApiKey = '';
  String _savedBaseUrl = 'https://api.openai.com/v1';
  String _savedModel = 'gpt-4o-mini';
  String _savedProvider = 'OpenAI';
  bool _isLoaded = false; // 标记是否已从数据库加载
  bool _notificationEnabled = true;
  bool _weeklyReminder = true;

  UserPreferencesDao? _prefsDao;

  @override
  void initState() {
    super.initState();
    _baseUrlCtrl.text = _savedBaseUrl;
    _modelCtrl.text = _savedModel;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final db = await ref.read(appDatabaseProvider.future);
      _prefsDao = UserPreferencesDao(db);
      final prefs = await _prefsDao!.getOrCreate();

      if (mounted) {
        setState(() {
          _savedApiKey = prefs.aiApiKey ?? '';
          _savedBaseUrl = prefs.aiBaseUrl ?? 'https://api.openai.com/v1';
          _savedModel = prefs.aiModel ?? 'gpt-4o-mini';
          _savedProvider = prefs.aiProvider;
          _selectedProvider = prefs.aiProvider;
          _notificationEnabled = prefs.notificationEnabled;
          _baseUrlCtrl.text = _savedBaseUrl;
          _modelCtrl.text = _savedModel;
          _isLoaded = true;
        });

        // 同步到 AI 配置 Provider
        ref.read(aiConfigProvider.notifier).update(
          provider: _savedProvider,
          baseUrl: _savedBaseUrl,
          model: _savedModel,
          apiKey: _savedApiKey,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoaded = true);
      }
    }
  }

  Future<void> _saveAIConfigToDb() async {
    if (_prefsDao == null) return;
    try {
      await _prefsDao!.setAIConfig(
        provider: _savedProvider,
        baseUrl: _savedBaseUrl,
        model: _savedModel,
        apiKey: _savedApiKey,
      );
      ref.read(aiConfigProvider.notifier).update(
        provider: _savedProvider,
        baseUrl: _savedBaseUrl,
        model: _savedModel,
        apiKey: _savedApiKey,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ---- 外观 ----
          _sectionHeader('外观'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('跟随系统'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(themeModeProvider.notifier).state = v;
                      _prefsDao?.setThemeMode('system');
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('浅色模式'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(themeModeProvider.notifier).state = v;
                      _prefsDao?.setThemeMode('light');
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('深色模式'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(themeModeProvider.notifier).state = v;
                      _prefsDao?.setThemeMode('dark');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---- AI 配置 ----
          _sectionHeader('AI 配置'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // 供应商选择
                ListTile(
                  leading: const Icon(Icons.cloud),
                  title: const Text('AI 平台'),
                  subtitle: Text(_selectedProvider),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showProviderPicker(),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),

                // API 地址
                ListTile(
                  leading: const Icon(Icons.dns),
                  title: const Text('API 地址'),
                  subtitle: Text(_savedBaseUrl.isEmpty ? '未设置' : _savedBaseUrl),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showTextEditor(
                    'API 地址',
                    _baseUrlCtrl,
                    (v) {
                      setState(() => _savedBaseUrl = v);
                      _baseUrlCtrl.text = v;
                    },
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),

                // 模型
                ListTile(
                  leading: const Icon(Icons.model_training),
                  title: const Text('模型'),
                  subtitle: Text(_savedModel.isEmpty ? '未设置' : _savedModel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showModelPicker(),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),

                // API Key（支持明文/密文切换）
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('API Key'),
                  subtitle: Text(
                    _savedApiKey.isEmpty
                        ? '未配置'
                        : _showApiKey
                            ? _savedApiKey
                        : _savedApiKey.length > 12
                            ? '${_savedApiKey.substring(0, 8)}****${_savedApiKey.substring(_savedApiKey.length - 4)}'
                            : _savedApiKey.replaceRange(1, _savedApiKey.length - 1, '****'),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _showApiKey ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _showApiKey = !_showApiKey),
                      ),
                      const Icon(Icons.edit, size: 20),
                    ],
                  ),
                  onTap: () => _showApiKeyEditor(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- 通知 ----
          _sectionHeader('通知'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('每日复盘提醒'),
                  subtitle: const Text('默认 21:00'),
                  value: _notificationEnabled,
                  onChanged: (v) {
                    setState(() => _notificationEnabled = v);
                    _prefsDao?.setNotificationEnabled(v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v ? '每日复盘提醒已开启' : '每日复盘提醒已关闭')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('每周周报提醒'),
                  subtitle: const Text('每周日 20:00'),
                  value: _weeklyReminder,
                  onChanged: (v) {
                    setState(() => _weeklyReminder = v);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v ? '周报提醒已开启' : '周报提醒已关闭')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- 数据 ----
          _sectionHeader('数据'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('导出备份'),
                  subtitle: const Text('导出全部数据为加密文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportBackup(),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('导入备份'),
                  subtitle: const Text('从备份文件恢复数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importBackup(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- 关于 ----
          _sectionHeader('关于'),
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
                  onTap: () => _showLicenses(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
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

  // ===== AI 供应商选择 =====
  void _showProviderPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('选择 AI 平台', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ..._aiProviders.keys.map((provider) => RadioListTile<String>(
                title: Text(provider),
                subtitle: Text(_aiProviders[provider]!['baseUrl']!.toString()),
                value: provider,
                groupValue: _selectedProvider,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedProvider = v;
                    final info = _aiProviders[v]!;
                    _savedBaseUrl = info['baseUrl']!.toString();
                    _baseUrlCtrl.text = _savedBaseUrl;
                    if (info['defaultModel']!.toString().isNotEmpty) {
                      _savedModel = info['defaultModel']!.toString();
                      _modelCtrl.text = _savedModel;
                    }
                    _savedProvider = v;
                  });
                  _saveAIConfigToDb();
                  Navigator.pop(ctx);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ===== 模型选择 =====
  void _showModelPicker() {
    final models = _aiProviders[_selectedProvider]?['models'] as List<String>? ?? [];
    if (models.isEmpty) {
      // 自定义模型，直接编辑
      _showTextEditor('模型名称', _modelCtrl, (v) {
        setState(() => _savedModel = v);
      });
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('选择模型', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...models.map((model) => RadioListTile<String>(
                title: Text(model),
                value: model,
                groupValue: _savedModel,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _savedModel = v;
                    _modelCtrl.text = v;
                  });
                  _saveAIConfigToDb();
                  Navigator.pop(ctx);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ===== API Key 编辑器（支持明文/密文切换） =====
  void _showApiKeyEditor() {
    final ctrl = TextEditingController(text: _savedApiKey);
    setState(() => _showKeyInDialog = false);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('平台：', style: TextStyle(fontSize: 13)),
                  Text(_selectedProvider, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: '输入 API Key',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showKeyInDialog ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setDialogState(() => _showKeyInDialog = !_showKeyInDialog),
                  ),
                ),
                obscureText: !_showKeyInDialog,
                maxLines: 1,
              ),
              const SizedBox(height: 8),
              Text(
                'Key 将加密存储在本地设备上',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _savedApiKey = ctrl.text.trim();
                  _apiKeyCtrl.text = _savedApiKey;
                });
                _saveAIConfigToDb();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key 已保存')),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 通用文本编辑器 =====
  void _showTextEditor(String title, TextEditingController ctrl, Function(String) onSave) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onSave(ctrl.text.trim());
              _saveAIConfigToDb();
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ===== 备份导出 =====
  void _exportBackup() async {
    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出备份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入加密密码（请牢记，恢复时需要）：'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '加密密码',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('导出'),
          ),
        ],
      ),
    );

    if (confirmed == true && passwordCtrl.text.isNotEmpty && mounted) {
      try {
        final db = await ref.read(appDatabaseProvider.future);
        final backupService = BackupService(db);
        final path = await backupService.exportBackup(passwordCtrl.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('备份已导出到：$path')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导出失败: $e')),
          );
        }
      }
    }
  }

  // ===== 备份导入 =====
  void _importBackup() async {
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final backupService = BackupService(db);
      final filePath = await backupService.pickBackupFile();

      if (filePath == null || !mounted) return;

      final passwordCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入备份'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请输入备份密码以解密数据：'),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '备份密码',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '⚠️ 导入将覆盖当前所有数据！',
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );

      if (confirmed == true && passwordCtrl.text.isNotEmpty && mounted) {
        await backupService.importBackup(filePath, passwordCtrl.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据已恢复，请重新打开应用')),
          );
          // 刷新所有 Provider
          ref.invalidate(appDatabaseProvider);
          ref.invalidate(aiConfigProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  // ===== 开源许可 =====
  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: '个人全能助手',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 Personal Assistant',
    );
  }
}
