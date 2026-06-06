// 个人全能助手 — DartPad 兼容版
// 复制全部代码到 https://dartpad.dev 运行

import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '个人全能助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

// ============================================================
// 主屏幕 — 底部导航 5 Tab
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;

  static const _titles = ['待办清单', '文玩记录', 'AI 复盘', '简历管理', '设置'];
  static const _icons = [
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
        title: Text(_titles[_tab]),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          TodoPage(),
          CollectionPage(),
          ReviewPage(),
          ResumePage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        onTap: (i) => setState(() => _tab = i),
        items: List.generate(5, (i) => BottomNavigationBarItem(
          icon: Icon(_icons[i]),
          activeIcon: Icon(_icons[i], color: Colors.deepPurple),
          label: _titles[i],
        )),
      ),
    );
  }
}

// ============================================================
// 1. 待办清单模块
// ============================================================

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  bool _isLife = true;

  final _allTodos = [
    _Todo('买水果', true, true, 2),
    _Todo('健身打卡', false, true, 4),
    _Todo('周报提交', false, false, 5),
    _Todo('代码审查', false, false, 3),
    _Todo('读书30分钟', true, true, 2),
    _Todo('项目会议', false, false, 4),
    _Todo('洗衣服', false, true, 1),
  ];

  List<_Todo> get _current => _allTodos
      .where((t) => t.isLife == _isLife && !t.done)
      .toList();
  List<_Todo> get _done => _allTodos
      .where((t) => t.isLife == _isLife && t.done)
      .toList();

  @override
  Widget build(BuildContext context) {
    final color = _isLife ? Colors.green : Colors.blue;
    final total = _allTodos.where((t) => t.isLife == _isLife).length;
    final doneCount = _done.length;
    final rate = total > 0 ? (doneCount / total * 100).round() : 0;

    return Column(
      children: [
        // 统计卡
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat(Icons.today, '今日', '$doneCount/$total', Colors.blue),
                _stat(Icons.trending_up, '完成率', '$rate%', Colors.green),
                _stat(Icons.star, '最高优先级',
                    '${_allTodos.where((t) => t.priority >= 4 && t.isLife == _isLife).length}',
                    Colors.orange),
              ],
            ),
          ),
        ),

        // 分类切换
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _chip('生活', Icons.home, Colors.green, _isLife, () => setState(() => _isLife = true)),
              const SizedBox(width: 12),
              _chip('工作', Icons.work, Colors.blue, !_isLife, () => setState(() => _isLife = false)),
              const Spacer(),
              Text('$doneCount/$total', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 列表
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ..._current.map((t) => _todoItem(t, false)),
              if (_done.isNotEmpty && _current.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('已完成  $doneCount',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ),
              ..._done.map((t) => _todoItem(t, true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _chip(String label, IconData icon, Color color, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: sel ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: sel ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: sel ? color : Colors.grey,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _todoItem(_Todo t, bool done) {
    final color = t.isLife ? Colors.green : Colors.blue;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        leading: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? color : Colors.grey,
        ),
        title: Text(t.title,
            style: TextStyle(
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? Colors.grey : null)),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(t.isLife ? '生活' : '工作',
                  style: TextStyle(fontSize: 10, color: color)),
            ),
            const SizedBox(width: 8),
            ...List.generate(t.priority, (i) => const Icon(Icons.star, size: 12, color: Colors.orange)),
          ],
        ),
      ),
    );
  }
}

class _Todo {
  final String title;
  final bool done;
  final bool isLife;
  final int priority;
  const _Todo(this.title, this.done, this.isLife, this.priority);
}

// ============================================================
// 2. 文玩记录模块
// ============================================================

class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key});

  final _items = const [
    _Item('绿松石手串', '松石', 2800, Colors.teal),
    _Item('南红玛瑙', '南红', 3600, Colors.red),
    _Item('金刚菩提', '菩提', 1200, Colors.brown),
    _Item('和田玉吊坠', '和田玉', 5800, Colors.blueGrey),
    _Item('紫砂壶', '紫砂', 4200, Colors.deepOrange),
    _Item('小叶紫檀', '杂项', 1800, Colors.purple),
  ];

  @override
  Widget build(BuildContext context) {
    final total = _items.fold(0, (s, i) => s + i.price);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.diamond, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text('${_items.length} 件藏品',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const Spacer(),
              Text('估值 ¥$total',
                  style: const TextStyle(color: Colors.green, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final item = _items[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        color: item.color.withOpacity(0.12),
                        child: Center(
                          child: Icon(Icons.diamond, size: 48, color: item.color.withOpacity(0.4)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(item.category,
                                    style: const TextStyle(fontSize: 10, color: Colors.deepPurple)),
                              ),
                              const Spacer(),
                              Text('¥${item.price}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
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

class _Item {
  final String name;
  final String category;
  final int price;
  final Color color;
  const _Item(this.name, this.category, this.price, this.color);
}

// ============================================================
// 3. AI 复盘模块
// ============================================================

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 日期卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text('${now.month}/${now.day}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${now.year}年${now.month}月${now.day}日',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('今日尚未复盘', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.grey[300], size: 32),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // AI 复盘入口
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text('AI 每日复盘', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('回顾今天的工作与生活，让 AI 帮你总结和提升。',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showReview(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('开始今日复盘'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 本周周报
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_view_week, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text('第 ${now.weekday} 周周报',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Chip(
                      label: const Text('未生成', style: TextStyle(fontSize: 12)),
                      backgroundColor: Colors.grey[100],
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
        const SizedBox(height: 12),

        // 历史
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text('${now.month}月复盘记录',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('本月暂无复盘记录', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ReviewSheet(),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet();

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _mood = 3;
  int _energy = 3;
  bool _showAi = false;

  static const _moods = ['😞', '😐', '🙂', '😊', '😄'];
  static const _energies = ['🪫', '🔋', '⚡', '⚡', '⚡'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('每日复盘', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: '今日总结',
                hintText: '今天做了什么？有什么收获？',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _picker('情绪', _moods, _mood, (v) => setState(() => _mood = v))),
                const SizedBox(width: 16),
                Expanded(child: _picker('能量', _energies, _energy, (v) => setState(() => _energy = v))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showAi = true),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI 生成复盘评语'),
              ),
            ),
            if (_showAi) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 18, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Text('AI 评语', style: TextStyle(fontWeight: FontWeight.w600)),
                        Spacer(),
                        Text('平稳', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('平稳度过的一天，完成了日常任务，保持了良好的节奏。'),
                    SizedBox(height: 12),
                    Divider(),
                    SizedBox(height: 4),
                    Text('💡 建议', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('尝试每天留出 15 分钟给自己，放松心情。'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _picker(String label, List<String> items, int sel, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (i) {
            final selected = i + 1 == sel;
            return GestureDetector(
              onTap: () => onChanged(i + 1),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: selected ? Colors.deepPurple.withOpacity(0.15) : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: selected ? Border.all(color: Colors.deepPurple, width: 2) : null,
                ),
                child: Center(child: Text(items[i], style: const TextStyle(fontSize: 18))),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ============================================================
// 4. 简历模块
// ============================================================

class ResumePage extends StatefulWidget {
  const ResumePage({super.key});

  @override
  State<ResumePage> createState() => _ResumePageState();
}

class _ResumePageState extends State<ResumePage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '个人信息'),
            Tab(text: '工作经历'),
            Tab(text: '技能'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _profileTab(),
              _workTab(),
              _skillTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(labelText: '姓名', prefixIcon: Icon(Icons.person)),
          controller: TextEditingController(text: '张三'),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '职位头衔', prefixIcon: Icon(Icons.work)),
          controller: TextEditingController(text: 'Flutter 开发工程师'),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email)),
          controller: TextEditingController(text: 'zhangsan@example.com'),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: '个人简介'),
          maxLines: 3,
          controller: TextEditingController(text: '5年移动端开发经验，专注于 Flutter 跨平台开发。'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save),
            label: const Text('保存信息'),
          ),
        ),
      ],
    );
  }

  Widget _workTab() {
    final works = [
      ['字节跳动', 'Flutter 高级工程师', '2022-至今'],
      ['阿里巴巴', '移动端开发工程师', '2019-2022'],
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...works.map((w) => Card(
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.business, color: Colors.deepPurple),
            ),
            title: Text(w[0]),
            subtitle: Text('${w[1]} · ${w[2]}'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {}),
          ),
        )),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('添加工作经历'),
          ),
        ),
      ],
    );
  }

  Widget _skillTab() {
    final skills = [
      ['Flutter', '框架', '5'],
      ['Dart', '语言', '4'],
      ['Swift', '语言', '3'],
      ['Riverpod', '框架', '4'],
      ['Git', '工具', '4'],
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...skills.map((s) => Card(
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(s[2], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              ),
            ),
            title: Text(s[0]),
            subtitle: Text(s[1]),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {}),
          ),
        )),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
// 5. 设置页
// ============================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _group('外观', [
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题模式'),
            subtitle: const Text('浅色模式'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言'),
            subtitle: const Text('中文'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 8),
        _group('AI 配置', [
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('API Key'),
            subtitle: const Text('sk-xxxxxxxxxxxx'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('API 地址'),
            subtitle: const Text('https://api.openai.com/v1'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.model_training),
            title: const Text('模型'),
            subtitle: const Text('gpt-3.5-turbo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 8),
        _group('通知', [
          SwitchListTile(
            title: const Text('每日复盘提醒'),
            subtitle: const Text('默认 21:00'),
            value: true,
            onChanged: (_) {},
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile(
            title: const Text('每周周报提醒'),
            subtitle: const Text('每周日 20:00'),
            value: true,
            onChanged: (_) {},
          ),
        ]),
        const SizedBox(height: 8),
        _group('数据', [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('导出备份'),
            subtitle: const Text('加密导出全部数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('导入备份'),
            subtitle: const Text('从加密文件恢复'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 8),
        _group('关于', [
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

  Widget _group(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(title, style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple[400],
          )),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
