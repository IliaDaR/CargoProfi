import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';

/// Провайдер управления расходами.
class ExpenseProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<Expense> _expenses = [];
  bool _isLoading = false;
  String? _error;
  double _total = 0.0;

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get total => _total;

  /// Загружает расходы для конкретного рейса.
  Future<void> loadTripExpenses(String tripId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await _firestore.getTripExpenses(tripId);
      _total = _expenses.fold(0.0, (sum, e) => sum + e.amount);
    } catch (e) {
      _error = 'Ошибка загрузки расходов: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Загружает сводку расходов водителя за период (owner).
  Future<void> loadDriverExpensesReport({
    required String driverId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await _firestore.getDriverExpenses(
        driverId: driverId,
        startDate: startDate,
        endDate: endDate,
      );
      _total = _expenses.fold(0.0, (sum, e) => sum + e.amount);
    } catch (e) {
      _error = 'Ошибка загрузки отчёта: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Сгруппировать расходы по категориям.
  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final e in _expenses) {
      map[e.category.name] = (map[e.category.name] ?? 0) + e.amount;
    }
    return map;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
