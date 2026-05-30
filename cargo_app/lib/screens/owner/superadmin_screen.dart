import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/local_storage.dart';

class SuperadminScreen extends StatefulWidget {
  final LocalStorage storage;
  const SuperadminScreen({super.key, required this.storage});
  @override
  State<SuperadminScreen> createState() => _SuperadminScreenState();
}

class _SuperadminScreenState extends State<SuperadminScreen> {
  int _tab = 0;
  LocalStorage get store => widget.storage;

  @override
  Widget build(BuildContext context) {
    final owners = store.users.where((u) => u['role'] == 'owner').toList();
    final drivers = store.users.where((u) => u['role'] == 'driver').toList();

    final tabs = [
      _ownersTab(store, owners),
      _tariffsTab(store, owners),
      _statsTab(store, owners, drivers),
      _ticketsTab(store),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель Numino'),
        actions: [
          TextButton.icon(
            onPressed: () {
              // Выход из суперадмина
              store.setCurrentUser(null);
              Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Выйти'),
          ),
        ],
      ),
      body: Column(children: [
        Row(children: [
          _tabBtn('Владельцы', 0),
          _tabBtn('Тарифы', 1),
          _tabBtn('Статистика', 2),
          _tabBtn('Тикеты', 3),
        ]),
        Expanded(child: tabs[_tab]),
      ]),
    );
  }

  Widget _tabBtn(String label, int i) => Expanded(child: InkWell(
    onTap: () => setState(() => _tab = i),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _tab == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2)),
      ),
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: _tab == i ? FontWeight.bold : FontWeight.normal, color: _tab == i ? Theme.of(context).colorScheme.primary : Colors.grey)),
    ),
  ));

  // ===== ВЛАДЕЛЬЦЫ =====
  Widget _ownersTab(LocalStorage store, List<Map<String,dynamic>> owners) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Expanded(child: Text('Владельцы парков (${owners.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ElevatedButton.icon(onPressed: () => _addOwner(store), icon: const Icon(Icons.add, size: 16), label: const Text('Добавить')),
      ]),
      const SizedBox(height: 10),
      ...owners.map((o) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        leading: CircleAvatar(child: Text((o['displayName'] ?? '?')[0])),
        title: Text(o['displayName'] ?? o['email'] ?? ''),
        subtitle: Text('${o['email']} • ${_getTariff(store, o['uid'] ?? '')}'),
        trailing: Switch(
          value: o['active'] != false,
          onChanged: (v) { o['active'] = v; store.saveUsers(); setState(() {}); },
        ),
      ))),
    ]);
  }

  void _addOwner(LocalStorage store) {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Добавить владельца'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          if (emailCtrl.text.isEmpty) return;
          store.addUser(emailCtrl.text, 'owner123', nameCtrl.text, 'owner');
          Navigator.pop(ctx);
          setState(() {});
        }, child: const Text('Добавить')),
      ],
    ));
  }

  // ===== ТАРИФЫ =====
  final Map<String, Map<String,dynamic>> _tariffs = {
    'start': {'name': 'Старт', 'price': 990, 'trial': 21, 'cars': '1-2'},
    'business': {'name': 'Бизнес', 'price': 1990, 'trial': 14, 'cars': '3-5'},
    'corp': {'name': 'Корпоративный', 'price': 0, 'trial': 0, 'cars': '6+'},
  };

  Widget _tariffsTab(LocalStorage store, List<Map<String,dynamic>> owners) {
    final ownerTariffs = <String, String>{};
    for (var o in owners) {
      final t = store.getOwnerTariff(o['uid'] ?? '');
      if (t != null) ownerTariffs[o['uid'] ?? ''] = t;
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Тарифные планы', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ..._tariffs.entries.map((e) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        title: Text(e.value['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${e.value['cars']} машин • ${e.value['price']} ₽/мес • Триал: ${e.value['trial']} дн'),
        trailing: const Icon(Icons.chevron_right),
      ))),
      const SizedBox(height: 16),
      Text('Назначение тарифов', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ...owners.map((o) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        leading: CircleAvatar(child: Text((o['displayName'] ?? '?')[0])),
        title: Text(o['displayName'] ?? ''),
        trailing: DropdownButton<String>(
          value: ownerTariffs[o['uid']] ?? 'start',
          underline: const SizedBox(),
          items: _tariffs.keys.map((k) => DropdownMenuItem(value: k, child: Text(_tariffs[k]!['name'] as String))).toList(),
          onChanged: (v) {
            if (v != null) {
              store.setOwnerTariff(o['uid'] ?? '', v);
              setState(() { ownerTariffs[o['uid'] ?? ''] = v; });
            }
          },
        ),
      ))),
    ]);
  }

  String _getTariff(LocalStorage store, String uid) {
    final t = store.getOwnerTariff(uid);
    if (t == null) return 'Без тарифа';
    final info = _tariffs[t];
    return info != null ? '${info['name']} (${info['price']} ₽)' : t;
  }

  // ===== СТАТИСТИКА =====
  Widget _statsTab(LocalStorage store, List<Map<String,dynamic>> owners, List<Map<String,dynamic>> drivers) {
    final totalTrips = store.trips.length;
    final totalExpenses = store.expenses.fold(0.0, (s, e) => s + e.amount);
    final activeTrips = store.trips.where((t) => t.status.toString() == 'TripStatus.active').length;

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _statCard('Владельцев', '${owners.length}', Icons.business, Colors.blue),
        _statCard('Водителей', '${drivers.length}', Icons.person, Colors.green),
        _statCard('Машин', '${store.vehicles.length}', Icons.directions_car, Colors.orange),
        _statCard('Рейсов всего', '$totalTrips', Icons.route, Colors.purple),
        _statCard('Активных', '$activeTrips', Icons.drive_eta, Colors.green.shade700),
        _statCard('Расходов', '${totalExpenses.toStringAsFixed(0)} ₽', Icons.receipt_long, Colors.red),
      ]),
      const SizedBox(height: 20),
      Text('Последние рейсы', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      ...store.trips.reversed.take(5).map((t) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
        title: Text(t.routeDescription ?? 'Без названия'),
        subtitle: Text(DateFormat('dd.MM.yyyy').format(t.startTime)),
        trailing: Text('${t.mileage.toStringAsFixed(1)} км'),
      ))),
    ]));
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return SizedBox(width: 180, child: Card(
      child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ])),
      ])),
    ));
  }

  // ===== ТИКЕТЫ =====
  Widget _ticketsTab(LocalStorage store) {
    final tickets = store.tickets;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Обращения (${tickets.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      if (tickets.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Нет обращений'))),
      ...tickets.map((t) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        leading: CircleAvatar(backgroundColor: t['status'] == 'new' ? Colors.red.shade100 : Colors.green.shade100, child: Icon(t['status'] == 'new' ? Icons.mail : Icons.done, color: t['status'] == 'new' ? Colors.red : Colors.green)),
        title: Text(t['name'] ?? 'Без имени'),
        subtitle: Text('${t['email']} • ${t['message'] ?? ''}', maxLines: 2),
        trailing: t['status'] == 'new'
          ? TextButton(onPressed: () { t['status'] = 'resolved'; store.saveTickets(); setState(() {}); }, child: const Text('Закрыть'))
          : null,
      ))),
    ]);
  }
}
