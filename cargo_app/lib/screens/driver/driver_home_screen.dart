import 'dart:async';
import 'dart:convert';
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
import '../../utils/distance.dart';
import '../../utils/navigation.dart';
import '../../services/notification_service.dart';
import '../auth/role_screen.dart';
import 'trip_detail_screen.dart';
import 'driver_profile_screen.dart';

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
  Timer? _idleGpsTimer;
  Position? _lastIdlePosition;
  Position? _lastKnownPosition;
  bool _shownMovementReminder = false;

  @override
  void initState() {
    super.initState();
    _checkActive();
    _startIdleMovementDetection();
  }

  void _startIdleMovementDetection() {
    _idleGpsTimer?.cancel();
    _idleGpsTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_hasActiveTrip) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        ).timeout(const Duration(seconds: 5));
        if (_lastIdlePosition != null && !_hasActiveTrip && !_shownMovementReminder) {
          final dist = haversineDistance(
            _lastIdlePosition!.latitude, _lastIdlePosition!.longitude,
            pos.latitude, pos.longitude,
          );
          if (dist > 0.1) {
            _shownMovementReminder = true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Обнаружено движение. Не забудьте начать рейс!'),
                  backgroundColor: Colors.orange.shade700,
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(
                    label: 'Начать',
                    textColor: Colors.white,
                    onPressed: () {
                      if (_cargoCtrl.text.isEmpty && _routeCtrl.text.isEmpty) {
                        _routeCtrl.text = 'Без маршрута';
                      }
                      _startTrip();
                    },
                  ),
                ),
              );
            }
          }
        }
        _lastIdlePosition = pos;
      } catch (_) {}
    });
  }

  void _checkActive() {
    final store = context.read<LocalStorage>();
    final active = store.trips.where((t) => t.driverId == widget.driverId && t.status == TripStatus.active).firstOrNull;
    setState(() {
      _hasActiveTrip = active != null;
      _activeTripId = active?.id;
      _tripStart = active?.startTime;
      _shownMovementReminder = active != null;
    });
  }

  @override
  void dispose() {
    _idleGpsTimer?.cancel();
    _cargoCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  void _startTrip() async {
    final store = context.read<LocalStorage>();
    // Проверка: нет ли уже активного рейса
    final activeTrip = store.trips.where((t) => t.driverId == widget.driverId && t.status == TripStatus.active).firstOrNull;
    if (activeTrip != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('У вас уже есть активный рейс'), backgroundColor: Colors.orange));
      return;
    }
    final freeVehicles = store.vehicles.where((v) => !v.isActive).toList();
    if (freeVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет свободных машин'), backgroundColor: Colors.red));
      return;
    }

    // Выбор машины из списка свободных
    String? chosenId = freeVehicles.length == 1 ? freeVehicles.first.id : null;
    if (chosenId == null) {
      chosenId = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Выберите машину'),
          children: freeVehicles.map((v) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, v.id),
            child: ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text('${v.brand} ${v.model}'),
              subtitle: Text(v.plateNumber),
            ),
          )).toList(),
        ),
      );
    }
    if (chosenId == null) return; // отмена

    // Получаем реальные GPS-координаты
    double lat = _lastKnownPosition?.latitude ?? 0;
    double lon = _lastKnownPosition?.longitude ?? 0;
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 10));
      lat = pos.latitude; lon = pos.longitude;
      _lastKnownPosition = pos;
    } catch (_) {
      if (lat == 0 && lon == 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS недоступен. Включите GPS и повторите.'), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
        return;
      }
    }

    final tripId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final cargo = _cargoCtrl.text.trim().isEmpty ? null : _cargoCtrl.text.trim();
    final route = _routeCtrl.text.trim().isEmpty ? null : _routeCtrl.text.trim();
    store.addTrip(Trip(
      id: tripId, driverId: widget.driverId, vehicleId: chosenId, status: TripStatus.active,
      startTime: now, startLatitude: lat, startLongitude: lon,
      cargoDescription: cargo, routeDescription: route,
      mileage: 0, mileageSource: MileageSource.auto, createdAt: now,
    ));
    // Помечаем машину как «в рейсе»
    final vIdx = store.vehicles.indexWhere((v) => v.id == chosenId);
    if (vIdx != -1) {
      store.vehicles[vIdx] = store.vehicles[vIdx].copyWith(isActive: true, activeDriverId: widget.driverId);
      store.saveVehicles();
    }
    _cargoCtrl.clear(); _routeCtrl.clear();
    _checkActive();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рейс начат!'), backgroundColor: Colors.green));
    // Синхронизация с облаком (если доступно)
    try { context.read<dynamic>().startTrip(vehicleId: chosenId, latitude: lat, longitude: lon, cargoDescription: cargo, routeDescription: route); } catch (_) {}
    NotificationService.tripStarted(Trip(
      id: tripId, driverId: widget.driverId, vehicleId: chosenId, status: TripStatus.active,
      startTime: now, startLatitude: lat, startLongitude: lon,
      routeDescription: route, cargoDescription: cargo,
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => DriverProfileScreen(driverId: widget.driverId)));
          },
        ),
        title: const Text('Кабинет водителя'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () {
          store.setCurrentUser(null);
          goHome(context);
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
        else ...driverTrips.reversed.map((t) => InkWell(
          onTap: t.status == TripStatus.completed
            ? () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: t.id)));
              }
            : null,
          child: Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
          leading: CircleAvatar(backgroundColor: (t.status == TripStatus.active ? Colors.green : Colors.blue).withOpacity(0.15), child: Icon(t.status == TripStatus.active ? Icons.drive_eta : Icons.check_circle, color: t.status == TripStatus.active ? Colors.green : Colors.blue)),
          title: Text(t.routeDescription ?? 'Без маршрута'),
          subtitle: Text('${df.format(t.startTime)} • ${t.mileage.toStringAsFixed(1)} км'),
          trailing: Text('${t.income?.toStringAsFixed(0) ?? 0} ₽', style: TextStyle(fontWeight: FontWeight.bold, color: t.income != null ? Colors.green.shade700 : Colors.grey)),
        )),
      )),
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

class _ActiveTripScreenState extends State<ActiveTripScreen> with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _gpsTimer;
  Duration _elapsed = Duration.zero;
  final List<TrackPoint> _track = [];
  Position? _lastGpsPosition;
  DateTime? _stationarySince;
  double _lastSpeed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Восстанавливаем трек из sync queue при перезагрузке страницы
    final store = context.read<LocalStorage>();
    for (final item in store.syncQueue) {
      if (item['type'] == 'track_point' && item['data']['tripId'] == widget.tripId) {
        final d = item['data'];
        _track.add(TrackPoint(latitude: d['latitude'] as double, longitude: d['longitude'] as double, timestamp: DateTime.tryParse(d['timestamp'] ?? '') ?? DateTime.now()));
      }
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final store = context.read<LocalStorage>();
      final trip = store.trips.where((t) => t.id == widget.tripId).firstOrNull;
      if (trip != null && trip.status == TripStatus.active) {
        setState(() => _elapsed = DateTime.now().difference(trip.startTime));
      }
    });
    // GPS-трекинг каждые 30 секунд с офлайн-буфером
    _startGps();
  }

  void _startGps() {
    _gpsTimer?.cancel();
    _scheduleNextGps();
  }

  void _scheduleNextGps() {
    final interval = _getAdaptiveInterval();
    _gpsTimer = Timer(interval, _pollGps);
  }

  Duration _getAdaptiveInterval() {
    if (_lastSpeed > 15) return const Duration(seconds: 30);  // driving
    if (_lastSpeed > 3) return const Duration(seconds: 60);    // slow
    if (_stationarySince != null &&
        DateTime.now().difference(_stationarySince!).inMinutes > 30) {
      return const Duration(minutes: 30);  // parked — check rarely
    }
    return const Duration(minutes: 5);  // stationary
  }

  Future<void> _pollGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      // Calculate speed from position delta
      if (_lastGpsPosition != null) {
        _lastSpeed = pos.speed > 0
            ? pos.speed * 3.6  // m/s → km/h
            : _lastSpeed;
        if (_lastSpeed < 3) {
          _stationarySince ??= DateTime.now();
        } else {
          _stationarySince = null;
        }
      }
      _lastGpsPosition = pos;
      final now = DateTime.now();
      _track.add(TrackPoint(latitude: pos.latitude, longitude: pos.longitude, timestamp: now));

      // Сохраняем трек в рейс (защита от краша)
      final store = context.read<LocalStorage>();
      final tIdx = store.trips.indexWhere((t) => t.id == widget.tripId);
      if (tIdx != -1) {
        store.trips[tIdx] = Trip(
          id: store.trips[tIdx].id, driverId: store.trips[tIdx].driverId,
          vehicleId: store.trips[tIdx].vehicleId, status: store.trips[tIdx].status,
          startTime: store.trips[tIdx].startTime,
          startLatitude: store.trips[tIdx].startLatitude,
          startLongitude: store.trips[tIdx].startLongitude,
          endTime: store.trips[tIdx].endTime,
          endLatitude: store.trips[tIdx].endLatitude,
          endLongitude: store.trips[tIdx].endLongitude,
          mileage: store.trips[tIdx].mileage,
          mileageSource: store.trips[tIdx].mileageSource,
          cargoDescription: store.trips[tIdx].cargoDescription,
          routeDescription: store.trips[tIdx].routeDescription,
          income: store.trips[tIdx].income,
          createdAt: store.trips[tIdx].createdAt,
          track: _track.toList(),
          manualMileage: store.trips[tIdx].manualMileage,
          waybillUrl: store.trips[tIdx].waybillUrl,
          waybillUuid: store.trips[tIdx].waybillUuid,
          signatureStatus: store.trips[tIdx].signatureStatus,
          signatureUrl: store.trips[tIdx].signatureUrl,
          signatureHash: store.trips[tIdx].signatureHash,
          signedPdfUrl: store.trips[tIdx].signedPdfUrl,
          signedAt: store.trips[tIdx].signedAt,
          signedBy: store.trips[tIdx].signedBy,
        );
      }

      // Sync queue + cloud
      store.addToSyncQueue('track_point', {
        'tripId': widget.tripId, 'latitude': pos.latitude,
        'longitude': pos.longitude, 'timestamp': now.toIso8601String(),
      });
      try {
        final cloudFn = context.read<dynamic>();
        await cloudFn.addTrackPoint(tripId: widget.tripId, latitude: pos.latitude, longitude: pos.longitude);
        final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
        store.syncQueue.removeWhere((item) {
          if (item['type'] != 'track_point') return false;
          final ts = DateTime.tryParse(item['data']['timestamp'] ?? '');
          return ts != null && ts.isBefore(cutoff);
        });
      } catch (_) {}
    } catch (_) {}

    // Schedule next poll with adaptive interval
    _scheduleNextGps();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _gpsTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startGps();
    }
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
              final img = await picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70);
              if (img != null) { photoBytes = await img.readAsBytes(); setD(() {}); }
            },
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Камера', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 70);
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
          // Firebase Storage (production) или base64 (офлайн-fallback)
          final receiptUrl = photoBytes != null
              ? 'data:image/jpeg;base64,${base64Encode(photoBytes!)}'
              : null;
          context.read<LocalStorage>().addExpense(Expense(id: now.millisecondsSinceEpoch.toString(), tripId: widget.tripId, driverId: widget.driverId, amount: a, category: cat, description: descCtrl.text, latitude: lat, longitude: lon, photoTimestamp: now, createdAt: now, receiptUrl: receiptUrl));
          // Уведомление при крупных расходах
          if (a >= 10000) {
            final driverName = context.read<LocalStorage>().drivers.where((d) => d['uid'] == widget.driverId).firstOrNull?['displayName'] ?? 'Водитель';
            NotificationService.highExpense(Expense(id: '', tripId: widget.tripId, driverId: widget.driverId, amount: a, category: cat, latitude: lat, longitude: lon, photoTimestamp: now, createdAt: now), driverName);
          }
          // Синхронизация с облаком
          try { context.read<dynamic>().addExpense(tripId: widget.tripId, amount: a, category: cat.name, latitude: lat, longitude: lon, description: descCtrl.text); } catch (_) {}
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
    final double autoMileage = calculateTotalDistanceFromPoints(_track);
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
          final mileage = manual > 0 ? manual : (useAuto ? autoMileage : 0.0);
          if (mileage <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите пробег'), backgroundColor: Colors.red));
            return;
          }
          store.trips[idx] = Trip(
            id: old.id, driverId: old.driverId, vehicleId: old.vehicleId, status: TripStatus.completed,
            startTime: old.startTime, startLatitude: old.startLatitude, startLongitude: old.startLongitude,
            endTime: DateTime.now(), endLatitude: lat, endLongitude: lon,
            mileage: mileage, mileageSource: manual > 0 || !useAuto ? MileageSource.manual : MileageSource.auto,
            income: double.tryParse(incomeCtrl.text), routeDescription: old.routeDescription, cargoDescription: old.cargoDescription,
            createdAt: old.createdAt, track: _track.map((p) => TrackPoint(latitude: p.latitude, longitude: p.longitude, timestamp: p.timestamp)).toList(),
          );
          store.saveTrips(); // Сохраняем в SharedPreferences
          // Синхронизация с облаком
          try { context.read<dynamic>().endTrip(tripId: widget.tripId, latitude: lat, longitude: lon, income: double.tryParse(incomeCtrl.text)); } catch (_) {}
          // Освобождаем машину
          final vIdx2 = store.vehicles.indexWhere((v) => v.id == old.vehicleId);
          if (vIdx2 != -1) {
            store.vehicles[vIdx2] = store.vehicles[vIdx2].copyWith(isActive: false, activeDriverId: null);
            store.saveVehicles();
          }
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DriverHomeScreen(driverId: widget.driverId)));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        _buildSyncStatus(store),
        const SizedBox(height: 16),
        SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _addExpense, icon: const Icon(Icons.add), label: const Text('Добавить расход'), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white))),
        const SizedBox(height: 12),
        SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _endTrip, icon: const Icon(Icons.stop_circle), label: const Text('Завершить рейс'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white))),
      ])),
    );
  }

  Widget _buildSyncStatus(LocalStorage store) {
    final pending = store.syncQueue.length;
    if (pending == 0) {
      return Row(children: [
        Icon(Icons.cloud_done, size: 14, color: Colors.green.shade700),
        const SizedBox(width: 4),
        Text('Синхронизировано', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
      ]);
    }
    return Row(children: [
      const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      const SizedBox(width: 4),
      Text('Ожидает синхронизации: $pending', style: const TextStyle(fontSize: 11, color: Colors.orange)),
    ]);
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Icon(icon, color: color, size: 24), const SizedBox(height: 4),
      Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ])));
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _timer?.cancel(); _gpsTimer?.cancel(); super.dispose(); }
}
