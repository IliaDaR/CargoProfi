import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip.dart';
import '../models/expense.dart';
import '../models/vehicle.dart';
import '../models/salary_rule.dart';
import '../models/salary_payment.dart';

/// Универсальный сервис для работы с Firestore, Storage и Cloud Functions.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ===== АВТОМОБИЛИ =====

  Future<List<Vehicle>> getVehicles(String ownerId) async {
    final snapshot = await _firestore
        .collection('vehicles')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final vehicles = snapshot.docs
        .map((doc) => Vehicle.fromMap(doc.id, doc.data()))
        .toList();

    // Определяем статус: проверяем активные рейсы для каждой машины
    for (int i = 0; i < vehicles.length; i++) {
      final activeTrips = await _firestore
          .collection('trips')
          .where('vehicleId', isEqualTo: vehicles[i].id)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (activeTrips.docs.isNotEmpty) {
        final tripData = activeTrips.docs.first.data();
        vehicles[i] = vehicles[i].copyWith(
          isActive: true,
          activeDriverId: tripData['driverId'],
        );
      }
    }

    return vehicles;
  }

  // ===== РЕЙСЫ =====

  /// Начать рейс через Cloud Function.
  Future<String> startTrip({
    required String vehicleId,
    required double latitude,
    required double longitude,
    String? cargoDescription,
    String? routeDescription,
  }) async {
    final result = await _functions.httpsCallable('startTrip').call({
      'vehicleId': vehicleId,
      'latitude': latitude,
      'longitude': longitude,
      if (cargoDescription != null) 'cargoDescription': cargoDescription,
      if (routeDescription != null) 'routeDescription': routeDescription,
    });

    return (result.data as Map<String, dynamic>)['tripId'];
  }

  /// Добавить GPS-точку к активному рейсу.
  Future<void> addTrackPoint({
    required String tripId,
    required double latitude,
    required double longitude,
  }) async {
    await _functions.httpsCallable('addTrackPoint').call({
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Добавить батч GPS-точек.
  Future<void> addTrackPointsBatch({
    required String tripId,
    required List<Map<String, dynamic>> points,
  }) async {
    await _functions.httpsCallable('addTrackPointsBatch').call({
      'tripId': tripId,
      'points': points,
    });
  }

  /// Завершить рейс.
  Future<Map<String, dynamic>> endTrip({
    required String tripId,
    required double latitude,
    required double longitude,
    double? manualMileage,
    double? income,
  }) async {
    final result = await _functions.httpsCallable('endTrip').call({
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
      if (manualMileage != null && manualMileage > 0)
        'manualMileage': manualMileage,
      if (income != null && income > 0) 'income': income,
    });

    return result.data as Map<String, dynamic>;
  }

  /// Получить активный рейс текущего водителя.
  Future<Trip?> getActiveTrip() async {
    final snapshot = await _firestore
        .collection('trips')
        .where('driverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return Trip.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
  }

  /// Поток активного рейса (real-time).
  Stream<Trip?> activeTripStream() {
    return _firestore
        .collection('trips')
        .where('driverId', isEqualTo: _uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Trip.fromMap(
        snapshot.docs.first.id,
        snapshot.docs.first.data(),
      );
    });
  }

  /// Получить рейсы водителя.
  Future<List<Trip>> getDriverTrips({int limit = 20}) async {
    final snapshot = await _firestore
        .collection('trips')
        .where('driverId', isEqualTo: _uid)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Trip.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Получить все рейсы (для owner — фильтруется правилами Firestore).
  Stream<List<Trip>> allTripsStream() {
    return _firestore
        .collection('trips')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Trip.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Получить рейсы для конкретного водителя (owner).
  Future<List<Trip>> getTripsByDriver(
    String driverId, {
    String? statusFilter,
  }) async {
    var query = _firestore
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .orderBy('startTime', descending: true);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Trip.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ===== РАСХОДЫ =====

  /// Добавить расход через Cloud Function.
  Future<String> addExpense({
    required String tripId,
    required double amount,
    required String category,
    double? latitude,
    double? longitude,
    String? description,
    String? receiptUrl,
  }) async {
    final result = await _functions.httpsCallable('addExpense').call({
      'tripId': tripId,
      'amount': amount,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      if (description != null) 'description': description,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
    });

    return (result.data as Map<String, dynamic>)['expenseId'];
  }

  /// Загрузить фото чека в Storage.
  Future<String> uploadReceipt(File file, String expenseId) async {
    final ref = _storage
        .ref()
        .child('receipts')
        .child(_uid)
        .child('$expenseId.jpg');

    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Получить расходы по рейсу.
  Future<List<Expense>> getTripExpenses(String tripId) async {
    final snapshot = await _firestore
        .collection('expenses')
        .where('tripId', isEqualTo: tripId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Expense.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Сводка расходов (owner).
  Future<List<Expense>> getDriverExpenses({
    required String driverId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await _functions
        .httpsCallable('getDriverExpensesReport')
        .call({
      'driverId': driverId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    });

    final data = result.data as Map<String, dynamic>;
    final expensesList = data['expenses'] as List<dynamic>? ?? [];

    return expensesList.map((e) {
      final map = e as Map<String, dynamic>;
      final id = map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      return Expense.fromMap(id, map);
    }).toList();
  }

  // ===== ЗАРПЛАТА =====

  /// Задать правило зарплаты.
  Future<void> setSalaryRule({
    required String driverId,
    required String type, // 'percent' или 'fixed'
    double? percentValue,
    double? fixedValue,
  }) async {
    await _functions.httpsCallable('setSalaryRule').call({
      'driverId': driverId,
      'type': type,
      if (percentValue != null) 'percentValue': percentValue,
      if (fixedValue != null) 'fixedValue': fixedValue,
    });
  }

  /// Получить активное правило зарплаты для водителя.
  Future<SalaryRule?> getSalaryRule(String driverId) async {
    final result = await _functions.httpsCallable('getSalaryRule').call({
      'driverId': driverId,
    });

    final data = result.data as Map<String, dynamic>;
    final ruleData = data['rule'];

    if (ruleData == null) return null;

    return SalaryRule.fromMap(
      ruleData['id'] ?? '',
      ruleData as Map<String, dynamic>,
    );
  }

  /// Рассчитать зарплату за период.
  Future<SalaryPayment> calculateSalary({
    required String driverId,
    required String periodStart, // 'YYYY-MM-DD'
    required String periodEnd,
  }) async {
    final result = await _functions.httpsCallable('calculateSalary').call({
      'driverId': driverId,
      'periodStart': periodStart,
      'periodEnd': periodEnd,
    });

    final data = result.data as Map<String, dynamic>;
    return SalaryPayment.fromMap(data['paymentId'] ?? '', data);
  }

  /// История расчётов зарплаты.
  Future<List<SalaryPayment>> getSalaryHistory(String driverId) async {
    final result = await _functions.httpsCallable('getSalaryHistory').call({
      'driverId': driverId,
    });

    final data = result.data as Map<String, dynamic>;
    final paymentsList = data['payments'] as List<dynamic>? ?? [];

    return paymentsList.map((p) {
      final map = p as Map<String, dynamic>;
      return SalaryPayment.fromMap(
        map['id'] ?? '',
        map,
      );
    }).toList();
  }

  // ===== ПУТЕВОЙ ЛИСТ =====

  /// Сформировать PDF путевого листа.
  Future<String> generateWaybill(String tripId) async {
    final result = await _functions.httpsCallable('generateWaybill').call({
      'tripId': tripId,
    });

    return (result.data as Map<String, dynamic>)['waybillUrl'];
  }

  // ===== ВОДИТЕЛИ (для owner) =====

  /// Получить список водителей владельца.
  Future<List<Map<String, dynamic>>> getDrivers(String ownerId) async {
    final snapshot = await _firestore
        .collection('drivers')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    return snapshot.docs.map((doc) => {
      'uid': doc.id,
      ...doc.data(),
    }).toList();
  }
}
