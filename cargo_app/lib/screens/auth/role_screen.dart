import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/local_storage.dart';
import '../../providers/vehicle_provider.dart';
import '../owner/owner_dashboard_screen.dart';

/// Экран выбора роли — две кнопки вместо логина.
class RoleScreen extends StatelessWidget {
  final LocalStorage storage;
  const RoleScreen({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStorage>.value(value: storage),
        ChangeNotifierProvider(create: (_) => VehicleProvider(storage)),
      ],
      child: Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_shipping, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Numino', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Рабочий кабинет перевозчика', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 36),
            SizedBox(
              width: 280, height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDashboardScreen())),
                icon: const Icon(Icons.business, size: 24),
                label: const Text('Владелец автопарка', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 280, height: 56,
              child: OutlinedButton.icon(
                onPressed: () => _showDriverInfo(context),
                icon: const Icon(Icons.person, size: 24),
                label: const Text('Водитель', style: TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.grey.shade400)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showDriverInfo(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Приложение водителя'),
      content: const Text('Приложение для водителя находится в разработке.\n\nСкачайте APK с сайта Numino.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ));
  }
}
