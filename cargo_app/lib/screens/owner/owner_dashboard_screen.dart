import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../models/vehicle.dart';
import '../../utils/constants.dart';
import '../../models/demo_data.dart';
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
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<VehicleProvider>().loadVehicles(auth.profile?.uid ?? 'demo');
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vehicleProvider = context.watch<VehicleProvider>();

    final screens = <Widget>[
      _buildDashboard(vehicleProvider),
      const VehiclesScreen(),
      const TripsScreen(),
      const ExpensesScreen(),
      const SalaryScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.account_circle, size: 20),
                const SizedBox(width: 6),
                Text(auth.profile?.displayName ?? 'Администратор'),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => auth.signOut(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Выйти'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          if (constraints.maxWidth >= 800) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Дашборд')),
                    NavigationRailDestination(icon: Icon(Icons.directions_car), label: Text('Машины')),
                    NavigationRailDestination(icon: Icon(Icons.route), label: Text('Рейсы')),
                    NavigationRailDestination(icon: Icon(Icons.receipt_long), label: Text('Расходы')),
                    NavigationRailDestination(icon: Icon(Icons.payments), label: Text('Зарплата')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: screens[_selectedIndex]),
              ],
            );
          }
          return screens[_selectedIndex];
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 800
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard), label: 'Дашборд'),
                NavigationDestination(icon: Icon(Icons.directions_car), label: 'Машины'),
                NavigationDestination(icon: Icon(Icons.route), label: 'Рейсы'),
                NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Расходы'),
                NavigationDestination(icon: Icon(Icons.payments), label: 'Зарплата'),
              ],
            )
          : null,
    );
  }

  static const _titles = ['Дашборд', 'Автомобили', 'Рейсы', 'Расходы', 'Зарплата'];

  Widget _buildDashboard(VehicleProvider vp) {
    final vehicles = vp.vehicles;
    final trips = DemoData.trips;
    final completedTrips = trips.where((t) => t.status == TripStatus.completed);
    final totalIncome = completedTrips.fold(0.0, (s, t) => s + (t.income ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Обзор парка', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 180, child: AppWidgets.statCard(title: 'Всего машин', value: '${vehicles.length}', icon: Icons.directions_car, color: Colors.blue)),
            SizedBox(width: 180, child: AppWidgets.statCard(title: 'В рейсе', value: '${vp.activeCount}', icon: Icons.drive_eta, color: Colors.green)),
            SizedBox(width: 180, child: AppWidgets.statCard(title: 'Свободны', value: '${vp.freeCount}', icon: Icons.local_parking, color: Colors.orange)),
            SizedBox(width: 180, child: AppWidgets.statCard(title: 'Рейсов', value: '${completedTrips.length}', icon: Icons.route, color: Colors.purple)),
            SizedBox(width: 180, child: AppWidgets.statCard(title: 'Доход', value: '$totalIncome ₽', icon: Icons.attach_money, color: Colors.green.shade700)),
          ]),
          const SizedBox(height: 24),
          Text('Быстрые действия', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _actionBtn(Icons.add_circle, 'Добавить авто', () { setState(() => _selectedIndex = 1); _showAddVehicle(); }),
            _actionBtn(Icons.route, 'Все рейсы', () => setState(() => _selectedIndex = 2)),
            _actionBtn(Icons.receipt_long, 'Расходы', () => setState(() => _selectedIndex = 3)),
            _actionBtn(Icons.payments, 'Зарплата', () => setState(() => _selectedIndex = 4)),
          ]),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center)]),
      ),
    );
  }

  void _showAddVehicle() {
    final plateCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить автомобиль'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Госномер', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Марка', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Модель', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(onPressed: () {
            final vp = context.read<VehicleProvider>();
            vp.addVehicle(Vehicle(
              id: 'v${vp.vehicles.length + 10}', ownerId: 'demo',
              plateNumber: plateCtrl.text, brand: brandCtrl.text, model: modelCtrl.text,
              createdAt: DateTime.now(),
            ));
            Navigator.pop(ctx);
            AppWidgets.showSuccess(context, 'Автомобиль добавлен!');
          }, child: const Text('Добавить')),
        ],
      ),
    );
  }
}
