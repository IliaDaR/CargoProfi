import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Сервис GPS-трекинга. Используется водителем во время активного рейса.
class LocationService {
  Timer? _trackingTimer;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;
  bool isTracking = false;

  /// Запрашивает разрешение на геолокацию.
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Проверяет, включён ли GPS.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Получает текущие координаты однократно.
  Future<Position> getCurrentPosition() async {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Запускает периодическое отслеживание позиции (по умолчанию раз в 30 сек).
  /// В реальном приложении используется раз в 60 сек для экономии.
  void startTracking({Duration interval = const Duration(seconds: 30)}) {
    if (isTracking) return;
    isTracking = true;

    _trackingTimer = Timer.periodic(interval, (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _positionController.add(position);
      } catch (_) {
        // Игнорируем ошибки GPS, чтобы не прерывать трекинг
      }
    });
  }

  /// Останавливает отслеживание.
  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    isTracking = false;
  }

  /// Освобождает ресурсы.
  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
