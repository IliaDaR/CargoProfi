import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/local_storage.dart';
import '../../models/trip.dart';
import '../../models/expense.dart';
import '../../utils/constants.dart';
import '../../services/notification_service.dart';
import '../auth/role_screen.dart';

Position? _lastPosition;

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

  void _startTrip() async {
    final store = context.read<LocalStorage>();
    final vehicles = store.vehicles.where((v) => !v.isActive).toList();
    if (vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет свободных машин'), backgroundColor: Colors.red));
      return;
    }

    // Получаем реальные GPS-координаты (веб: browser, Android: GPS)
    double lat = 55.75, lon = 37.61;
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 10));
      lat = pos.latitude; lon = pos.longitude;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось получить GPS. Использованы координаты по умолчанию.'), backgroundColor: Colors.orange));
    }

    final tripId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    store.addTrip(Trip(
      id: tripId, driverId: widget.driverId, vehicleId: vehicles.first.id, status: TripStatus.active,
      startTime: now, startLatitude: lat, startLongitude: lon,
      cargoDescription: _cargoCtrl.text.trim().isEmpty ? null : _cargoCtrl.text.trim(),
      routeDescription: _routeCtrl.text.trim().isEmpty ? null : _routeCtrl.text.trim(),
      mileage: 0, mileageSource: MileageSource.auto, createdAt: now,
    ));
    _cargoCtrl.clear(); _routeCtrl.clear();
    _checkActive();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рейс начат!'), backgroundColor: Colors.green));
    NotificationService.tripStarted(Trip(
      id: tripId, driverId: widget.driverId, vehicleId: vehicles.first.id, status: TripStatus.active,
      startTime: now, startLatitude: lat, startLongitude: lon,
      routeDescription: _cargoCtrl.text.trim().isEmpty ? null : _cargoCtrl.text.trim(),
      createdAt: now, mileage: 0, mileageSource: MileageSource.auto,
    ), 'Водитель');
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
        IconButton(icon: const Icon(Icons.logout), onPressed: () {
          store.setCurrentUser(null);
          html.window.location.href = '/';
        }),
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
  Timer? _gpsTimer;
  Duration _elapsed = Duration.zero;
  final List<Map<String, double>> _track = [];

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
    // GPS-трекинг каждые 30 секунд
    _gpsTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));
        _track.add({'latitude': pos.latitude, 'longitude': pos.longitude});
      } catch (_) {}
    });
  }

  void _addExpense() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    ExpenseCategory cat = ExpenseCategory.fuel;
    Uint8List? photoBytes;
    final picker = ImagePicker();

    // Получаем GPS
    double lat = 55.75, lon = 37.61;
    try { final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 10)); lat = pos.latitude; lon = pos.longitude; } catch (_) {}

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
        const SizedBox(height: 10),
        // Фото чека
        Row(children: [
          OutlinedButton.icon(
            onPressed: () async {
              final img = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
              if (img != null) { photoBytes = await img.readAsBytes(); setD(() {}); }
            },
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Камера', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
              if (img != null) { photoBytes = await img.readAsBytes(); setD(() {}); }
            },
            icon: const Icon(Icons.photo_library, size: 18),
            label: const Text('Галерея', style: TextStyle(fontSize: 12)),
          ),
        ]),
        if (photoBytes != null) ...[
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(photoBytes!, height: 120, fit: BoxFit.cover)),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          final a = double.tryParse(amountCtrl.text);
          if (a == null || a <= 0) return;
          final now = DateTime.now();
          final receiptUrl = photoBytes != null ? 'data:image/jpeg;base64,${base64Encode(photoBytes!)}' : null;
          context.read<LocalStorage>().addExpense(Expense(id: now.millisecondsSinceEpoch.toString(), tripId: widget.tripId, driverId: widget.driverId, amount: a, category: cat, description: descCtrl.text, latitude: lat, longitude: lon, photoTimestamp: now, createdAt: now, receiptUrl: receiptUrl));
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Расход добавлен'), backgroundColor: Colors.green));
        }, child: const Text('Сохранить')),
      ],
    )));
  }

  void _endTrip() async {
    final incomeCtrl = TextEditingController();
    final mileageCtrl = TextEditingController();

    double lat = 55.75, lon = 37.61;
    try { final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 10)); lat = pos.latitude; lon = pos.longitude; } catch (_) {}

    // Расчёт пробега по GPS-треку
    final double autoMileage = _calculateTrackMileage();
    bool useAuto = autoMileage > 0;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Завершить рейс'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (useAuto)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Пробег по GPS: ${autoMileage.toStringAsFixed(1)} км', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        TextField(controller: mileageCtrl, decoration: InputDecoration(
          labelText: useAuto ? 'Пробег вручную (необязательно)' : 'Пробег (км)',
          border: const OutlineInputBorder(),
        ), keyboardType: TextInputType.number),
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
          final manual = double.tryParse(mileageCtrl.text) ?? 0;
          final mileage = manual > 0 ? manual : (useAuto ? autoMileage : 100.0);
          store.trips[idx] = Trip(
            id: old.id, driverId: old.driverId, vehicleId: old.vehicleId, status: TripStatus.completed,
            startTime: old.startTime, startLatitude: old.startLatitude, startLongitude: old.startLongitude,
            endTime: DateTime.now(), endLatitude: lat, endLongitude: lon,
            mileage: mileage, mileageSource: manual > 0 || !useAuto ? MileageSource.manual : MileageSource.auto,
            income: double.tryParse(incomeCtrl.text), routeDescription: old.routeDescription, cargoDescription: old.cargoDescription,
            createdAt: old.createdAt, track: _track.map((p) => TrackPoint(latitude: p['latitude']!, longitude: p['longitude']!, timestamp: DateTime.now())).toList(),
          );
          );
          store.saveTrips();
          Navigator.pop(ctx);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DriverHomeScreen(driverId: widget.driverId)));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рейс завершён!'), backgroundColor: Colors.green));
          final completed = store.trips[idx];
          NotificationService.tripCompleted(completed, 'Водитель');
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

  double _calculateTrackMileage() {
    if (_track.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _track.length; i++) {
      total += _haversine(_track[i-1]['latitude']!, _track[i-1]['longitude']!, _track[i]['latitude']!, _track[i]['longitude']!);
    }
    return (total * 10).roundToDouble() / 10;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * 3.14159 / 180;
    final dLon = (lon2 - lon1) * 3.14159 / 180;
    final a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * 3.14159/180) * cos(lat2 * 3.14159/180) * sin(dLon/2) * sin(dLon/2);
    return R * 2 * atan2(sqrt(a), sqrt(1-a));
  }

  @override
  void dispose() { _timer?.cancel(); _gpsTimer?.cancel(); super.dispose(); }
}
