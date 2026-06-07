/// 设置页面 — 主题/AI配置/通知/备份/关于。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_provider.dart';
import '../../../../core/database/backup_service.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/database/user_preferences_dao.dart';
import 'package:dio/dio.dart';
import '../../../../features/collection/presentation/providers/antique_providers.dart'
    show dailyPickConfigProvider;

// AI 供应商预设
const _aiProviders = {
  '离线模式': {
    'baseUrl': '',
    'models': [],
    'defaultModel': '',
  },
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
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  String _selectedProvider = '离线模式';
  bool _showApiKey = false;
  bool _showKeyInDialog = false;

  String _savedApiKey = '';
  String _savedBaseUrl = '';
  String _savedModel = '';
  String _savedProvider = '离线模式';
  bool _notificationEnabled = true;
  bool _weeklyReminder = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _weeklyTime = const TimeOfDay(hour: 20, minute: 0);

  UserPreferencesDao? _prefsDao;

  @override
  void initState() {
    super.initState();
    _baseUrlCtrl.text = _savedBaseUrl;
    _modelCtrl.text = _savedModel;
    _loadSettings();
  }

  bool get _isOffline => _selectedProvider == '离线模式';

  Future<void> _loadSettings() async {
    try {
      final db = await ref.read(appDatabaseProvider.future);
      _prefsDao = UserPreferencesDao(db);
      final prefs = await _prefsDao!.getOrCreate();

      if (!mounted) return;
      setState(() {
        _savedApiKey = prefs.aiApiKey ?? '';
        _savedBaseUrl = prefs.aiBaseUrl ?? 'https://api.openai.com/v1';
        _savedModel = prefs.aiModel ?? 'gpt-4o-mini';
        _savedProvider = prefs.aiProvider;
        _selectedProvider = prefs.aiProvider;
        _notificationEnabled = prefs.notificationEnabled;
        // 加载通知时间
        final dailyTime = prefs.dailyReviewTime;
        if (dailyTime.isNotEmpty && dailyTime.contains(':')) {
          final parts = dailyTime.split(':');
          _notificationTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 21,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
        // 周报时间存在提醒中就用默认的每周日，时间复用 weeklyReportDay 中的时间格式
        _weeklyReminder = prefs.weeklyReportDay == 'sunday';
        _baseUrlCtrl.text = _savedBaseUrl;
        _modelCtrl.text = _savedModel;
      });

      ref.read(aiConfigProvider.notifier).update(
            provider: _savedProvider,
            baseUrl: _savedBaseUrl,
            model: _savedModel,
            apiKey: _savedApiKey,
          );
    } catch (_) {
      // 数据库加载失败，使用默认内存配置
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
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _sectionHeader('AI 配置'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: _isOffline
                // 离线模式：简洁展示
                ? Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cloud),
                        title: const Text('AI 平台'),
                        subtitle: Text(_selectedProvider),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showProviderPicker(),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      const ListTile(
                        leading: Icon(Icons.wifi_off, color: Colors.green),
                        title: Text('离线模式已启用'),
                        subtitle: Text('无需网络，App 内置模板引擎即时生成日报/周报', style: TextStyle(fontSize: 12)),
                        trailing: Icon(Icons.check_circle, color: Colors.green),
                      ),
                    ],
                  )
                // 在线模式：完整配置
                : Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.cloud),
                        title: const Text('AI 平台'),
                        subtitle: Text(_selectedProvider),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showProviderPicker(),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.dns),
                        title: const Text('API 地址'),
                        subtitle: Text(_savedBaseUrl.isEmpty ? '未设置' : _savedBaseUrl),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _showTextEditor(
                          'API 地址', _baseUrlCtrl,
                          (v) { setState(() => _savedBaseUrl = v); _baseUrlCtrl.text = v; },
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.model_training),
                        title: const Text('模型'),
                        subtitle: Text(_savedModel.isEmpty ? '未设置' : _savedModel),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showModelPicker(),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
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
                              icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility, size: 20),
                              onPressed: () => setState(() => _showApiKey = !_showApiKey),
                            ),
                            const Icon(Icons.edit, size: 20),
                          ],
                        ),
                        onTap: () => _showApiKeyEditor(),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.wifi_tethering),
                        title: const Text('检测连接'),
                        subtitle: const Text('测试服务器是否可达'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _testOllamaConnection(),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          _sectionHeader('通知'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('每日复盘提醒'),
                  subtitle: Text('每日 ${_notificationTime.format(context)}'),
                  value: _notificationEnabled,
                  onChanged: (v) {
                    setState(() => _notificationEnabled = v);
                    _prefsDao?.setNotificationEnabled(v);
                  },
                ),
                if (_notificationEnabled)
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('提醒时间'),
                    subtitle: Text(_notificationTime.format(context)),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _pickTime(context, true),
                  ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('每周周报提醒'),
                  subtitle: Text('每周日 ${_weeklyTime.format(context)}'),
                  value: _weeklyReminder,
                  onChanged: (v) => setState(() => _weeklyReminder = v),
                ),
                if (_weeklyReminder)
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('提醒时间'),
                    subtitle: Text(_weeklyTime.format(context)),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _pickTime(context, false),
                  ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('关于通知'),
                  subtitle: Text('提醒需要 App 在后台运行权限，请在系统设置中允许通知', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _sectionHeader('文玩'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer(builder: (context, ref, _) {
              final config = ref.watch(dailyPickConfigProvider);
              return Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.auto_awesome),
                    title: Text('每日翻牌推荐'),
                    subtitle: Text('配置每日推荐的种类和数量'),
                  ),
                  ...config.counts.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(entry.key, style: const TextStyle(fontSize: 14)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () {
                            final notifier = ref.read(dailyPickConfigProvider.notifier);
                            if (entry.value > 1) {
                              notifier.setCount(entry.key, entry.value - 1);
                            }
                          },
                        ),
                        SizedBox(
                          width: 24,
                          child: Text('${entry.value}', textAlign: TextAlign.center),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () {
                            ref.read(dailyPickConfigProvider.notifier).setCount(entry.key, entry.value + 1);
                          },
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),

          _sectionHeader('数据'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('导出备份'),
                  subtitle: const Text('导出全部数据为 JSON 文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportBackup(),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('导入备份'),
                  subtitle: const Text('从 JSON 备份文件恢复数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importBackup(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
      child: Text(title, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      )),
    );
  }

  void _showProviderPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择 AI 平台', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ..._aiProviders.keys.map((provider) => RadioListTile<String>(
                  title: Text(provider),
                  subtitle: provider == '离线模式'
                      ? const Text('App 内置模板引擎，无需网络')
                      : Text(_aiProviders[provider]!['baseUrl']!.toString()),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showModelPicker() {
    final models = _aiProviders[_selectedProvider]?['models'] as List<String>? ?? [];
    if (models.isEmpty) {
      _showTextEditor('模型名称', _modelCtrl, (v) => setState(() => _savedModel = v));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(
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
                    setState(() { _savedModel = v; _modelCtrl.text = v; });
                    _saveAIConfigToDb();
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

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
              Row(children: [
                const Text('平台：', style: TextStyle(fontSize: 13)),
                Text(_selectedProvider, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: '输入 API Key',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_showKeyInDialog ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => _showKeyInDialog = !_showKeyInDialog),
                  ),
                ),
                obscureText: !_showKeyInDialog,
              ),
              const SizedBox(height: 8),
              Text('Key 存储在本地设备上', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () {
                setState(() { _savedApiKey = ctrl.text.trim(); });
                _saveAIConfigToDb();
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextEditor(String title, TextEditingController ctrl, Function(String) onSave) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { onSave(ctrl.text.trim()); _saveAIConfigToDb(); Navigator.pop(ctx); },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ===== 通知时间选择 =====
  Future<void> _pickTime(BuildContext context, bool isDaily) async {
    final initial = isDaily ? _notificationTime : _weeklyTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isDaily) {
          _notificationTime = picked;
          _prefsDao?.setDailyReviewTime('${picked.hour}:${picked.minute.toString().padLeft(2, '0')}');
        } else {
          _weeklyTime = picked;
          _prefsDao?.setWeeklyReminder(true);
        }
      });
    }
  }

  // ===== Ollama 连接检测 =====
  Future<void> _testOllamaConnection() async {
    // 从用户配置的 baseUrl 提取根地址（去掉 /v1 后缀）
    var baseUrl = _savedBaseUrl.isNotEmpty ? _savedBaseUrl : _baseUrlCtrl.text;
    if (baseUrl.endsWith('/v1')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 3);
    }
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('检测连接'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('正在连接 Ollama 服务…'),
          ],
        ),
      ),
    );

    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ));

      // 调用 Ollama 的 /api/tags 获取本地已下载的模型列表
      final response = await dio.get('/api/tags');
      final List<dynamic> models = response.data['models'] ?? [];

      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      // 构建可用模型列表字符串
      final modelNames = models.map((m) {
        final name = m['name'] ?? m['model'] ?? '未知';
        final size = m['size'] != null
            ? ' (${_formatBytes(m['size'] as int)})'
            : '';
        return '  • $name$size';
      }).join('\n');

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('连接成功！'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ollama 服务运行正常。'),
                const SizedBox(height: 12),
                if (models.isNotEmpty) ...[
                  const Text('已安装的模型：', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(modelNames, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                  const SizedBox(height: 12),
                  Text(
                    '当前推荐模型：${_aiProviders["本地模型 (Ollama)"]!["defaultModel"]}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ] else ...[
                  const Text('⚠️ 尚未安装任何模型。'),
                  const SizedBox(height: 8),
                  Text(
                    '请在终端运行：\nollama pull qwen2.5:7b',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭加载对话框

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('连接失败'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('无法连接到 Ollama 服务。'),
              const SizedBox(height: 8),
              Text('错误：${e.toString().replaceFirst(RegExp(r'^.+Exception: '), '')}'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💡 排查方法：', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('1. 确保已安装 Ollama (ollama.com)'),
                    Text('2. 启动 Ollama 桌面应用或运行 ollama serve'),
                    Text('3. 在终端运行 ollama pull qwen2.5:7b 下载模型'),
                    Text('4. 应用会自动连接 http://localhost:11434/v1'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ===== 备份导出 =====
  void _exportBackup() async {
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final backupService = BackupService(db);

      // 让用户选择：存到默认目录 or 自定义位置
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导出备份'),
          content: const Text('选择保存位置：'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'default'),
              child: const Text('默认位置'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'custom'),
              child: const Text('自定义位置'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;

      String? path;
      if (choice == 'custom') {
        // Android 上用 SAF 选择保存位置，iOS 上 saveFile 也兼容
        path = await backupService.exportViaSaf();
      } else {
        path = await backupService.exportBackup();
      }

      if (mounted) {
        if (path != null && path.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导出：$path'), duration: const Duration(seconds: 4)),
          );
        } else {
          // SAF 写入成功但没返回路径（部分 Android 版本）
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已导出'), duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    }
  }

  // ===== 备份导入 =====
  void _importBackup() async {
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final backupService = BackupService(db);
      final filePath = await backupService.pickBackupFile();
      if (filePath == null || !mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入备份'),
          content: const Text('确定要恢复数据吗？\n\n⚠️ 当前所有数据将被覆盖！'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await backupService.importBackup(filePath);
      ref.invalidate(appDatabaseProvider);
      ref.invalidate(aiConfigProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('数据已恢复！')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: '个人全能助手',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 Personal Assistant',
    );
  }
}
