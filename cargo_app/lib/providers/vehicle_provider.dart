import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../models/demo_data.dart';
import '../services/firestore_service.dart';

class VehicleProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;
  bool _demo = true;

  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get activeCount => _vehicles.where((v) => v.isActive).length;
  int get freeCount => _vehicles.where((v) => !v.isActive).length;

  Future<void> loadVehicles(String ownerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _vehicles = await _firestore.getVehicles(ownerId);
      _demo = _vehicles.isEmpty;
    } catch (e) {
      _demo = true;
    }

    if (_demo) {
      await Future.delayed(const Duration(milliseconds: 300));
      _vehicles = DemoData.vehicles;
    }

    _isLoading = false;
    notifyListeners();
  }

  void addVehicle(Vehicle v) {
    _vehicles.add(v);
    notifyListeners();
  }

  void clearError() { _error = null; notifyListeners(); }
}
