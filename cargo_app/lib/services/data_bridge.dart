import 'local_storage.dart';
import 'yandex_bridge.dart';
import '../models/trip.dart';
import '../models/expense.dart';

/// DataBridge — write-through из LocalStorage в Yandex Cloud
class DataBridge {
  final LocalStorage local;
  DataBridge(this.local);

  Future<void> addTrip(Trip t) async {
    local.addTrip(t);
    try { await YandexBridge.instance.functions.startTrip(vehicleId: t.vehicleId, latitude: t.startLatitude, longitude: t.startLongitude, cargoDescription: t.cargoDescription, routeDescription: t.routeDescription); } catch (_) {}
  }

  Future<void> endTrip(Trip t, double lat, double lon, {double? income}) async {
    local.saveTrips();
    try { await YandexBridge.instance.functions.endTrip(tripId: t.id, latitude: lat, longitude: lon, income: income); } catch (_) {}
  }

  Future<void> addExpense(Expense e) async {
    local.addExpense(e);
    try { await YandexBridge.instance.functions.addExpense(tripId: e.tripId, amount: e.amount, category: e.category.name, latitude: e.latitude, longitude: e.longitude, description: e.description); } catch (_) {}
  }

  Future<void> generateWaybill(String tripId) async {
    try { await YandexBridge.instance.functions.generateWaybill(tripId); } catch (_) {}
  }

  Future<void> signWaybill(String tripId) async {
    try { await YandexBridge.instance.functions.signWaybill(tripId); } catch (_) {}
  }

  Future<void> addSalaryRule(String driverId, String type, {double? percent, double? fixed}) async {
    try { await YandexBridge.instance.functions.setSalaryRule(driverId: driverId, type: type, percentValue: percent, fixedValue: fixed); } catch (_) {}
  }
}
