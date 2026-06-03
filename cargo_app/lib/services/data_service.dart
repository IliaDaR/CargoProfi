import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_storage.dart';
import '../models/trip.dart';
import '../models/expense.dart';
import '../models/vehicle.dart';
import '../models/salary_rule.dart';
import '../models/salary_payment.dart';

/// Универсальный сервис данных: Firestore (основной) + LocalStorage (fallback).
class DataService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorage _local;
  bool _useLocal = false;

  DataService(this._local);

  String get _uid => _auth.currentUser?.uid ?? 'local';

  /// Проверяет доступность Firestore, при ошибке переключается на локальное хранилище.
  Future<void> _ensureConnected() async {
    if (_useLocal) return;
    try {
      await _fs.collection('owners').doc('_ping_').get().timeout(const Duration(seconds: 5));
    } catch (_) {
      _useLocal = true;
    }
  }

  // ===== АВТО =====

  List<Vehicle> get vehicles => _local.vehicles;

  Future<void> addVehicle(Vehicle v) async {
    _local.addVehicle(v);
    await _ensureConnected();
    if (!_useLocal) {
      await _fs.collection('vehicles').doc(v.id).set({
        'ownerId': _uid, 'plateNumber': v.plateNumber, 'brand': v.brand, 'model': v.model,
        'year': v.year, 'vin': v.vin, 'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void removeVehicle(int index) => _local.removeVehicle(index);

  // ===== ВОДИТЕЛИ =====

  List<Map<String, dynamic>> get drivers => _local.drivers;

  void addDriver(Map<String, dynamic> d) {
    _local.addDriver(d);
  }

  void removeDriver(int index) => _local.removeDriver(index);

  // ===== РЕЙСЫ =====

  List<Trip> get trips => _local.trips;

  void addTrip(Trip t) => _local.addTrip(t);

  // ===== РАСХОДЫ =====

  List<Expense> get expenses => _local.expenses;

  void addExpense(Expense e) => _local.addExpense(e);

  // ===== ЗАРПЛАТА =====

  List<SalaryRule> get salaryRules => _local.salaryRules;

  List<SalaryPayment> get salaryPayments => _local.salaryPayments;

  void addSalaryRule(SalaryRule r) => _local.addSalaryRule(r);

  void addSalaryPayment(SalaryPayment p) => _local.addSalaryPayment(p);

  void saveSalaryRules() => _local.saveSalaryRules();

  // ===== ТАРИФЫ =====

  String? getOwnerTariff(String uid) => _local.getOwnerTariff(uid);

  void setOwnerTariff(String uid, String tariff) => _local.setOwnerTariff(uid, tariff);

  // ===== АВТОРИЗАЦИЯ =====

  Map<String, dynamic>? get currentUser => _local.currentUser;

  void setCurrentUser(Map<String, dynamic>? user) => _local.setCurrentUser(user);

  Map<String, dynamic>? loadCurrentUser() => _local.loadCurrentUser();

  Map<String, dynamic>? registerUser(String email, String pass, String name, String role) =>
      _local.registerUser(email, pass, name, role);

  void addUser(String email, String pass, String name, String role) =>
      _local.addUser(email, pass, name, role);

  void saveUsers() => _local.saveUsers();

  // ===== ТИКЕТЫ =====

  List<Map<String, dynamic>> get tickets => _local.tickets;

  void addTicket(String name, String email, String msg) => _local.addTicket(name, email, msg);

  void saveTickets() => _local.saveTickets();
}
