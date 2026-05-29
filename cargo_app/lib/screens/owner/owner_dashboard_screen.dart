import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common_widgets.dart';
import 'vehicles_screen.dart';
import 'trips_screen.dart';
import 'expenses_screen.dart';
import 'salary_screen.dart';

/// Дашборд владельца парка.
/// Показывает сводную статистику и навигацию по разделам.
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
      context.read<VehicleProvider>().loadVehicles(auth.profile!.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final vehicleProvider = context.watch<VehicleProvider>();

    final screens = <Widget>[
      // Главная — дашборд
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
                Text(auth.profile?.displayName ?? ''),
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
          // Адаптивная навигация: боковое меню на широком экране, вкладки снизу на узком
          if (constraints.maxWidth >= 800) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: _buildDestinations(),
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
              destinations: _buildDestinations()
                  .map((d) => NavigationDestination(icon: d.icon, label: d.label))
                  .toList(),
            )
          : null,
    );
  }

  List<NavigationRailDestination> _buildDestinations() {
    return const [
      NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Дашборд')),
      NavigationRailDestination(icon: Icon(Icons.directions_car), label: Text('Машины')),
      NavigationRailDestination(icon: Icon(Icons.route), label: Text('Рейсы')),
      NavigationRailDestination(icon: Icon(Icons.receipt_long), label: Text('Расходы')),
      NavigationRailDestination(icon: Icon(Icons.payments), label: Text('Зарплата')),
    ];
  }

  static const _titles = ['Дашборд', 'Автомобили', 'Рейсы', 'Расходы', 'Зарплата'];

  Widget _buildDashboard(VehicleProvider vehicleProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Обзор парка', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          // Статистика
          LayoutBuilder(
            builder: (ctx, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: constraints.maxWidth >= 600 ? 200 : constraints.maxWidth,
                  child: AppWidgets.statCard(
                    title: 'Всего машин',
                    value: '${vehicleProvider.vehicles.length}',
                    icon: Icons.directions_car,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth >= 600 ? 200 : constraints.maxWidth,
                  child: AppWidgets.statCard(
                    title: 'В рейсе',
                    value: '${vehicleProvider.activeCount}',
                    icon: Icons.drive_eta,
                    color: Colors.green,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth >= 600 ? 200 : constraints.maxWidth,
                  child: AppWidgets.statCard(
                    title: 'Свободны',
                    value: '${vehicleProvider.freeCount}',
                    icon: Icons.local_parking,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text('Быстрые действия', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildQuickAction(Icons.route, 'Все рейсы', () => setState(() => _selectedIndex = 2)),
              _buildQuickAction(Icons.receipt_long, 'Расходы', () => setState(() => _selectedIndex = 3)),
              _buildQuickAction(Icons.payments, 'Зарплата', () => setState(() => _selectedIndex = 4)),
              _buildQuickAction(Icons.directions_car, 'Автопарк', () => setState(() => _selectedIndex = 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
