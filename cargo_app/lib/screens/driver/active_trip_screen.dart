import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/expense_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';
import 'add_expense_screen.dart';

/// Экран активного рейса: таймер, пробег, GPS-точки, расходы.
class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final _manualMileageCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  bool _showEndDialog = false;

  @override
  void dispose() {
    _manualMileageCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _endTrip() async {
    final tripProvider = context.read<TripProvider>();
    final manualMileage = double.tryParse(_manualMileageCtrl.text);
    final income = double.tryParse(_incomeCtrl.text);

    final success = await tripProvider.endTrip(
      manualMileage: manualMileage,
      income: income,
    );

    if (success && mounted) {
      Navigator.pop(context); // закрываем диалог
      Navigator.pushReplacementNamed(context, '/driver');
      AppWidgets.showSuccess(context, 'Рейс успешно завершён!');
    } else if (mounted) {
      AppWidgets.showError(context, tripProvider.error ?? 'Ошибка завершения');
    }
  }

  void _showEndTripDialog() {
    _manualMileageCtrl.clear();
    _incomeCtrl.clear();
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final tripProvider = context.read<TripProvider>();
          final hasGpsData = tripProvider.localMileage > 0;

          return AlertDialog(
            title: const Text('Завершить рейс'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasGpsData) ...[
                    Text('Пробег по GPS: ${tripProvider.localMileage.toStringAsFixed(1)} км'),
                    const SizedBox(height: 4),
                    const Text('Будет использован автоматический расчёт.',
                      style: TextStyle(color: Colors.green, fontSize: 12)),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _manualMileageCtrl,
                    decoration: InputDecoration(
                      labelText: hasGpsData ? 'Пробег вручную (если сбой GPS)' : 'Пробег (км) *',
                      border: const OutlineInputBorder(),
                      suffixText: 'км',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _incomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Доход за рейс',
                      border: OutlineInputBorder(),
                      suffixText: '₽',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: tripProvider.isLoading ? null : () => _endTrip(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: tripProvider.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Завершить рейс'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();

    if (tripProvider.activeTrip == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/driver');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Активный рейс'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Карточка таймера
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('ВРЕМЯ В ПУТИ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      tripProvider.formattedDuration,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Карточки статистики
            Row(
              children: [
                Expanded(
                  child: AppWidgets.statCard(
                    title: 'Пробег',
                    value: '${tripProvider.localMileage.toStringAsFixed(1)} км',
                    icon: Icons.speed,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppWidgets.statCard(
                    title: 'GPS-точек',
                    value: '${tripProvider.localTrack.length}',
                    icon: Icons.gps_fixed,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Кнопка добавления расхода
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(tripId: tripProvider.activeTrip!.id),
                  ),
                ),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Добавить расход', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Кнопка завершения рейса
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _showEndTripDialog,
                icon: const Icon(Icons.stop_circle, size: 28),
                label: const Text('Завершить рейс', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
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
