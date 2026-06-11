import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/local_storage.dart';
import '../../utils/constants.dart';
import '../../utils/navigation.dart';

class SuperadminScreen extends StatefulWidget {
  final LocalStorage storage;
  const SuperadminScreen({super.key, required this.storage});
  @override
  State<SuperadminScreen> createState() => _SuperadminScreenState();
}

class _SuperadminScreenState extends State<SuperadminScreen> {
  int _tab = 0;
  String _search = '';
  final List<Map<String, dynamic>> _logs = [];
  LocalStorage get s => widget.storage;

  @override
  void initState() {
    super.initState();
    // Восстанавливаем логи из SharedPreferences
    _logs.addAll(s.adminLogs);
  }

  void _addLog(String action, String detail) {
    _logs.insert(0, {
      'action': action, 'detail': detail,
      'time': DateFormat('dd.MM HH:mm').format(DateTime.now()),
    });
    if (_logs.length > 100) _logs.removeLast();
    s.saveAdminLogs(_logs);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final owners = s.users.where((u) => u['role'] == 'owner' || u['role'] == 'admin' || u['role'] == 'superadmin').toList();
    final drivers = s.users.where((u) => u['role'] == 'driver').toList();
    final filtered = _search.isEmpty ? owners : owners.where((o) => (o['displayName'] ?? '').toLowerCase().contains(_search.toLowerCase()) || (o['email'] ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Админ-панель Numino'), actions: [
          TextButton.icon(onPressed: () { s.setCurrentUser(null); goHome(context); }, icon: const Icon(Icons.logout, size: 16), label: const Text('Выйти')),
      ]),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _tabBtn('Владельцы (${owners.length})', 0),
          _tabBtn('Машины (${s.vehicles.length})', 1),
          _tabBtn('Водители (${drivers.length})', 2),
          _tabBtn('Тарифы', 3),
          _tabBtn('Статистика', 4),
          _tabBtn('Тикеты', 5),
          _tabBtn('Логи', 6),
        ])),
        Expanded(child: [
          _ownersTab(filtered), _vehiclesTab(owners), _driversTab(drivers, owners), _tariffsTab(owners), _statsTab(owners, drivers), _ticketsTab(), _logsTab(),
        ][_tab]),
      ]),
    );
  }

  Widget _tabBtn(String label, int i) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: InkWell(
      onTap: () => setState(() => _tab = i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2))),
        child: Text(label, style: TextStyle(fontWeight: _tab == i ? FontWeight.bold : FontWeight.normal, color: _tab == i ? Theme.of(context).colorScheme.primary : Colors.grey, fontSize: 13)),
    )));

  // ===== ВЛАДЕЛЬЦЫ =====
  Widget _ownersTab(List<Map<String,dynamic>> owners) {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: TextField(
          decoration: const InputDecoration(hintText: 'Поиск по имени или email...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
          onChanged: (v) => setState(() => _search = v),
        )),
        const SizedBox(width: 8),
        ElevatedButton.icon(onPressed: _addOwner, icon: const Icon(Icons.add, size: 16), label: const Text('Добавить')),
      ])),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: owners.map((o) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
        leading: CircleAvatar(child: Text((o['displayName'] ?? '?')[0].toUpperCase())),
        title: Text(o['displayName'] ?? o['email'] ?? ''),
        subtitle: Text('${o['email']} • ${o['role'] ?? 'owner'}'),
        onTap: () => _showOwnerDetail(o),
        trailing: Switch(value: o['active'] != false, onChanged: (v) {
          final action = v ? 'Разблокировать' : 'Заблокировать';
          showDialog(context: context, builder: (ctx) => AlertDialog(
            title: Text('$action владельца?'),
            content: Text('${o['displayName'] ?? o['email']}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              ElevatedButton(onPressed: () { Navigator.pop(ctx); o['active'] = v; s.saveUsers(); _addLog(action, o['email'] ?? ''); setState(() {}); }, style: ElevatedButton.styleFrom(backgroundColor: v ? Colors.green : Colors.red, foregroundColor: Colors.white), child: Text(action)),
            ],
          ));
        }),
      ))).toList())),
    ]);
  }

  void _addOwner() {
    final n = TextEditingController(), e = TextEditingController(), p = TextEditingController(text: 'owner123');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Добавить владельца'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: n, decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: e, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: p, decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()), obscureText: true),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')), ElevatedButton(onPressed: () { final email = e.text.trim(); final pass = p.text.trim(); if (email.isEmpty || !email.contains('@') || !email.contains('.')) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите корректный email'), backgroundColor: Colors.red)); return; } if (n.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите имя'), backgroundColor: Colors.red)); return; } if (pass.length < 6) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль минимум 6 символов'), backgroundColor: Colors.red)); return; } s.addUser(email, pass, n.text.trim(), 'owner'); _addLog('Добавил владельца', email); Navigator.pop(ctx); setState(() {}); }, child: const Text('Добавить'))],
    ));
  }

  void _showOwnerDetail(Map<String, dynamic> owner) {
    final uid = owner['uid'] ?? '';
    final ownerVehicles = s.vehicles.where((v) => v.ownerId == uid).toList();
    final ownerDrivers = s.drivers.where((d) => d['ownerId'] == uid).toList();
    final ownerTrips = s.trips.where((t) {
      final d = s.drivers.where((dr) => dr['uid'] == t.driverId).firstOrNull;
      return d?['ownerId'] == uid;
    }).toList();
    final activeTrips = ownerTrips.where((t) => t.status == TripStatus.active).length;
    final completedTrips = ownerTrips.where((t) => t.status == TripStatus.completed).length;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(owner['displayName'] ?? owner['email'] ?? ''),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Email: ${owner['email']}', style: const TextStyle(fontSize: 13)),
        Text('Роль: ${owner['role'] ?? 'owner'}', style: const TextStyle(fontSize: 13)),
        Text('Активен: ${owner['active'] != false ? 'Да' : 'Нет'}', style: const TextStyle(fontSize: 13)),
        const Divider(),
        Text('Машин: ${ownerVehicles.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ...ownerVehicles.map((v) => Padding(padding: const EdgeInsets.only(left: 12, top: 2), child: Text('${v.brand} ${v.model} — ${v.plateNumber}', style: const TextStyle(fontSize: 12)))),
        const Divider(),
        Text('Водителей: ${ownerDrivers.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ...ownerDrivers.map((d) => Padding(padding: const EdgeInsets.only(left: 12, top: 2), child: Text(d['displayName'] ?? d['email'] ?? '', style: const TextStyle(fontSize: 12)))),
        const Divider(),
        Text('Рейсов: всего ${ownerTrips.length} (активных $activeTrips, завершённых $completedTrips)', style: const TextStyle(fontWeight: FontWeight.bold)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
    ));
  }

  // ===== МАШИНЫ =====
  Widget _vehiclesTab(List owners) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Все машины (${s.vehicles.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...s.vehicles.map((v) {
        final owner = owners.where((o) => o['uid'] == v.ownerId).firstOrNull;
        final ownerName = owner?['displayName'] ?? owner?['email'] ?? v.ownerId.substring(0, 8);
        return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
          leading: CircleAvatar(backgroundColor: v.isActive ? Colors.green.shade100 : Colors.grey.shade100,
            child: Icon(Icons.directions_car, color: v.isActive ? Colors.green : Colors.grey)),
          title: Text('${v.brand} ${v.model}'),
          subtitle: Text('${v.plateNumber} • Владелец: $ownerName'),
          trailing: v.isActive ? Chip(label: const Text('В рейсе', style: TextStyle(fontSize: 11)), backgroundColor: Colors.green.shade50) : null,
        ));
      }),
    ]);
  }

  // ===== ВОДИТЕЛИ =====
  Widget _driversTab(List drivers, List owners) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Все водители (${drivers.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...drivers.map((d) {
        final owner = owners.where((o) => o['uid'] == d['ownerId']).firstOrNull;
        final ownerName = owner?['displayName'] ?? owner?['email'] ?? (d['ownerId'] ?? '').substring(0, 8);
        final vehicle = s.vehicles.where((v) => v.activeDriverId == d['uid']).firstOrNull;
        final driverTrips = s.trips.where((t) => t.driverId == d['uid'] && t.status == TripStatus.completed).toList();
        return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
          leading: CircleAvatar(child: Text((d['displayName'] ?? '?')[0].toUpperCase())),
          title: Text(d['displayName'] ?? d['email'] ?? ''),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d['email']} • Владелец: $ownerName', style: const TextStyle(fontSize: 12)),
            Text('Рейсов: ${driverTrips.length}${vehicle != null ? ' • За рулём: ${vehicle.plateNumber}' : ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          isThreeLine: true,
        ));
      }),
    ]);
  }

  // ===== ТАРИФЫ =====
  Widget _tariffsTab(List owners) {
    final plans = {'start': 'Старт (990 ₽, 1-2 маш)', 'business': 'Бизнес (1 990 ₽, 3-5 маш)', 'corp': 'Корпоративный (индив.)'};
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Тарифные планы', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ...plans.entries.map((e) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(title: Text(e.value)))),
      const SizedBox(height: 16),
      Text('Назначение', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ...owners.map((o) {
        final t = s.getOwnerTariff(o['uid'] ?? '') ?? 'start';
        return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
          title: Text(o['displayName'] ?? ''),
          trailing: DropdownButton<String>(value: t, underline: const SizedBox(), items: plans.keys.map((k) => DropdownMenuItem(value: k, child: Text(plans[k]!.split('(')[0]))).toList(), onChanged: (v) { if (v != null) { s.setOwnerTariff(o['uid'] ?? '', v); _addLog('Сменил тариф', '${o['email']} → ${plans[v]?.split('(')[0] ?? v}'); setState(() {}); } }),
        ));
      }),
    ]);
  }

  // ===== СТАТИСТИКА =====
  Widget _statsTab(List owners, List drivers) {
    final totalIncome = s.trips.where((t) => t.status == TripStatus.completed).fold(0.0, (sum, t) => sum + (t.income ?? 0));
    final cancelled = s.trips.where((t) => t.status == TripStatus.cancelled).length;
    final activeSubs = owners.where((o) => o['active'] != false).length;
    final avgCheck = s.trips.where((t) => t.status == TripStatus.completed && (t.income ?? 0) > 0).map((t) => t.income ?? 0).toList();
    final avg = avgCheck.isEmpty ? 0.0 : avgCheck.reduce((a, b) => a + b) / avgCheck.length;

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _card('Владельцев', '${owners.length}', Icons.business, Colors.blue),
        _card('Водителей', '${drivers.length}', Icons.person, Colors.green),
        _card('Машин', '${s.vehicles.length}', Icons.directions_car, Colors.orange),
        _card('Рейсов', '${s.trips.length}', Icons.route, Colors.purple),
        _card('Отменено', '$cancelled', Icons.cancel, Colors.red),
        _card('Выручка', '${totalIncome.toStringAsFixed(0)} ₽', Icons.attach_money, Colors.green.shade700),
        _card('Подписки', '$activeSubs активны', Icons.card_membership, Colors.amber.shade700),
        _card('Средний чек', '${avg.toStringAsFixed(0)} ₽', Icons.trending_up, Colors.teal),
      ]),
      const SizedBox(height: 20),
      // Простой столбчатый график выручки по месяцам
      _revenueChart(),
    ]));
  }

  Widget _revenueChart() {
    // Группируем доход по месяцам
    final byMonth = <String, double>{};
    for (final t in s.trips.where((t) => t.status == TripStatus.completed)) {
      final key = DateFormat('MM.yyyy').format(t.startTime);
      byMonth[key] = (byMonth[key] ?? 0) + (t.income ?? 0);
    }
    if (byMonth.isEmpty) return const SizedBox.shrink();

    final entries = byMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Выручка по месяцам', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      SizedBox(height: 150, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: entries.map((e) {
        final h = (e.value / maxVal * 120).clamp(4.0, 120.0);
        return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('${e.value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9)),
          const SizedBox(height: 2),
          Container(height: h, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.7), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 4),
          Text(e.key, style: const TextStyle(fontSize: 9)),
        ])));
      }).toList())),
    ])));
  }

  Widget _card(String t, String v, IconData i, Color c) => SizedBox(width: 160, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
    Icon(i, color: c, size: 24), const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
  ]))));

  // ===== ТИКЕТЫ =====
  Widget _ticketsTab() {
    final tickets = s.tickets;
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (tickets.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Нет обращений'))),
      ...tickets.map((t) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
        leading: CircleAvatar(backgroundColor: t['status'] == 'new' ? Colors.red.shade100 : Colors.green.shade100, child: Icon(t['status'] == 'new' ? Icons.mail : Icons.done, color: t['status'] == 'new' ? Colors.red : Colors.green)),
        title: Text(t['name'] ?? 'Без имени'),
        subtitle: Text('${t['email']} • ${t['message'] ?? ''}', maxLines: 2),
        trailing: t['status'] == 'new' ? TextButton(onPressed: () { t['status'] = 'resolved'; s.saveTickets(tickets); _addLog('Закрыл тикет', t['email'] ?? ''); setState(() {}); }, child: const Text('Закрыть')) : const Text('✓', style: TextStyle(color: Colors.green)),
      ))),
    ]);
  }

  // ===== ЛОГИ =====
  Widget _logsTab() {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Последние действия', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (_logs.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Логов пока нет'))),
      ..._logs.map((l) => Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
        dense: true,
        leading: CircleAvatar(radius: 14, backgroundColor: Colors.blue.shade100, child: const Icon(Icons.history, size: 16, color: Colors.blue)),
        title: Text(l['action'] ?? '', style: const TextStyle(fontSize: 13)),
        subtitle: Text(l['detail'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Text(l['time'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ))),
    ]);
  }
}
