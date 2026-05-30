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

class FirestoreService {
  FirebaseFirestore? _fs;
  FirebaseFunctions? _fn;
  FirebaseStorage? _st;
  FirebaseAuth? _au;

  FirebaseFirestore get db => _fs ??= FirebaseFirestore.instance;
  FirebaseFunctions get fn => _fn ??= FirebaseFunctions.instance;
  FirebaseStorage get st => _st ??= FirebaseStorage.instance;
  FirebaseAuth get au => _au ??= FirebaseAuth.instance;

  String get uid {
    try { return au.currentUser!.uid; } catch (_) { return ''; }
  }

  // ===== АВТОМОБИЛИ =====

  Future<List<Vehicle>> getVehicles(String ownerId) async {
    final snapshot = await db
        .collection('vehicles')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final vehicles = snapshot.docs
        .map((doc) => Vehicle.fromMap(doc.id, doc.data()))
        .toList();

    for (int i = 0; i < vehicles.length; i++) {
      final activeTrips = await db
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

  Future<String> startTrip({
    required String vehicleId,
    required double latitude,
    required double longitude,
    String? cargoDescription,
    String? routeDescription,
  }) async {
    final result = await fn.httpsCallable('startTrip').call({
      'vehicleId': vehicleId,
      'latitude': latitude,
      'longitude': longitude,
      if (cargoDescription != null) 'cargoDescription': cargoDescription,
      if (routeDescription != null) 'routeDescription': routeDescription,
    });

    return (result.data as Map<String, dynamic>)['tripId'];
  }

  Future<void> addTrackPoint({
    required String tripId,
    required double latitude,
    required double longitude,
  }) async {
    await fn.httpsCallable('addTrackPoint').call({
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<void> addTrackPointsBatch({
    required String tripId,
    required List<Map<String, dynamic>> points,
  }) async {
    await fn.httpsCallable('addTrackPointsBatch').call({
      'tripId': tripId,
      'points': points,
    });
  }

  Future<Map<String, dynamic>> endTrip({
    required String tripId,
    required double latitude,
    required double longitude,
    double? manualMileage,
    double? income,
  }) async {
    final result = await fn.httpsCallable('endTrip').call({
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
      if (manualMileage != null && manualMileage > 0)
        'manualMileage': manualMileage,
      if (income != null && income > 0) 'income': income,
    });

    return result.data as Map<String, dynamic>;
  }

  Future<Trip?> getActiveTrip() async {
    final snapshot = await db
        .collection('trips')
        .where('driverId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return Trip.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
  }

  Stream<Trip?> activeTripStream() {
    return db
        .collection('trips')
        .where('driverId', isEqualTo: uid)
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

  Future<List<Trip>> getDriverTrips({int limit = 20}) async {
    final snapshot = await db
        .collection('trips')
        .where('driverId', isEqualTo: uid)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Trip.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Trip>> allTripsStream() {
    return db
        .collection('trips')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Trip.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<List<Trip>> getTripsByDriver(
    String driverId, {
    String? statusFilter,
  }) async {
    var query = db
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

  Future<String> addExpense({
    required String tripId,
    required double amount,
    required String category,
    double? latitude,
    double? longitude,
    String? description,
    String? receiptUrl,
  }) async {
    final result = await fn.httpsCallable('addExpense').call({
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

  Future<String> uploadReceipt(File file, String expenseId) async {
    final ref = st
        .ref()
        .child('receipts')
        .child(uid)
        .child('$expenseId.jpg');

    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<List<Expense>> getTripExpenses(String tripId) async {
    final snapshot = await db
        .collection('expenses')
        .where('tripId', isEqualTo: tripId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Expense.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<Expense>> getDriverExpenses({
    required String driverId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await fn
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

  Future<void> setSalaryRule({
    required String driverId,
    required String type,
    double? percentValue,
    double? fixedValue,
  }) async {
    await fn.httpsCallable('setSalaryRule').call({
      'driverId': driverId,
      'type': type,
      if (percentValue != null) 'percentValue': percentValue,
      if (fixedValue != null) 'fixedValue': fixedValue,
    });
  }

  Future<SalaryRule?> getSalaryRule(String driverId) async {
    final result = await fn.httpsCallable('getSalaryRule').call({
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

  Future<SalaryPayment> calculateSalary({
    required String driverId,
    required String periodStart,
    required String periodEnd,
  }) async {
    final result = await fn.httpsCallable('calculateSalary').call({
      'driverId': driverId,
      'periodStart': periodStart,
      'periodEnd': periodEnd,
    });

    final data = result.data as Map<String, dynamic>;
    return SalaryPayment.fromMap(data['paymentId'] ?? '', data);
  }

  Future<List<SalaryPayment>> getSalaryHistory(String driverId) async {
    final result = await fn.httpsCallable('getSalaryHistory').call({
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

  Future<String> generateWaybill(String tripId) async {
    final result = await fn.httpsCallable('generateWaybill').call({
      'tripId': tripId,
    });

    return (result.data as Map<String, dynamic>)['waybillUrl'];
  }

  // ===== ВОДИТЕЛИ (для owner) =====

  Future<List<Map<String, dynamic>>> getDrivers(String ownerId) async {
    final snapshot = await db
        .collection('drivers')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    return snapshot.docs.map((doc) => {
      'uid': doc.id,
      ...doc.data(),
    }).toList();
  }
}
