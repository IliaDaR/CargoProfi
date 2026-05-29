import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trip.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../utils/distance.dart';

/// Провайдер управления рейсами для водителя.
class TripProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  final LocationService _locationService = LocationService();

  Trip? _activeTrip;
  bool _isLoading = false;
  String? _error;

  // Локальный трек для расчёта пробега (не ждём Firestore)
  final List<Map<String, double>> _localTrack = [];
  double _localMileage = 0.0;
  DateTime? _tripStartTime;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;

  StreamSubscription<Position>? _positionSub;

  Trip? get activeTrip => _activeTrip;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTracking => _locationService.isTracking;
  double get localMileage => _localMileage;
  Duration get elapsed => _elapsed;
  List<Map<String, double>> get localTrack => List.unmodifiable(_localTrack);

  /// Проверяет, есть ли активный рейс при старте приложения.
  Future<void> checkActiveTrip() async {
    _isLoading = true;
    notifyListeners();

    try {
      _activeTrip = await _firestore.getActiveTrip();
      if (_activeTrip != null) {
        _tripStartTime = _activeTrip!.startTime;
        _startDurationTimer();
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Начать рейс: запрашивает GPS, создаёт рейс в Firestore, запускает трекинг.
  Future<bool> startTrip({
    required String vehicleId,
    String? cargoDescription,
    String? routeDescription,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final hasPermission = await _locationService.requestPermission();
      if (!hasPermission) {
        _error = 'Необходимо разрешение на геолокацию';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Включите GPS на устройстве';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final position = await _locationService.getCurrentPosition();

      final tripId = await _firestore.startTrip(
        vehicleId: vehicleId,
        latitude: position.latitude,
        longitude: position.longitude,
        cargoDescription: cargoDescription,
        routeDescription: routeDescription,
      );

      // Запускаем трекинг и таймер
      _tripStartTime = DateTime.now();
      _localTrack.clear();
      _localMileage = 0.0;
      _localTrack.add({
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      _startDurationTimer();
      _startGpsTracking(tripId);

      _activeTrip = await _firestore.getActiveTrip();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка при старте рейса: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Запускает GPS-трекинг: раз в 60 сек отправляет точку в Firestore.
  void _startGpsTracking(String tripId) {
    _locationService.startTracking(interval: const Duration(seconds: 60));

    _positionSub = _locationService.positionStream.listen((position) {
      _addLocalPoint(position.latitude, position.longitude);

      _firestore.addTrackPoint(
        tripId: tripId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
  }

  /// Добавляет точку в локальный трек и обновляет пробег.
  void _addLocalPoint(double lat, double lon) {
    _localTrack.add({'latitude': lat, 'longitude': lon});
    _localMileage = calculateTotalDistance(_localTrack);
    notifyListeners();
  }

  /// Завершить рейс.
  Future<bool> endTrip({
    double? manualMileage,
    double? income,
  }) async {
    if (_activeTrip == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _locationService.stopTracking();
      _positionSub?.cancel();
      _stopDurationTimer();

      final position = await _locationService.getCurrentPosition().catchError((_) => null);
      final lat = position?.latitude ?? _localTrack.last['latitude'] ?? 0;
      final lon = position?.longitude ?? _localTrack.last['longitude'] ?? 0;

      // Добавляем финальную точку
      if (position != null) {
        _addLocalPoint(lat, lon);
      }

      await _firestore.endTrip(
        tripId: _activeTrip!.id,
        latitude: lat,
        longitude: lon,
        manualMileage: manualMileage,
        income: income,
      );

      _localTrack.clear();
      _localMileage = 0.0;
      _activeTrip = null;
      _tripStartTime = null;
      _elapsed = Duration.zero;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка при завершении рейса: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _startDurationTimer() {
    _elapsed = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tripStartTime != null) {
        _elapsed = DateTime.now().difference(_tripStartTime!);
        notifyListeners();
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  String get formattedDuration {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopDurationTimer();
    _positionSub?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
