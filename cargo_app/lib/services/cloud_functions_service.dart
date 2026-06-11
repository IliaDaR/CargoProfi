import '../models/trip.dart';
import '../models/expense.dart';
import '../utils/constants.dart';
import '../services/local_storage.dart';

/// Stub-сервис облачных функций (Firebase удалён, Yandex CF — через HTTP).
/// Все методы возвращают fallback на localStorage.
class CloudFunctionsService {
  final LocalStorage _local;

  CloudFunctionsService(this._local);

  // ===== РЕЙСЫ =====

  Future<String> startTrip({
    required String vehicleId, required double latitude, required double longitude,
    String? cargoDescription, String? routeDescription,
  }) async {
    return vehicleId;
  }

  Future<void> addTrackPoint({required String tripId, required double latitude, required double longitude}) async {}

  Future<void> addTrackPointsBatch({required String tripId, required List<Map<String, dynamic>> points}) async {}

  Future<Map<String, dynamic>> endTrip({
    required String tripId, required double latitude, required double longitude,
    double? manualMileage, double? income,
  }) async {
    return {'mileage': manualMileage ?? 0, 'mileageSource': 'manual'};
  }

  // ===== РАСХОДЫ =====

  Future<String> addExpense({
    required String tripId, required double amount, required String category,
    required double latitude, required double longitude,
    String? description,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _local.addExpense(Expense(
      id: id, tripId: tripId,
      driverId: _local.currentUser?['uid'] ?? 'local',
      amount: amount, category: expenseCategoryFromString(category),
      description: description, latitude: latitude, longitude: longitude,
      photoTimestamp: DateTime.now(), createdAt: DateTime.now(),
    ));
    return id;
  }

  // ===== РЕДАКТИРОВАНИЕ РЕЙСА =====

  Future<void> updateTrip({
    required String tripId,
    String? routeDescription, String? cargoDescription,
    double? income, double? mileage,
  }) async {}

  // ===== ПУТЕВОЙ ЛИСТ =====

  Future<String?> generateWaybill(String tripId) async => null;

  Future<Map<String, dynamic>?> signWaybill(String tripId) async => null;

  Future<Map<String, dynamic>?> validateInviteCode(String code) async => null;

  // ===== ЗАРПЛАТА =====

  Future<void> setSalaryRule({required String driverId, required String type, double? percentValue, double? fixedValue}) async {}

  Future<Map<String, dynamic>> calculateSalary({required String driverId, required String periodStart, required String periodEnd}) async => {};
}
