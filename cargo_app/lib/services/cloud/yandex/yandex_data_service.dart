import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../cloud_interfaces.dart';
import '../cloud_config.dart';
import '../../../models/trip.dart';
import '../../../models/expense.dart';
import '../../../models/salary_rule.dart';

class YandexDataService implements ICloudData {
  String get _base => CloudConfig.yandexFunctionUrl;

  Future<Map<String, dynamic>> _query(String collection, Map<String, dynamic> params) async {
    final resp = await http.post(
      Uri.parse('$_base?endpoint=data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'collection': collection, ...params}),
    );
    if (resp.statusCode >= 400) throw Exception('Data error: ${resp.body}');
    return jsonDecode(resp.body);
  }

  @override
  Future<void> addVehicle(Map<String, dynamic> vehicle) async => await _query('vehicles', {'action': 'add', 'data': vehicle});

  @override
  Future<void> addTrip(Trip trip) async => await _query('trips', {'action': 'add', 'data': _tripToJson(trip)});

  @override
  Future<void> updateTrip(Trip trip) async => await _query('trips', {'action': 'update', 'data': _tripToJson(trip)});

  @override
  Future<void> addExpense(Expense expense) async => await _query('expenses', {'action': 'add', 'data': _expenseToJson(expense)});

  @override
  Future<void> addDriver(Map<String, dynamic> driver) async => await _query('drivers', {'action': 'add', 'data': driver});

  @override
  Future<void> addSalaryRule(SalaryRule rule) async => await _query('salaryRules', {'action': 'add', 'data': _ruleToJson(rule)});

  @override
  Future<void> addSalaryPayment(Map<String, dynamic> payment) async => await _query('salaryPayments', {'action': 'add', 'data': payment});

  @override
  Future<void> removeVehicle(String id) async => await _query('vehicles', {'action': 'remove', 'id': id});

  @override
  Future<void> removeDriver(String uid) async => await _query('drivers', {'action': 'remove', 'id': uid});

  @override
  Future<List<Map<String, dynamic>>> fetchVehicles(String ownerId) async {
    final r = await _query('vehicles', {'action': 'list', 'ownerId': ownerId});
    return (r['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  @override
  Future<List<Trip>> fetchTrips(String ownerId) async {
    final r = await _query('trips', {'action': 'list', 'ownerId': ownerId});
    final items = (r['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return items.map((e) => Trip.fromMap(e['id'] ?? '', e)).toList();
  }

  @override
  Future<List<Expense>> fetchExpensesByTrip(String tripId) async {
    final r = await _query('expenses', {'action': 'list', 'tripId': tripId});
    final items = (r['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return items.map((e) => Expense.fromMap(e['id'] ?? '', e)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDrivers(String ownerId) async {
    final r = await _query('drivers', {'action': 'list', 'ownerId': ownerId});
    return (r['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  @override
  Future<List<SalaryRule>> fetchSalaryRules(String ownerId) async {
    final r = await _query('salaryRules', {'action': 'list', 'ownerId': ownerId});
    final items = (r['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return items.map((s) => SalaryRule.fromMap(s['id'] ?? '', s)).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> vehiclesStream(String ownerId) => Stream.empty();

  @override
  Stream<List<Trip>> tripsStream(String ownerId) => Stream.empty();

  Map<String, dynamic> _tripToJson(Trip t) => {
    'id': t.id, 'driverId': t.driverId, 'vehicleId': t.vehicleId,
    'status': t.status.name, 'startTime': t.startTime.toIso8601String(),
    'startLatitude': t.startLatitude, 'startLongitude': t.startLongitude,
    'endTime': t.endTime?.toIso8601String(), 'endLatitude': t.endLatitude, 'endLongitude': t.endLongitude,
    'mileage': t.mileage, 'mileageSource': t.mileageSource.name, 'income': t.income,
    'routeDescription': t.routeDescription, 'cargoDescription': t.cargoDescription,
    'waybillUrl': t.waybillUrl, 'waybillUuid': t.waybillUuid,
  };

  Map<String, dynamic> _expenseToJson(Expense e) => {
    'id': e.id, 'tripId': e.tripId, 'driverId': e.driverId,
    'amount': e.amount, 'category': e.category.name,
    'description': e.description, 'receiptUrl': e.receiptUrl,
    'latitude': e.latitude, 'longitude': e.longitude,
    'photoTimestamp': e.photoTimestamp.toIso8601String(), 'createdAt': e.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _ruleToJson(SalaryRule r) => {
    'id': r.id, 'ownerId': r.ownerId, 'driverId': r.driverId,
    'type': r.type.name, 'percentValue': r.percentValue, 'fixedValue': r.fixedValue,
    'isActive': r.isActive, 'createdAt': r.createdAt.toIso8601String(),
  };
}
