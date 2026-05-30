import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../models/expense.dart';
import '../models/vehicle.dart';
import '../models/salary_rule.dart';
import '../models/salary_payment.dart';
import '../models/user_profile.dart';
import '../models/demo_data.dart';

/// Локальное хранилище — всё сохраняется на устройстве без облака.
class LocalStorage {
  static const _kVehicles = 'vehicles';
  static const _kTrips = 'trips';
  static const _kExpenses = 'expenses';
  static const _kDrivers = 'drivers';
  static const _kSalaryRules = 'salary_rules';
  static const _kSalaryPayments = 'salary_payments';
  static const _kUsers = 'users';
  static const _kCurrentUser = 'current_user';

  SharedPreferences? _prefs;
  bool _initialized = false;

  // In-memory cache
  final List<Vehicle> vehicles = [];
  final List<Trip> trips = [];
  final List<Expense> expenses = [];
  final List<Map<String, dynamic>> drivers = [];
  final List<SalaryRule> salaryRules = [];
  final List<SalaryPayment> salaryPayments = [];
  final List<Map<String, dynamic>> users = [];
  Map<String, dynamic>? currentUser;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_initialized) _seedIfEmpty();
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  /// При первом запуске заполняем демо-данными.
  void _seedIfEmpty() {
    if (_prefs!.getString(_kVehicles) == null) {
      _saveVehicles(DemoData.vehicles);
      _saveTrips(DemoData.trips);
      _saveExpenses(DemoData.expenses);
      _saveDrivers(DemoData.drivers);
      _saveSalaryRules(DemoData.salaryRules);
      _saveSalaryPayments(DemoData.salaryPayments);
      // Дефолтный админ
      users.add({'uid': 'admin', 'email': 'admin@numino.ru', 'password': 'admin123', 'displayName': 'Администратор', 'role': 'owner', 'phone': '+79183951315'});
      _prefs!.setString(_kUsers, jsonEncode(users));
    } else {
      _loadAll();
    }
  }

  void _loadAll() {
    vehicles.clear();
    vehicles.addAll(_loadVehicles());
    trips.clear();
    trips.addAll(_loadTrips());
    expenses.clear();
    expenses.addAll(_loadExpenses());
    drivers.clear();
    drivers.addAll(_loadDrivers());
    salaryRules.clear();
    salaryRules.addAll(_loadSalaryRules());
    salaryPayments.clear();
    salaryPayments.addAll(_loadSalaryPayments());
    final u = _prefs!.getString(_kUsers);
    if (u != null) { users.clear(); users.addAll(List<Map<String, dynamic>>.from(jsonDecode(u))); }
  }

  // ===== Auth =====
  Map<String, dynamic>? findUser(String email, String password) {
    try {
      return users.where((u) => u['email'] == email && u['password'] == password).firstOrNull;
    } catch (_) { return null; }
  }

  Map<String, dynamic>? registerUser(String email, String password, String name, String role) {
    if (users.any((u) => u['email'] == email)) return null;
    final user = {'uid': DateTime.now().millisecondsSinceEpoch.toString(), 'email': email, 'password': password, 'displayName': name, 'role': role};
    users.add(user);
    _prefs!.setString(_kUsers, jsonEncode(users));
    return user;
  }

  void setCurrentUser(Map<String, dynamic>? user) {
    currentUser = user;
    if (user != null) _prefs!.setString(_kCurrentUser, jsonEncode(user));
  }

  Map<String, dynamic>? loadCurrentUser() {
    final s = _prefs!.getString(_kCurrentUser);
    if (s != null) return Map<String, dynamic>.from(jsonDecode(s));
    return null;
  }

  // ===== CRUD =====

  void _saveVehicles(List<Vehicle> list) => _prefs!.setString(_kVehicles, jsonEncode(list.map((v) => _vehicleToMap(v)).toList()));
  void _saveTrips(List<Trip> list) => _prefs!.setString(_kTrips, jsonEncode(list.map((t) => _tripToMap(t)).toList()));
  void _saveExpenses(List<Expense> list) => _prefs!.setString(_kExpenses, jsonEncode(list.map((e) => _expenseToMap(e)).toList()));
  void _saveDrivers(List<Map<String,dynamic>> list) => _prefs!.setString(_kDrivers, jsonEncode(list));
  void _saveSalaryRules(List<SalaryRule> list) => _prefs!.setString(_kSalaryRules, jsonEncode(list.map((r) => _ruleToMap(r)).toList()));
  void _saveSalaryPayments(List<SalaryPayment> list) => _prefs!.setString(_kSalaryPayments, jsonEncode(list.map((p) => _paymentToMap(p)).toList()));

  void addVehicle(Vehicle v) { vehicles.add(v); _saveVehicles(vehicles); }
  void addTrip(Trip t) { trips.add(t); _saveTrips(trips); }
  void addExpense(Expense e) { expenses.add(e); _saveExpenses(expenses); }
  void addDriver(Map<String,dynamic> d) { drivers.add(d); _saveDrivers(drivers); }
  void addSalaryRule(SalaryRule r) { salaryRules.add(r); _saveSalaryRules(salaryRules); }
  void addSalaryPayment(SalaryPayment p) { salaryPayments.add(p); _saveSalaryPayments(salaryPayments); }

  List<Vehicle> _loadVehicles() => _load(_kVehicles).map((m) => Vehicle.fromMap(m['id'], m)).toList();
  List<Trip> _loadTrips() => _load(_kTrips).map((m) => Trip.fromMap(m['id'], m)).toList();
  List<Expense> _loadExpenses() => _load(_kExpenses).map((m) => Expense.fromMap(m['id'], m)).toList();
  List<Map<String,dynamic>> _loadDrivers() => _load(_kDrivers).cast<Map<String,dynamic>>();
  List<SalaryRule> _loadSalaryRules() => _load(_kSalaryRules).map((m) => SalaryRule.fromMap(m['id'], m)).toList();
  List<SalaryPayment> _loadSalaryPayments() => _load(_kSalaryPayments).map((m) => SalaryPayment.fromMap(m['id'], m)).toList();

  List<dynamic> _load(String key) {
    final s = _prefs!.getString(key);
    return s != null ? jsonDecode(s) as List<dynamic> : [];
  }

  // ===== Сериализация =====

  Map<String,dynamic> _vehicleToMap(Vehicle v) => {
    'id': v.id, 'ownerId': v.ownerId, 'plateNumber': v.plateNumber, 'brand': v.brand, 'model': v.model,
    'year': v.year, 'vin': v.vin, 'fuelType': v.fuelType, 'createdAt': v.createdAt.toIso8601String(),
    'isActive': v.isActive, 'activeDriverId': v.activeDriverId,
  };

  Map<String,dynamic> _tripToMap(Trip t) => {
    'id': t.id, 'driverId': t.driverId, 'vehicleId': t.vehicleId, 'status': t.status.name,
    'startTime': t.startTime.toIso8601String(), 'startLocation': {'latitude': t.startLatitude, 'longitude': t.startLongitude},
    'endTime': t.endTime?.toIso8601String(), 'endLocation': t.endLatitude != null ? {'latitude': t.endLatitude, 'longitude': t.endLongitude} : null,
    'mileage': t.mileage, 'mileageSource': t.mileageSource.name, 'manualMileage': t.manualMileage,
    'cargoDescription': t.cargoDescription, 'routeDescription': t.routeDescription, 'income': t.income,
    'createdAt': t.createdAt.toIso8601String(), 'track': [],
  };

  Map<String,dynamic> _expenseToMap(Expense e) => {
    'id': e.id, 'tripId': e.tripId, 'driverId': e.driverId, 'amount': e.amount, 'category': e.category.name,
    'description': e.description, 'location': {'latitude': e.latitude, 'longitude': e.longitude},
    'photoTimestamp': e.photoTimestamp.toIso8601String(), 'createdAt': e.createdAt.toIso8601String(),
    'receiptUrl': e.receiptUrl,
  };

  Map<String,dynamic> _ruleToMap(SalaryRule r) => {
    'id': r.id, 'ownerId': r.ownerId, 'driverId': r.driverId, 'type': r.type.name,
    'percentValue': r.percentValue, 'fixedValue': r.fixedValue, 'isActive': r.isActive,
    'createdAt': r.createdAt.toIso8601String(),
  };

  Map<String,dynamic> _paymentToMap(SalaryPayment p) => {
    'id': p.id, 'ownerId': p.ownerId, 'driverId': p.driverId,
    'periodStart': p.periodStart.toIso8601String(), 'periodEnd': p.periodEnd.toIso8601String(),
    'tripIds': p.tripIds, 'totalIncome': p.totalIncome, 'calculatedSalary': p.calculatedSalary,
    'ruleType': p.ruleType.name, 'ruleValue': p.ruleValue, 'status': p.status.name,
    'createdAt': p.createdAt.toIso8601String(), 'paidAt': p.paidAt?.toIso8601String(),
  };
}
