import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../cloud_interfaces.dart';
import '../cloud_config.dart';

class YandexFunctionsService implements ICloudFunctions {
  String get _base => CloudConfig.yandexFunctionUrl;

  Future<Map<String, dynamic>> _call(String function, Map<String, dynamic> data) async {
    final resp = await http.post(
      Uri.parse('$_base?endpoint=$function'),
      headers: {'Content-Type': 'application/json', 'X-API-Key': CloudConfig.yandexApiKey},
      body: jsonEncode(data),
    );
    if (resp.statusCode >= 400) throw Exception('Function error: ${resp.body}');
    return jsonDecode(resp.body);
  }

  @override
  Future<String> startTrip({required String vehicleId, required double latitude, required double longitude, String? cargoDescription, String? routeDescription}) async {
    final r = await _call('startTrip', {'vehicleId': vehicleId, 'latitude': latitude, 'longitude': longitude, if (cargoDescription != null) 'cargoDescription': cargoDescription, if (routeDescription != null) 'routeDescription': routeDescription});
    return r['tripId'] ?? '';
  }

  @override
  Future<void> addTrackPoint({required String tripId, required double latitude, required double longitude}) async {
    await _call('addTrackPoint', {'tripId': tripId, 'latitude': latitude, 'longitude': longitude});
  }

  @override
  Future<void> addTrackPointsBatch({required String tripId, required List<Map<String, dynamic>> points}) async {
    await _call('addTrackPointsBatch', {'tripId': tripId, 'points': points});
  }

  @override
  Future<Map<String, dynamic>> endTrip({required String tripId, required double latitude, required double longitude, double? manualMileage, double? income}) async {
    return await _call('endTrip', {'tripId': tripId, 'latitude': latitude, 'longitude': longitude, if (manualMileage != null) 'manualMileage': manualMileage, if (income != null) 'income': income});
  }

  @override
  Future<void> updateTrip({required String tripId, String? routeDescription, String? cargoDescription, double? income, double? mileage}) async {
    await _call('updateTrip', {'tripId': tripId, if (routeDescription != null) 'routeDescription': routeDescription, if (cargoDescription != null) 'cargoDescription': cargoDescription, if (income != null) 'income': income, if (mileage != null) 'mileage': mileage});
  }

  @override
  Future<String> addExpense({required String tripId, required double amount, required String category, required double latitude, required double longitude, String? description, Uint8List? receiptBytes}) async {
    String? receiptUrl;
    if (receiptBytes != null) {
      receiptUrl = 'data:image/jpeg;base64,${base64Encode(receiptBytes)}';
    }
    final r = await _call('addExpense', {'tripId': tripId, 'amount': amount, 'category': category, 'latitude': latitude, 'longitude': longitude, if (description != null) 'description': description, if (receiptUrl != null) 'receiptUrl': receiptUrl});
    return r['expenseId'] ?? '';
  }

  @override
  Future<String?> generateWaybill(String tripId) async {
    final r = await _call('generateWaybill', {'tripId': tripId});
    return r['waybillUrl'];
  }

  @override
  Future<Map<String, dynamic>?> signWaybill(String tripId) async {
    final r = await _call('signWaybill', {'tripId': tripId});
    return r;
  }

  @override
  Future<void> setSalaryRule({required String driverId, required String type, double? percentValue, double? fixedValue}) async {
    await _call('setSalaryRule', {'driverId': driverId, 'type': type, if (percentValue != null) 'percentValue': percentValue, if (fixedValue != null) 'fixedValue': fixedValue});
  }

  @override
  Future<Map<String, dynamic>> calculateSalary({required String driverId, required String periodStart, required String periodEnd}) async {
    return await _call('calculateSalary', {'driverId': driverId, 'periodStart': periodStart, 'periodEnd': periodEnd});
  }
}
