import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/local_storage.dart';

class SuperadminScreen extends StatefulWidget {
  final LocalStorage storage;
  const SuperadminScreen({super.key, required this.storage});
  @override
  State<SuperadminScreen> createState() => _SuperadminScreenState();
}

class _SuperadminScreenState extends State<SuperadminScreen> {
  int _tab = 0;
  LocalStorage get s => widget.storage;

  @override
  Widget build(BuildContext context) {
    final owners = s.users.where((u) => u['role'] == 'owner').toList();
    final drivers = s.users.where((u) => u['role'] == 'driver').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель Numino'),
        actions: [
          TextButton.icon(onPressed: () { s.setCurrentUser(null); }, icon: const Icon(Icons.logout, size: 16), label: const Text('Выйти')),
        ],
      ),
      body: Column(children: [
        Row(children: [
          _tabBtn('Владельцы (${owners.length})', 0),
          _tabBtn('Тарифы', 1),
          _tabBtn('Статистика', 2),
          _tabBtn('Тикеты', 3),
        ]),
        Expanded(child: [_ownersTab(owners), _tariffsTab(owners), _statsTab(owners, drivers), _ticketsTab()][_tab]),
      ]),
    );
  }

  Widget _tabBtn(String label, int i) => Expanded(child: InkWell(
    onTap: () => setState(() => _tab = i),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2))),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: _tab == i ? FontWeight.bold : FontWeight.normal, color: _tab == i ? Theme.of(context).colorScheme.primary : Colors.grey)),
    ),
  ));

  Widget _ownersTab(List<Map<String,dynamic>> owners) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Expanded(child: Text('Владельцы парков', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ElevatedButton.icon(onPressed: () => _addOwner(), icon: const Icon(Icons.add, size: 16), label: const Text('Добавить')),
      ]),
      const SizedBox(height: 10),
      ...owners.map((o) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        leading: CircleAvatar(child: Text((o['displayName'] ?? '?')[0].toUpperCase())),
        title: Text(o['displayName'] ?? o['email'] ?? ''),
        subtitle: Text('${o['email']}'),
        trailing: Switch(value: o['active'] != false, onChanged: (v) { o['active'] = v; s.saveUsers(); setState(() {}); }),
      ))),
    ]);
  }

  void _addOwner() {
    final n = TextEditingController(), e = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Добавить владельца'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: e, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')), ElevatedButton(onPressed: () { if (e.text.isNotEmpty) s.addUser(e.text, 'owner123', n.text, 'owner'); Navigator.pop(ctx); setState(() {}); }, child: const Text('Добавить'))],
    ));
  }

  Widget _tariffsTab(List<Map<String,dynamic>> owners) {
    final plans = {'start': 'Старт (990 ₽, 1-2 маш)', 'business': 'Бизнес (1 990 ₽, 3-5 маш)', 'corp': 'Корпоративный (индив.)'};
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Тарифные планы', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ...plans.entries.map((e) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(title: Text(e.value)))),
      const SizedBox(height: 16),
      Text('Назначение', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ...owners.map((o) {
        final t = s.getOwnerTariff(o['uid'] ?? '') ?? 'start';
        return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
          title: Text(o['displayName'] ?? ''),
          trailing: DropdownButton<String>(value: t, underline: const SizedBox(), items: plans.keys.map((k) => DropdownMenuItem(value: k, child: Text(plans[k]!.split('(')[0]))).toList(), onChanged: (v) { if (v != null) { s.setOwnerTariff(o['uid'] ?? '', v); setState(() {}); } }),
        ));
      }),
    ]);
  }

  Widget _statsTab(List owners, List drivers) {
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _card('Владельцев', '${owners.length}', Icons.business, Colors.blue),
        _card('Водителей', '${drivers.length}', Icons.person, Colors.green),
        _card('Машин', '${s.vehicles.length}', Icons.directions_car, Colors.orange),
        _card('Рейсов', '${s.trips.length}', Icons.route, Colors.purple),
      ]),
    ]));
  }

  Widget _card(String t, String v, IconData i, Color c) => SizedBox(width: 160, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
    Icon(i, color: c, size: 24), const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
  ]))));

  Widget _ticketsTab() {
    final tickets = s.tickets;
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (tickets.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Нет обращений'))),
      ...tickets.map((t) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        leading: CircleAvatar(backgroundColor: t['status'] == 'new' ? Colors.red.shade100 : Colors.green.shade100, child: Icon(t['status'] == 'new' ? Icons.mail : Icons.done, color: t['status'] == 'new' ? Colors.red : Colors.green)),
        title: Text(t['name'] ?? 'Без имени'),
        subtitle: Text('${t['email']} • ${t['message'] ?? ''}', maxLines: 2),
        trailing: t['status'] == 'new' ? TextButton(onPressed: () { t['status'] = 'resolved'; setState(() {}); }, child: const Text('Закрыть')) : null,
      ))),
    ]);
  }
}
