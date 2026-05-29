import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/firestore_service.dart';

/// Провайдер управления транспортом (для owner).
class VehicleProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;

  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get activeCount => _vehicles.where((v) => v.isActive).length;
  int get freeCount => _vehicles.where((v) => !v.isActive).length;

  /// Загружает список автомобилей владельца.
  Future<void> loadVehicles(String ownerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _vehicles = await _firestore.getVehicles(ownerId);
    } catch (e) {
      _error = 'Ошибка загрузки автомобилей: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
