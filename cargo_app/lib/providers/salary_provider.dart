import 'package:flutter/material.dart';
import '../models/salary_rule.dart';
import '../models/salary_payment.dart';
import '../services/firestore_service.dart';

/// Провайдер управления зарплатами (owner).
class SalaryProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<SalaryPayment> _payments = [];
  SalaryRule? _currentRule;
  SalaryPayment? _lastCalculation;
  List<Map<String, dynamic>> _drivers = [];
  
  bool _isLoading = false;
  String? _error;

  List<SalaryPayment> get payments => _payments;
  SalaryRule? get currentRule => _currentRule;
  SalaryPayment? get lastCalculation => _lastCalculation;
  List<Map<String, dynamic>> get drivers => _drivers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Загружает список водителей владельца.
  Future<void> loadDrivers(String ownerId) async {
    try {
      _drivers = await _firestore.getDrivers(ownerId);
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка загрузки водителей: $e';
      notifyListeners();
    }
  }

  /// Загружает правило зарплаты для конкретного водителя.
  Future<void> loadSalaryRule(String driverId) async {
    try {
      _currentRule = await _firestore.getSalaryRule(driverId);
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка загрузки правила: $e';
      notifyListeners();
    }
  }

  /// Задаёт правило начисления зарплаты.
  Future<bool> setSalaryRule({
    required String driverId,
    required String type,
    double? percentValue,
    double? fixedValue,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore.setSalaryRule(
        driverId: driverId,
        type: type,
        percentValue: percentValue,
        fixedValue: fixedValue,
      );
      await loadSalaryRule(driverId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Рассчитывает зарплату за период.
  Future<bool> calculateSalary({
    required String driverId,
    required String periodStart,
    required String periodEnd,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _lastCalculation = await _firestore.calculateSalary(
        driverId: driverId,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Ошибка расчёта: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Загружает историю выплат.
  Future<void> loadSalaryHistory(String driverId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _payments = await _firestore.getSalaryHistory(driverId);
    } catch (e) {
      _error = 'Ошибка загрузки истории: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
