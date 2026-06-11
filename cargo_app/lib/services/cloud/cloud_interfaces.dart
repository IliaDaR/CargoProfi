import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../models/trip.dart';
import '../../models/expense.dart';
import '../../models/salary_rule.dart';

abstract class ICloudAuth {
  Future<Map<String, dynamic>?> register(String email, String password, String name);
  Future<Map<String, dynamic>?> login(String email, String password);
  Future<void> signOut();
  Map<String, dynamic>? get currentUser;
  Stream<Map<String, dynamic>?> get authStateChanges;
}

abstract class ICloudData {
  Future<void> addVehicle(Map<String, dynamic> vehicle);
  Future<void> addTrip(Trip trip);
  Future<void> updateTrip(Trip trip);
  Future<void> addExpense(Expense expense);
  Future<void> addDriver(Map<String, dynamic> driver);
  Future<void> addSalaryRule(SalaryRule rule);
  Future<void> addSalaryPayment(Map<String, dynamic> payment);
  Future<void> removeVehicle(String id);
  Future<void> removeDriver(String uid);
  Future<List<Map<String, dynamic>>> fetchVehicles(String ownerId);
  Future<List<Trip>> fetchTrips(String ownerId);
  Future<List<Expense>> fetchExpensesByTrip(String tripId);
  Future<List<Map<String, dynamic>>> fetchDrivers(String ownerId);
  Future<List<SalaryRule>> fetchSalaryRules(String ownerId);
  Stream<List<Map<String, dynamic>>> vehiclesStream(String ownerId);
  Stream<List<Trip>> tripsStream(String ownerId);
}

abstract class ICloudStorage {
  Future<String?> uploadBytes(Uint8List bytes, String path, String contentType);
  Future<Uint8List?> downloadBytes(String path);
  Future<void> deleteFile(String path);
  Future<String> getPublicUrl(String path);
}

abstract class ICloudFunctions {
  Future<String> startTrip({required String vehicleId, required double latitude, required double longitude, String? cargoDescription, String? routeDescription});
  Future<void> addTrackPoint({required String tripId, required double latitude, required double longitude});
  Future<void> addTrackPointsBatch({required String tripId, required List<Map<String, dynamic>> points});
  Future<Map<String, dynamic>> endTrip({required String tripId, required double latitude, required double longitude, double? manualMileage, double? income});
  Future<void> updateTrip({required String tripId, String? routeDescription, String? cargoDescription, double? income, double? mileage});
  Future<String> addExpense({required String tripId, required double amount, required String category, required double latitude, required double longitude, String? description, Uint8List? receiptBytes});
  Future<String?> generateWaybill(String tripId);
  Future<Map<String, dynamic>?> signWaybill(String tripId);
  Future<void> setSalaryRule({required String driverId, required String type, double? percentValue, double? fixedValue});
  Future<Map<String, dynamic>> calculateSalary({required String driverId, required String periodStart, required String periodEnd});
}
