// DartPad 兼容版 — 个人全能助手 UI 原型
// 零外部依赖，仅使用 flutter/material.dart
// 复制全部代码到 https://dartpad.dev 即可预览

import 'package:flutter/material.dart';

void main() {
  runApp(const PersonalAssistantApp());
}

// ============================================================
// 1. 主题
// ============================================================

class AppTheme {
  static const Color primary = Color(0xFF6750A4);
  static const Color lifeColor = Colors.green;
  static const Color workColor = Colors.blue;

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: primary,
        brightness: Brightness.light,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: primary,
        brightness: Brightness.dark,
      );
}

// ============================================================
// 2. 入口
// ============================================================

class PersonalAssistantApp extends StatefulWidget {
  const PersonalAssistantApp({super.key});

  @override
  State<PersonalAssistantApp> createState() => _PersonalAssistantAppState();
}

class _PersonalAssistantAppState extends State<PersonalAssistantApp> {
  bool _isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '个人全能助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: MainShell(
        onToggleTheme: () => setState(() => _isDark = !_isDark),
        isDark: _isDark,
      ),
    );
  }
}

// ============================================================
// 3. 主壳 — 底部导航
// ============================================================

class MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const MainShell({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = <Widget>[
    const TodoListPage(),
    const CollectionListPage(),
    const ReviewHomePage(),
    const ResumeHomePage(),
    const SettingsPage(),
  ];

  final _titles = ['待办', '文玩', '复盘', '简历', '设置'];

  final _icons = [
    Icons.check_circle_outline,
    Icons.diamond_outlined,
    Icons.auto_awesome_outlined,
    Icons.description_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        actions: [
          if (_currentIndex == 4)
            IconButton(
              icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
              tooltip: '切换主题',
              onPressed: widget.onToggleTheme,
            ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: List.generate(5, (i) {
          return NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_icons[i], color: AppTheme.primary),
            label: _titles[i],
          );
        }),
      ),
    );
  }
}

// ============================================================
// 4. 待办模块
// ============================================================

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  bool _showLife = true; // true=生活, false=工作
  final _todos = <Map<String, dynamic>>[
    {'title': '买水果', 'done': true, 'life': true, 'priority': 2},
    {'title': '健身打卡', 'done': false, 'life': true, 'priority': 4},
    {'title': '周报提交', 'done': false, 'life': false, 'priority': 5},
    {'title': '代码审查', 'done': false, 'life': false, 'priority': 3},
    {'title': '读书30分钟', 'done': true, 'life': true, 'priority': 2},
    {'title': '项目会议', 'done': false, 'life': false, 'priority': 4},
  ];

  List<Map<String, dynamic>> get _filtered =>
      _todos.where((t) => t['life'] == _showLife && t['done'] == false).toList();

  List<Map<String, dynamic>> get _done =>
      _todos.where((t) => t['life'] == _showLife && t['done'] == true).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 统计卡片
        _buildStatsCard(),
        // 分类切换
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildCategoryChip('生活', Icons.home, Colors.green, _showLife,
                  () => setState(() => _showLife = true)),
              const SizedBox(width: 12),
              _buildCategoryChip('工作', Icons.work, Colors.blue, !_showLife,
                  () => setState(() => _showLife = false)),
              const Spacer(),
              Text('完成 ${_done.length}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
        // 列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                ..._filtered.map((t) => _buildTodoTile(t, false)),
                if (_done.isNotEmpty && _filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('已完成',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ),
                ..._done.map((t) => _buildTodoTile(t, true)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final total = _todos.where((t) => t['life'] == _showLife).length;
    final done = _done.length;
    final rate = total > 0 ? (done / total * 100).toInt() : 0;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(Icons.today, '今日', '$done/$total', Colors.blue),
            _divider(),
            _statItem(Icons.receipt_long, '完成率', '$rate%', Colors.green),
            _divider(),
            _statItem(Icons.star, '优先级', '${_showLife ? 4 : 5}', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value, Color c) {
    return Column(
      children: [
        Icon(icon, color: c, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: Colors.grey.shade300);

  Widget _buildCategoryChip(
      String label, IconData icon, Color c, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: c, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? c : Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? c : Colors.grey,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoTile(Map<String, dynamic> t, bool done) {
    final c = t['life'] as bool ? Colors.green : Colors.blue;
    return ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? c : Colors.grey.shade400,
      ),
      title: Text(t['title'] as String, style: TextStyle(
        decoration: done ? TextDecoration.lineThrough : null,
        color: done ? Colors.grey : null,
      )),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4)),
            child: Text(t['life'] as bool ? '生活' : '工作',
                style: TextStyle(fontSize: 10, color: c)),
          ),
          const SizedBox(width: 8),
          ...List.generate(
              t['priority'] as int,
              (i) => const Icon(Icons.star, size: 12, color: Colors.orange)),
        ],
      ),
    );
  }
}

// ============================================================
// 5. 文玩模块
// ============================================================

class CollectionListPage extends StatelessWidget {
  const CollectionListPage({super.key});

  final _items = const [
    {'name': '绿松石手串', 'category': '松石', 'price': 2800, 'color': Color(0xFF4CAF50)},
    {'name': '南红玛瑙', 'category': '南红', 'price': 3600, 'color': Color(0xFFE53935)},
    {'name': '金刚菩提', 'category': '菩提', 'price': 1200, 'color': Color(0xFF795548)},
    {'name': '和田玉吊坠', 'category': '和田玉', 'price': 5800, 'color': Color(0xFF9E9E9E)},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.diamond, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text('共 ${_items.length} 件藏品',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const Spacer(),
              const Text('4 个分类',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final item = _items[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        color: (item['color'] as Color).withOpacity(0.15),
                        child: Center(
                          child: Icon(Icons.diamond,
                              size: 48,
                              color: (item['color'] as Color).withOpacity(0.5)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(item['category'] as String,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.primary)),
                              ),
                              const Spacer(),
                              Text('¥${item['price']}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 6. AI 复盘模块
// ============================================================

class ReviewHomePage extends StatelessWidget {
  const ReviewHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 今日状态
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '${DateTime.now().month}/${DateTime.now().day}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日',
                        style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text('今日尚未复盘',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.grey.shade300, size: 32),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // AI 复盘入口
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text('AI 每日复盘',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('回顾今天的工作与生活，让 AI 帮你总结和提升。',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showReviewDialog(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('开始今日复盘'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 本周周报
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_view_week, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text('第 ${_getWeekNumber(DateTime.now())} 周周报',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Chip(
                      label: const Text('未生成',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('生成周报'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 历史记录
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text('${DateTime.now().month}月复盘记录',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('本月暂无复盘记录',
                      style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _getWeekNumber(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final diff = date.difference(firstDay).inDays;
    return ((diff + firstDay.weekday - 1) / 7).ceil();
  }

  void _showReviewDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _DailyReviewSheet(),
    );
  }
}

class _DailyReviewSheet extends StatefulWidget {
  const _DailyReviewSheet();

  @override
  State<_DailyReviewSheet> createState() => _DailyReviewSheetState();
}

class _DailyReviewSheetState extends State<_DailyReviewSheet> {
  int _mood = 3;
  int _energy = 3;
  String _summary = '';
  bool _showAI = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('每日复盘',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('今日总结'),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _summary = v,
              decoration: const InputDecoration(
                hintText: '今天做了什么？有什么收获？',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _emojiPicker('情绪',
                    ['😞', '😐', '🙂', '😊', '😄'], _mood, (v) => setState(() => _mood = v))),
                const SizedBox(width: 16),
                Expanded(child: _emojiPicker('能量',
                    ['🪫', '🔋', '⚡', '⚡⚡', '⚡⚡⚡'], _energy, (v) => setState(() => _energy = v))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => setState(() => _showAI = true),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI 生成复盘评语'),
              ),
            ),
            if (_showAI) ...[
              const SizedBox(height: 16),
              Card(
                color: AppTheme.primary.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 18),
                          const SizedBox(width: 8),
                          const Text('AI 评语',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Chip(
                              label: Text('平稳',
                                  style: TextStyle(fontSize: 11))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('平稳度过的一天，完成了日常任务，保持了良好的节奏。'
                          '建议明天可以尝试挑战一个更有难度的任务。'),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 4),
                      const Text('💡 建议'),
                      const SizedBox(height: 4),
                      const Text('尝试每天留出 15 分钟给自己，放松心情。'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiPicker(String label, List<String> emojis, int selected,
      ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(emojis.length, (i) {
            final sel = i + 1 == selected;
            return GestureDetector(
              onTap: () => onChanged(i + 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sel
                      ? AppTheme.primary.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: sel
                      ? Border.all(color: AppTheme.primary, width: 2)
                      : null,
                ),
                child: Center(child: Text(emojis[i], style: const TextStyle(fontSize: 18))),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ============================================================
// 7. 简历模块
// ============================================================

class ResumeHomePage extends StatelessWidget {
  const ResumeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: '个人信息'),
              Tab(text: '工作经历'),
              Tab(text: '技能'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildProfileTab(context),
                _buildWorkTab(),
                _buildSkillTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(labelText: '姓名'),
          controller: TextEditingController(text: '张三'),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '职位头衔'),
          controller: TextEditingController(text: 'Flutter 开发工程师'),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '邮箱'),
          controller: TextEditingController(text: 'zhangsan@example.com'),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '个人简介'),
          maxLines: 3,
          controller: TextEditingController(
              text: '5年移动端开发经验，专注于 Flutter 跨平台开发。'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save),
            label: const Text('保存信息'),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkTab() {
    final works = [
      {'company': '字节跳动', 'position': 'Flutter 高级工程师', 'year': '2022-至今'},
      {'company': '阿里巴巴', 'position': '移动端开发工程师', 'year': '2019-2022'},
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...works.map((w) => Card(
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: AppTheme.primary),
                ),
                title: Text(w['company'] as String),
                subtitle: Text('${w['position']} · ${w['year']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(value: true, onChanged: (_) {}),
                    IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () {}),
                  ],
                ),
              ),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: OutlinedButton.icon(
            onPressed: () => {},
            icon: const Icon(Icons.add),
            label: const Text('添加工作经历'),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillTab() {
    final skills = [
      {'name': 'Flutter', 'level': 5, 'cat': '框架'},
      {'name': 'Dart', 'level': 4, 'cat': '语言'},
      {'name': 'Swift', 'level': 3, 'cat': '语言'},
      {'name': 'Riverpod', 'level': 4, 'cat': '框架'},
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...skills.map((s) => Card(
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${s['level']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary)),
                  ),
                ),
                title: Text(s['name'] as String),
                subtitle: Text(s['cat'] as String),
                trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () {}),
              ),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('添加技能'),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 8. 设置页
// ============================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static void _ignoreSwitch(bool v) {}

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _section('外观', [
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题模式'),
            subtitle: const Text('浅色'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ]),
        _section('AI 配置', [
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('API Key'),
            subtitle: const Text('已配置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('API 地址'),
            subtitle: const Text('https://api.openai.com/v1'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ]),
        _section('通知', [
          const SwitchListTile(
            title: Text('每日复盘提醒'),
            subtitle: Text('默认 21:00'),
            value: true,
            onChanged: _ignoreSwitch,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SwitchListTile(
            title: Text('每周周报提醒'),
            subtitle: Text('每周日 20:00'),
            value: true,
            onChanged: _ignoreSwitch,
          ),
        ]),
        _section('数据', [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('导出备份'),
            subtitle: const Text('加密导出全部数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('导入备份'),
            subtitle: const Text('从加密文件恢复'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ]),
        _section('关于', [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本'),
            subtitle: Text('v1.0.0'),
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              )),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }
}
