import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import 'active_trip_screen.dart';
import 'trip_history_screen.dart';

/// Главный экран водителя.
/// Если нет активного рейса — показывает кнопку «Начать рейс».
/// Если есть активный рейс — перенаправляет на экран рейса.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _cargoCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().checkActiveTrip();
    });
  }

  @override
  void dispose() {
    _cargoCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  Future<void> _startTrip() async {
    final tripProvider = context.read<TripProvider>();

    final success = await tripProvider.startTrip(
      vehicleId: _selectedVehicleId ?? 'default',
      cargoDescription: _cargoCtrl.text.trim().isEmpty ? null : _cargoCtrl.text.trim(),
      routeDescription: _routeCtrl.text.trim().isEmpty ? null : _routeCtrl.text.trim(),
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ActiveTripScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tripProvider.error ?? 'Не удалось начать рейс'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tripProvider = context.watch<TripProvider>();

    // Если есть активный рейс, показываем экран рейса
    if (tripProvider.activeTrip != null) {
      return const ActiveTripScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'История рейсов',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Приветствие
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.account_circle, size: 64, color: Colors.white70),
                    const SizedBox(height: 12),
                    Text(
                      '${auth.profile?.displayName ?? 'Водитель'}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      auth.profile?.email ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Форма начала рейса
            Text('Новый рейс',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _cargoCtrl,
              decoration: const InputDecoration(
                labelText: 'Описание груза',
                prefixIcon: Icon(Icons.inventory),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _routeCtrl,
              decoration: const InputDecoration(
                labelText: 'Маршрут',
                prefixIcon: Icon(Icons.route),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: tripProvider.isLoading ? null : _startTrip,
                icon: tripProvider.isLoading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow, size: 28),
                label: Text(
                  tripProvider.isLoading ? 'Запуск...' : 'Начать рейс',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
