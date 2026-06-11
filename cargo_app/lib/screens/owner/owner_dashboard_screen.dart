import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/local_storage.dart';
import '../../models/vehicle.dart';
import '../../utils/constants.dart';
import '../../models/trip.dart';
import '../../models/expense.dart';
import '../../widgets/common_widgets.dart';
import '../../services/notification_service.dart';
import '../../utils/navigation.dart';
import '../auth/role_screen.dart';
import 'vehicles_screen.dart';
import 'trips_screen.dart';
import 'expenses_screen.dart';
import 'salary_screen.dart';
import 'notifications_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});
  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VehicleProvider>();
    final storage = context.watch<LocalStorage>();

    final screens = [_dash(vp, storage), const VehiclesScreen(), const TripsScreen(), const ExpensesScreen(), const SalaryScreen()];

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_idx]), actions: [
        // Колокольчик уведомлений
        Stack(children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          if (NotificationService.unreadCount > 0)
            Positioned(right: 6, top: 6, child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text('${NotificationService.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            )),
      ]),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          const Icon(Icons.account_circle, size: 20), const SizedBox(width: 6),
          Text(storage.currentUser?['displayName'] ?? 'Владелец'), const SizedBox(width: 12),
          TextButton.icon(onPressed: () {
            storage.setCurrentUser(null);
            goHome(context);
          }, icon: const Icon(Icons.logout, size: 18), label: const Text('Выйти')),
        ])),
      ]),
      body: LayoutBuilder(builder: (ctx, c) => c.maxWidth > 800
        ? Row(children: [
            NavigationRail(selectedIndex: _idx, onDestinationSelected: (i) => setState(() => _idx = i), labelType: NavigationRailLabelType.all, destinations: _navRail()),
            const VerticalDivider(width: 1),
            Expanded(child: screens[_idx]),
          ])
        : screens[_idx]),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 800 ? NavigationBar(selectedIndex: _idx, onDestinationSelected: (i) => setState(() => _idx = i), destinations: _navBar()) : null,
    );
  }

  void _goToVehicles() => setState(() => _idx = 1);

  Widget _onboardingCard(String title, String subtitle, IconData icon, int targetTab) => Card(
    color: Colors.blue.shade50,
    child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      Icon(icon, size: 48, color: Colors.blue.shade300),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () => _idx = targetTab, icon: const Icon(Icons.add_circle, size: 18), label: Text(title)),
    ])),
  );

  static const _titles = ['Дашборд', 'Автомобили', 'Рейсы', 'Расходы', 'Зарплата'];

  List<NavigationRailDestination> _navRail() => const [
    NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Дашборд')),
    NavigationRailDestination(icon: Icon(Icons.directions_car), label: Text('Машины')),
    NavigationRailDestination(icon: Icon(Icons.route), label: Text('Рейсы')),
    NavigationRailDestination(icon: Icon(Icons.receipt_long), label: Text('Расходы')),
    NavigationRailDestination(icon: Icon(Icons.payments), label: Text('Зарплата')),
  ];

  List<NavigationDestination> _navBar() => const [
    NavigationDestination(icon: Icon(Icons.dashboard), label: 'Дашборд'),
    NavigationDestination(icon: Icon(Icons.directions_car), label: 'Машины'),
    NavigationDestination(icon: Icon(Icons.route), label: 'Рейсы'),
    NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Расходы'),
    NavigationDestination(icon: Icon(Icons.payments), label: 'Зарплата'),
  ];

  Widget _dash(VehicleProvider vp, LocalStorage store) {
    final ownerId = store.currentUser?['uid'] ?? '';
    final myVehicles = store.vehicles.where((v) => v.ownerId == ownerId).toList();
    final myDrivers = store.drivers.where((d) => d['ownerId'] == ownerId).toList();
    final myDriverIds = myDrivers.map((d) => d['uid']).toSet();
    final myTrips = store.trips.where((t) => myDriverIds.contains(t.driverId)).toList();
    final completed = myTrips.where((t) => t.status == TripStatus.completed);
    final income = completed.fold(0.0, (s, t) => s + (t.income ?? 0));
    final activeTrips = myTrips.where((t) => t.status == TripStatus.active).toList();
    final myExpenses = store.expenses.where((e) => myDriverIds.contains(e.driverId)).toList();
    final expenseTotal = myExpenses.fold(0.0, (s, e) => s + e.amount);

    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Quick actions
      _quickActions(),
      const SizedBox(height: 16),

      Text('Обзор парка', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),

      // Stat cards
      Wrap(spacing: 10, runSpacing: 10, children: [
        _statCard('Всего машин', '${myVehicles.length}', Icons.directions_car, Colors.blue),
        _statCard('В рейсе', '${myVehicles.where((v) => v.isActive).length}', Icons.drive_eta, Colors.green),
        _statCard('Свободны', '${myVehicles.where((v) => !v.isActive).length}', Icons.local_parking, Colors.orange),
        _statCard('Рейсов', '${completed.length}', Icons.route, Colors.purple),
        _statCard('Доход', '${income.toStringAsFixed(0)} ₽', Icons.attach_money, Colors.green.shade700),
        _statCard('Расходы', '${expenseTotal.toStringAsFixed(0)} ₽', Icons.receipt_long, Colors.red.shade400),
        _statCard('Прибыль', '${(income - expenseTotal).toStringAsFixed(0)} ₽', Icons.trending_up, Colors.teal),
      ]),

      // Tiered empty states
      if (myVehicles.isEmpty)
        _onboardingCard('Добавьте первую машину', 'Начните с добавления автомобиля в ваш парк.', Icons.directions_car, 1)
      else if (myDrivers.isEmpty)
        _onboardingCard('Пригласите первого водителя', 'Добавьте водителя для назначения на рейсы.', Icons.person_add, 1)
      else if (completed.isEmpty && activeTrips.isEmpty)
        _onboardingCard('Начните первый рейс', 'Водитель может начать рейс из приложения.', Icons.route, 2),

      // Active trips
      if (activeTrips.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('В рейсе сейчас', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...activeTrips.map((t) => _activeTripCard(store, t)),
      ],

      // Activity feed
      if (myTrips.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text('Последняя активность', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._activityFeed(store, myTrips, myExpenses),
      ],
    ]));
  }

  Widget _quickActions() => Row(children: [
    ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('Машина'), onPressed: () => setState(() => _idx = 1)),
    const SizedBox(width: 8),
    ActionChip(avatar: const Icon(Icons.person_add, size: 16), label: const Text('Водитель'), onPressed: () => setState(() => _idx = 1)),
    const SizedBox(width: 8),
    ActionChip(avatar: const Icon(Icons.route, size: 16), label: const Text('Рейсы'), onPressed: () => setState(() => _idx = 2)),
  ]);

  Widget _activeTripCard(LocalStorage store, Trip t) {
    final v = store.vehicles.where((v) => v.id == t.vehicleId).firstOrNull;
    final d = store.drivers.where((d) => d['uid'] == t.driverId).firstOrNull;
    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
      leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.drive_eta, color: Colors.white, size: 20)),
      title: Text('${v?.brand ?? ''} ${v?.model ?? ''} → ${d?['displayName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(t.routeDescription ?? 'В пути'),
      trailing: const Chip(label: Text('В рейсе', style: TextStyle(fontSize: 11)), backgroundColor: Colors.green),
    ));
  }

  List<Widget> _activityFeed(LocalStorage store, List<Trip> trips, List<Expense> expenses) {
    final items = <Widget>[];
    final recentTrips = trips.where((t) => t.status == TripStatus.completed).take(3).toList();
    final recentExpenses = expenses.take(3).toList();

    for (final t in recentTrips) {
      final d = store.drivers.where((d) => d['uid'] == t.driverId).firstOrNull;
      items.add(ListTile(
        leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 20)),
        title: Text('${d?['displayName'] ?? 'Водитель'} — ${t.routeDescription ?? 'Рейс'}', style: const TextStyle(fontSize: 13)),
        subtitle: Text('${t.mileage.toStringAsFixed(0)} км • ${t.income != null ? '${t.income!.toStringAsFixed(0)} ₽' : '—'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        dense: true,
      ));
    }
    for (final e in recentExpenses) {
      final d = store.drivers.where((d) => d['uid'] == e.driverId).firstOrNull;
      items.add(ListTile(
        leading: CircleAvatar(backgroundColor: Colors.red.shade100, child: Icon(Icons.receipt, color: Colors.red.shade700, size: 20)),
        title: Text('${d?['displayName'] ?? 'Водитель'} — ${e.description ?? expenseCategoryLabel(e.category)}', style: const TextStyle(fontSize: 13)),
        subtitle: Text('−${e.amount.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 11, color: Colors.red)),
        dense: true,
      ));
    }
    return items;
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return LayoutBuilder(builder: (ctx, constraints) {
      return SizedBox(
        width: constraints.maxWidth > 400 ? 180 : constraints.maxWidth / 2 - 16,
        child: AppWidgets.statCard(title: title, value: value, icon: icon, color: color),
      );
    });
  }
}
