// 个人全能助手 — DartPad 兼容版
// 复制到 https://dartpad.dev 运行

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
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      home: const MainScreen(),
    );
  }
}

// ============================================================
// 主壳 — 底部导航 5 Tab
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;

  static const _titles = ['待办', '文玩', '复盘', '简历', '设置'];
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
      appBar: AppBar(title: Text(_titles[_tab])),
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
        onTap: (i) => setState(() => _tab = i),
        items: List.generate(
          5,
          (i) => BottomNavigationBarItem(
            icon: Icon(_icons[i]),
            label: _titles[i],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 1. 待办
// ============================================================

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  bool _life = true;
  final _data = [
    _T('买水果', true, true, 2),
    _T('健身打卡', false, true, 4),
    _T('周报', false, false, 5),
    _T('审查代码', false, false, 3),
    _T('读书', true, true, 2),
    _T('开会', false, false, 4),
  ];

  @override
  Widget build(BuildContext context) {
    final cur = _data.where((t) => t.life == _life && !t.done).toList();
    final done = _data.where((t) => t.life == _life && t.done).toList();
    final c = _life ? Colors.green : Colors.blue;
    final total = _data.where((t) => t.life == _life).length;
    return Column(children: [
      // 统计
      Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _s('今日', '${done.length}/$total', Colors.blue),
                _s('完成率', total > 0 ? '${(done.length / total * 100).round()}%' : '0%',
                    Colors.green),
                _s('最高', '${_data.where((t) => t.priority >= 4 && t.life == _life).length}',
                    Colors.orange),
              ]),
        ),
      ),
      // 分类
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _chip('生活', Icons.home, Colors.green, _life, () => setState(() => _life = true)),
          const SizedBox(width: 8),
          _chip('工作', Icons.work, Colors.blue, !_life, () => setState(() => _life = false)),
          const Spacer(),
          Text('$total', style: const TextStyle(color: Colors.grey)),
        ]),
      ),
      // 列表
      Expanded(
        child: ListView(children: [
          ...cur.map((t) => _item(t, false, c)),
          if (done.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('已完成 ${done.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            ...done.map((t) => _item(t, true, c)),
          ],
        ]),
      ),
    ]);
  }

  Widget _s(String l, String v, Color c) =>
      Column(children: [
        Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 16)),
        Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]);

  Widget _chip(String l, IconData ic, Color c, bool sel, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? c.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: sel ? Border.all(color: c) : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 16, color: sel ? c : Colors.grey),
            const SizedBox(width: 4),
            Text(l,
                style: TextStyle(
                    color: sel ? c : Colors.grey,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
          ]),
        ),
      );

  Widget _item(_T t, bool done, Color c) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? c : Colors.grey),
          title: Text(t.title,
              style: TextStyle(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? Colors.grey : null)),
          subtitle: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(t.life ? '生活' : '工作',
                  style: TextStyle(fontSize: 10, color: c)),
            ),
            const SizedBox(width: 8),
            ...List.generate(t.priority,
                (i) => const Icon(Icons.star, size: 12, color: Colors.orange)),
          ]),
        ),
      );
}

class _T {
  final String title;
  final bool done, life;
  final int priority;
  const _T(this.title, this.done, this.life, this.priority);
}

// ============================================================
// 2. 文玩
// ============================================================

class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final e = _items[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Expanded(
              child: Container(
                color: e.color.withOpacity(0.1),
                child: Center(
                    child: Icon(Icons.diamond, size: 48, color: e.color.withOpacity(0.3))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(e.cat,
                        style: const TextStyle(fontSize: 10, color: Colors.deepPurple)),
                  ),
                  const Spacer(),
                  Text('¥${e.price}',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

const _items = [
  _E('绿松石手串', '松石', 2800, Colors.teal),
  _E('南红玛瑙', '南红', 3600, Colors.red),
  _E('金刚菩提', '菩提', 1200, Colors.brown),
  _E('和田玉吊坠', '和田玉', 5800, Colors.blueGrey),
  _E('紫砂壶', '紫砂', 4200, Colors.deepOrange),
  _E('小叶紫檀', '杂项', 1800, Colors.purple),
];

class _E {
  final String name, cat;
  final int price;
  final Color color;
  const _E(this.name, this.cat, this.price, this.color);
}

// ============================================================
// 3. AI 复盘
// ============================================================

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text('${n.month}/${n.day}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.deepPurple))),
            ),
            const SizedBox(width: 12),
            const Text('今日尚未复盘', style: TextStyle(color: Colors.grey)),
            const Spacer(),
            const Icon(Icons.check_circle, color: Colors.grey),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            ElevatedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _Sheet(),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('开始今日复盘'),
            ),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.calendar_view_week, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('第 ${n.weekday} 周周报'),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('生成')),
          ]),
        ),
      ),
    ]);
  }
}

class _Sheet extends StatefulWidget {
  const _Sheet();
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  int _m = 3;
  int _e = 3;
  bool _ai = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('每日复盘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
              hintText: '今天做了什么？', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => setState(() => _ai = true),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('AI 生成'),
        ),
        if (_ai) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('平稳度过的一天，继续保持。'),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('保存')),
      ]),
    );
  }
}

// ============================================================
// 4. 简历
// ============================================================

class ResumePage extends StatelessWidget {
  const ResumePage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(
        decoration: const InputDecoration(labelText: '姓名'),
        controller: TextEditingController(text: '张三'),
      ),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(labelText: '职位'),
        controller: TextEditingController(text: 'Flutter 工程师'),
      ),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(labelText: '邮箱'),
        controller: TextEditingController(text: 'a@b.com'),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.save),
        label: const Text('保存'),
      ),
    ]);
  }
}

// ============================================================
// 5. 设置
// ============================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _g('外观', [
        ListTile(
          leading: const Icon(Icons.palette),
          title: const Text('主题模式'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
      ]),
      _g('AI 配置', [
        ListTile(
          leading: const Icon(Icons.key),
          title: const Text('API Key'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
      ]),
      _g('通知', [
        SwitchListTile(
          title: const Text('每日复盘提醒'),
          value: true,
          onChanged: (_) {},
        ),
      ]),
      _g('关于', [
        const ListTile(title: Text('版本 v1.0.0'), leading: Icon(Icons.info_outline)),
      ]),
    ]);
  }

  Widget _g(String t, List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(t,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.deepPurple[400], fontSize: 13)),
        ),
        Card(child: Column(children: c)),
      ]);
}
