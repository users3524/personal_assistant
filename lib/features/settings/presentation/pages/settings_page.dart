/// 设置页面 — 主题/AI配置/通知/备份/关于。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app.dart';

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

  // 存储的配置（用内存模拟，实际应持久化到数据库）
  String _savedApiKey = '';
  String _savedBaseUrl = 'https://api.openai.com/v1';
  String _savedModel = 'gpt-4o-mini';
  String _savedProvider = 'OpenAI';

  @override
  void initState() {
    super.initState();
    // 初始化控制器
    _baseUrlCtrl.text = _savedBaseUrl;
    _modelCtrl.text = _savedModel;
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
                  });
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
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
