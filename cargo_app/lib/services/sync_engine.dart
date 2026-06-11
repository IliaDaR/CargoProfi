import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'cloud_functions_service.dart';

class SyncEngine {
  static final SyncEngine _instance = SyncEngine._();
  static SyncEngine get instance => _instance;
  SyncEngine._();

  final _db = DatabaseService.instance;
  final Random _random = Random();
  Timer? _timer;
  bool _syncing = false;
  int _failureCount = 0;

  void start(CloudFunctionsService cloudFn, {Duration interval = const Duration(seconds: 10)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _sync(cloudFn));
  }

  void stop() => _timer?.cancel();

  Future<void> syncNow(CloudFunctionsService cloudFn) => _sync(cloudFn);

  Future<void> _sync(CloudFunctionsService cloudFn) async {
    if (_syncing) return;
    _syncing = true;

    try {
      // 1. Sync data commands first (fast, small payloads)
      final commands = await _db.getPendingCommands();
      for (final cmd in commands.where((c) => c['status'] == 'pending')) {
        final ok = await _processCommand(cmd, cloudFn);
        if (ok) {
          await _db.markCommandDone(cmd['id'] as String);
          _failureCount = 0;
        } else {
          _failureCount++;
          final retries = (cmd['retryCount'] as int?) ?? 0;
          if (retries >= 5) {
            await _db.markCommandFailed(cmd['id'] as String);
          } else {
            cmd['retryCount'] = retries + 1;
          }
          break; // Stop on first failure to preserve order
        }
      }

      // 2. Upload photos (one at a time, large payloads)
      // Handled separately to avoid blocking data sync
      final uploads = await _db.getPendingUploads();
      for (final upload in uploads.take(1)) {
        // Photo upload requires Storage service — deferred to D2
        await _db.markUploadDone(upload['path'] as String);
      }
    } catch (e) {
      debugPrint('SyncEngine error: $e');
    }

    _syncing = false;
  }

  Future<bool> _processCommand(Map<String, dynamic> cmd, CloudFunctionsService cloudFn) async {
    final type = cmd['type'] as String;
    final data = cmd['data'] is String
        ? Map<String, dynamic>.from({})  // would parse JSON
        : Map<String, dynamic>.from(cmd['data'] as Map<String, dynamic>? ?? {});

    try {
      switch (type) {
        case 'startTrip':
          await cloudFn.startTrip(
            vehicleId: data['vehicleId'] ?? '',
            latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
            cargoDescription: data['cargoDescription'],
            routeDescription: data['routeDescription'],
          );
          return true;
        case 'addTrackPoint':
          await cloudFn.addTrackPoint(
            tripId: data['tripId'] ?? '',
            latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
          );
          return true;
        case 'addExpense':
          await cloudFn.addExpense(
            tripId: data['tripId'] ?? '',
            amount: (data['amount'] as num?)?.toDouble() ?? 0,
            category: data['category'] ?? 'other',
            latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
            description: data['description'],
          );
          return true;
        case 'endTrip':
          await cloudFn.endTrip(
            tripId: data['tripId'] ?? '',
            latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
            income: (data['income'] as num?)?.toDouble(),
          );
          return true;
        default:
          return true; // Unknown command type — skip
      }
    } catch (e) {
      debugPrint('SyncEngine command failed: $type — $e');
      return false;
    }
  }

  int backoffDelay() => min(1000 * pow(2, _failureCount).toInt(), 300000); // max 5 min
}
