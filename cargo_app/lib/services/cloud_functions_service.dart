import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../models/trip.dart';
import '../models/expense.dart';
import '../utils/constants.dart';
import '../services/local_storage.dart';

/// Сервис вызова Cloud Functions.
/// При недоступности Firebase — fallback на LocalStorage.
class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final LocalStorage _local;
  bool _useLocal = false;
  DateTime _lastRetry = DateTime.now().subtract(const Duration(minutes: 5));

  CloudFunctionsService(this._local);

  Future<bool> _tryCloud() async {
    if (!_useLocal) return true;
    if (DateTime.now().difference(_lastRetry).inSeconds < 30) return false;
    _lastRetry = DateTime.now();
    try {
      await FirebaseFirestore.instance.collection('owners').doc('_ping_').get().timeout(const Duration(seconds: 5));
      _useLocal = false;
      return true;
    } catch (_) {
      _useLocal = true;
      return false;
    }
  }

  // ===== РЕЙСЫ =====

  Future<String> startTrip({
    required String vehicleId, required double latitude, required double longitude,
    String? cargoDescription, String? routeDescription,
  }) async {
    if (await _tryCloud()) {
      try {
        final result = await _functions.httpsCallable('startTrip').call({
          'vehicleId': vehicleId, 'latitude': latitude, 'longitude': longitude,
          if (cargoDescription != null) 'cargoDescription': cargoDescription,
          if (routeDescription != null) 'routeDescription': routeDescription,
        });
        return (result.data as Map)['tripId'] ?? '';
      } catch (_) { _useLocal = true; }
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _local.addTrip(Trip(id: id, driverId: _local.currentUser?['uid'] ?? 'local', vehicleId: vehicleId, status: TripStatus.active, startTime: DateTime.now(), startLatitude: latitude, startLongitude: longitude, cargoDescription: cargoDescription, routeDescription: routeDescription, mileage: 0, mileageSource: MileageSource.auto, createdAt: DateTime.now()));
    return id;
  }

  Future<void> addTrackPoint({required String tripId, required double latitude, required double longitude}) async {
    if (await _tryCloud()) {
      try {
        await _functions.httpsCallable('addTrackPoint').call({'tripId': tripId, 'latitude': latitude, 'longitude': longitude});
      } catch (_) { _useLocal = true; }
    }
  }

  Future<void> addTrackPointsBatch({required String tripId, required List<Map<String, dynamic>> points}) async {
    if (await _tryCloud()) {
      try {
        await _functions.httpsCallable('addTrackPointsBatch').call({'tripId': tripId, 'points': points});
      } catch (_) { _useLocal = true; }
    }
  }

  Future<Map<String, dynamic>> endTrip({
    required String tripId, required double latitude, required double longitude,
    double? manualMileage, double? income,
  }) async {
    if (await _tryCloud()) {
      try {
        final result = await _functions.httpsCallable('endTrip').call({
          'tripId': tripId, 'latitude': latitude, 'longitude': longitude,
          if (manualMileage != null) 'manualMileage': manualMileage,
          if (income != null) 'income': income,
        });
        return result.data as Map<String, dynamic>;
      } catch (_) { _useLocal = true; }
    }
    return {'mileage': manualMileage ?? 0, 'mileageSource': 'manual'};
  }

  // ===== РАСХОДЫ =====

  Future<String> addExpense({
    required String tripId, required double amount, required String category,
    required double latitude, required double longitude,
    String? description, File? receiptFile,
  }) async {
    String? receiptUrl;
    // Firebase Storage для фото (если доступен)
    if (receiptFile != null && await _tryCloud()) {
      try {
        final ref = _storage.ref().child('receipts/${_local.currentUser?['uid'] ?? 'user'}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(receiptFile);
        receiptUrl = await ref.getDownloadURL();
      } catch (_) { _useLocal = true; }
    }

    if (await _tryCloud()) {
      try {
        final result = await _functions.httpsCallable('addExpense').call({
          'tripId': tripId, 'amount': amount, 'category': category,
          'latitude': latitude, 'longitude': longitude,
          if (description != null) 'description': description,
          if (receiptUrl != null) 'receiptUrl': receiptUrl,
        });
        return (result.data as Map)['expenseId'] ?? '';
      } catch (_) { _useLocal = true; }
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _local.addExpense(Expense(id: id, tripId: tripId, driverId: _local.currentUser?['uid'] ?? 'local', amount: amount, category: expenseCategoryFromString(category), description: description, latitude: latitude, longitude: longitude, photoTimestamp: DateTime.now(), createdAt: DateTime.now(), receiptUrl: receiptUrl));
    return id;
  }

  // ===== ПУТЕВОЙ ЛИСТ =====

  Future<String?> generateWaybill(String tripId) async {
    if (await _tryCloud()) {
      try {
        final result = await _functions.httpsCallable('generateWaybill').call({'tripId': tripId});
        return (result.data as Map)['waybillUrl'];
      } catch (_) { _useLocal = true; }
    }
    return null;
  }

  // ===== ЗАРПЛАТА =====

  Future<void> setSalaryRule({required String driverId, required String type, double? percentValue, double? fixedValue}) async {
    if (await _tryCloud()) {
      try {
        await _functions.httpsCallable('setSalaryRule').call({'driverId': driverId, 'type': type, if (percentValue != null) 'percentValue': percentValue, if (fixedValue != null) 'fixedValue': fixedValue});
      } catch (_) { _useLocal = true; }
    }
  }

  Future<Map<String, dynamic>> calculateSalary({required String driverId, required String periodStart, required String periodEnd}) async {
    if (await _tryCloud()) {
      try {
        final result = await _functions.httpsCallable('calculateSalary').call({'driverId': driverId, 'periodStart': periodStart, 'periodEnd': periodEnd});
        return result.data as Map<String, dynamic>;
      } catch (_) { _useLocal = true; }
    }
    return {};
  }
}
