import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/local_storage.dart';
import '../../models/trip.dart';
import '../../models/expense.dart';
import '../../utils/constants.dart';

class DriverHomeScreen extends StatefulWidget {
  final String driverId;
  const DriverHomeScreen({super.key, required this.driverId});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _cargoCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  bool _hasActiveTrip = false;
  String? _activeTripId;
  DateTime? _tripStart;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _checkActive();
  }

  void _checkActive() {
    final store = context.read<LocalStorage>();
    final active = store.trips.where((t) => t.driverId == widget.driverId && t.status == TripStatus.active).firstOrNull;
    setState(() {
      _hasActiveTrip = active != null;
      _activeTripId = active?.id;
      _tripStart = active?.startTime;
    });
  }

  void _startTrip() {
    final store = context.read<LocalStorage>();
    final vehicles = store.vehicles.where((v) => !v.isActive).toList();
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет свободных машин'), backgroundColor: Colors.red));
      return;
    }

    final tripId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    store.addTrip(Trip(
      id: tripId, driverId: widget.driverId, vehicleId: vehicles.first.id, status: TripStatus.active,
      startTime: now, startLatitude: 55.7558, startLongitude: 37.6173,
      cargoDescription: _cargoCtrl.text.trim().isEmpty ? null : _cargoCtrl.text.trim(),
      routeDescription: _routeCtrl.text.trim().isEmpty ? null : _routeCtrl.text.trim(),
      mileage: 0, mileageSource: MileageSource.auto, createdAt: now,
    ));
    _cargoCtrl.clear(); _routeCtrl.clear();
    _checkActive();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рейс начат!'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    final driverTrips = store.trips.where((t) => t.driverId == widget.driverId).toList();
    final df = DateFormat('dd.MM.yyyy HH:mm');

    if (_hasActiveTrip) {
      return ActiveTripScreen(driverId: widget.driverId, tripId: _activeTripId!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Кабинет водителя'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacementNamed(context, '/')),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          const Text('НОВЫЙ РЕЙС', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: _cargoCtrl, decoration: const InputDecoration(labelText: 'Описание груза', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _routeCtrl, decoration: const InputDecoration(labelText: 'Маршрут', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(height: 50, child: ElevatedButton.icon(
            onPressed: _startTrip, icon: const Icon(Icons.play_arrow, size: 28),
            label: const Text('Начать рейс', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ]))),
        const SizedBox(height: 20),
        Text('История рейсов', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (driverTrips.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Нет рейсов')))
        else ...driverTrips.reversed.map((t) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
          leading: CircleAvatar(backgroundColor: (t.status == TripStatus.active ? Colors.green : Colors.blue).withOpacity(0.15), child: Icon(t.status == TripStatus.active ? Icons.drive_eta : Icons.check_circle, color: t.status == TripStatus.active ? Colors.green : Colors.blue)),
          title: Text(t.routeDescription ?? 'Без маршрута'),
          subtitle: Text('${df.format(t.startTime)} • ${t.mileage.toStringAsFixed(1)} км'),
          trailing: Text('${t.income?.toStringAsFixed(0) ?? 0} ₽', style: TextStyle(fontWeight: FontWeight.bold, color: t.income != null ? Colors.green.shade700 : Colors.grey)),
        ))),
      ])),
    );
  }
}

// ===== АКТИВНЫЙ РЕЙС =====
class ActiveTripScreen extends StatefulWidget {
  final String driverId;
  final String tripId;
  const ActiveTripScreen({super.key, required this.driverId, required this.tripId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final store = context.read<LocalStorage>();
      final trip = store.trips.where((t) => t.id == widget.tripId).firstOrNull;
      if (trip != null && trip.status == TripStatus.active) {
        setState(() => _elapsed = DateTime.now().difference(trip.startTime));
      }
    });
  }

  void _addExpense() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    ExpenseCategory cat = ExpenseCategory.fuel;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: const Text('Добавить расход'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<ExpenseCategory>(
          value: cat, decoration: const InputDecoration(labelText: 'Категория', border: OutlineInputBorder()),
          items: ExpenseCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(expenseCategoryLabel(c)))).toList(),
          onChanged: (v) => setD(() => cat = v!),
        ),
        const SizedBox(height: 10),
        TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Сумма', border: OutlineInputBorder(), suffixText: '₽'), keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          final a = double.tryParse(amountCtrl.text);
          if (a == null || a <= 0) return;
          final now = DateTime.now();
          context.read<LocalStorage>().addExpense(Expense(id: now.millisecondsSinceEpoch.toString(), tripId: widget.tripId, driverId: widget.driverId, amount: a, category: cat, description: descCtrl.text, latitude: 55.75, longitude: 37.61, photoTimestamp: now, createdAt: now));
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Расход добавлен'), backgroundColor: Colors.green));
        }, child: const Text('Сохранить')),
      ],
    )));
  }

  void _endTrip() {
    final incomeCtrl = TextEditingController();
    final mileageCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Завершить рейс'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: mileageCtrl, decoration: const InputDecoration(labelText: 'Пробег (км)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        TextField(controller: incomeCtrl, decoration: const InputDecoration(labelText: 'Доход (₽)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          final store = context.read<LocalStorage>();
          final idx = store.trips.indexWhere((t) => t.id == widget.tripId);
          if (idx == -1) return;
          final old = store.trips[idx];
          final mileage = double.tryParse(mileageCtrl.text) ?? 0;
          store.trips[idx] = Trip(
            id: old.id, driverId: old.driverId, vehicleId: old.vehicleId, status: TripStatus.completed,
            startTime: old.startTime, startLatitude: old.startLatitude, startLongitude: old.startLongitude,
            endTime: DateTime.now(), endLatitude: 55.8, endLongitude: 37.6,
            mileage: mileage > 0 ? mileage : 100.0, mileageSource: mileage > 0 ? MileageSource.manual : MileageSource.auto,
            income: double.tryParse(incomeCtrl.text), routeDescription: old.routeDescription, cargoDescription: old.cargoDescription,
            createdAt: old.createdAt,
          );
          Navigator.pop(ctx);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DriverHomeScreen(driverId: widget.driverId)));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рейс завершён!'), backgroundColor: Colors.green));
        }, child: const Text('Завершить')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    final trip = store.trips.where((t) => t.id == widget.tripId).firstOrNull;
    if (trip == null || trip.status != TripStatus.active) {
      return DriverHomeScreen(driverId: widget.driverId);
    }

    final tripExpenses = store.expenses.where((e) => e.tripId == widget.tripId).toList();
    final expenseTotal = tripExpenses.fold(0.0, (s, e) => s + e.amount);

    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('Активный рейс'), leading: const SizedBox()),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(color: Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          const Text('ВРЕМЯ В ПУТИ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text('$h:$m:$s', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 4)),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _statCard('Расходов', '$expenseTotal ₽', Icons.receipt_long, Colors.orange)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Чеков', '${tripExpenses.length}', Icons.image, Colors.purple)),
        ]),
        const SizedBox(height: 16),
        SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _addExpense, icon: const Icon(Icons.add), label: const Text('Добавить расход'), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white))),
        const SizedBox(height: 12),
        SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _endTrip, icon: const Icon(Icons.stop_circle), label: const Text('Завершить рейс'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white))),
      ])),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Icon(icon, color: color, size: 24), const SizedBox(height: 4),
      Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ])));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}
