import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../models/expense.dart';
import '../utils/constants.dart';
import '../services/local_storage.dart';

/// Сервис вызова Yandex Cloud Functions через HTTP.
/// При недоступности — fallback на localStorage.
class CloudFunctionsService {
  static const String _baseUrl = 'https://d5duqmvvsoilrgj91lbs.kr8f6hld.apigw.yandexcloud.net';
  final LocalStorage _local;

  CloudFunctionsService(this._local);

  Future<Map<String, dynamic>?> _call(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

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

  Future<void> updateTrip({
    required String tripId,
    String? routeDescription, String? cargoDescription,
    double? income, double? mileage,
  }) async {}

  // ===== ПУТЕВОЙ ЛИСТ =====

  Future<String?> generateWaybill(String tripId) async => null;
  Future<Map<String, dynamic>?> signWaybill(String tripId) async => null;

  // ===== ИНВАЙТ-КОДЫ =====

  Future<Map<String, dynamic>?> validateInviteCode(String code) async {
    return _call('validate_invite', {'code': code});
  }

  // ===== ЗАРПЛАТА =====

  Future<void> setSalaryRule({required String driverId, required String type, double? percentValue, double? fixedValue}) async {}
  Future<Map<String, dynamic>> calculateSalary({required String driverId, required String periodStart, required String periodEnd}) async => {};
}
