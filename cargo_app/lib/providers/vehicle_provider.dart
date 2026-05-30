import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/local_storage.dart';

class VehicleProvider extends ChangeNotifier {
  final LocalStorage _storage;
  VehicleProvider(this._storage);

  List<Vehicle> get vehicles => _storage.vehicles;
  int get activeCount => _storage.vehicles.where((v) => v.isActive).length;
  int get freeCount => _storage.vehicles.where((v) => !v.isActive).length;

  void addVehicle(Vehicle v) {
    _storage.addVehicle(v);
    notifyListeners();
  }
}
