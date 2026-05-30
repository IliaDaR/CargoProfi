import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/local_storage.dart';
import '../../models/vehicle.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';
import 'vehicles_screen.dart';
import 'trips_screen.dart';
import 'expenses_screen.dart';
import 'salary_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});
  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vp = context.watch<VehicleProvider>();
    final storage = context.watch<LocalStorage>();

    final screens = [_dash(vp, storage), const VehiclesScreen(), const TripsScreen(), const ExpensesScreen(), const SalaryScreen()];

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_idx]), actions: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          const Icon(Icons.account_circle, size: 20), const SizedBox(width: 6),
          Text(auth.displayName ?? 'Владелец'), const SizedBox(width: 12),
          TextButton.icon(onPressed: () => auth.logout(), icon: const Icon(Icons.logout, size: 18), label: const Text('Выйти')),
        ])),
      ]),
      body: LayoutBuilder(builder: (ctx, c) => c.maxWidth >= 800
        ? Row(children: [
            NavigationRail(selectedIndex: _idx, onDestinationSelected: (i) => setState(() => _idx = i), labelType: NavigationRailLabelType.all, destinations: _navRail()),
            const VerticalDivider(width: 1),
            Expanded(child: screens[_idx]),
          ])
        : screens[_idx]),
      bottomNavigationBar: MediaQuery.of(context).size.width < 800 ? NavigationBar(selectedIndex: _idx, onDestinationSelected: (i) => setState(() => _idx = i), destinations: _navBar()) : null,
    );
  }

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
    final completed = store.trips.where((t) => t.status == TripStatus.completed);
    final income = completed.fold(0.0, (s, t) => s + (t.income ?? 0));
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Обзор парка', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(width: 170, child: AppWidgets.statCard(title: 'Всего машин', value: '${vp.vehicles.length}', icon: Icons.directions_car, color: Colors.blue)),
        SizedBox(width: 170, child: AppWidgets.statCard(title: 'В рейсе', value: '${vp.activeCount}', icon: Icons.drive_eta, color: Colors.green)),
        SizedBox(width: 170, child: AppWidgets.statCard(title: 'Свободны', value: '${vp.freeCount}', icon: Icons.local_parking, color: Colors.orange)),
        SizedBox(width: 170, child: AppWidgets.statCard(title: 'Рейсов', value: '${completed.length}', icon: Icons.route, color: Colors.purple)),
        SizedBox(width: 170, child: AppWidgets.statCard(title: 'Доход', value: '${income.toStringAsFixed(0)} ₽', icon: Icons.attach_money, color: Colors.green.shade700)),
      ]),
    ]));
  }
}
