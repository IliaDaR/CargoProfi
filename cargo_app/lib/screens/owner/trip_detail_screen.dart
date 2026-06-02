import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/trip.dart';
import '../../models/expense.dart';
import '../../services/local_storage.dart';
import '../../utils/constants.dart';

class TripDetailScreen extends StatelessWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    final trip = store.trips.where((t) => t.id == tripId).firstOrNull;
    if (trip == null) return const Scaffold(body: Center(child: Text('Рейс не найден')));

    final expenses = store.expenses.where((e) => e.tripId == tripId).toList();
    final driver = store.drivers.where((d) => d['uid'] == trip.driverId).firstOrNull;
    final vehicle = store.vehicles.where((v) => v.id == trip.vehicleId).firstOrNull;
    final df = DateFormat('dd.MM.yyyy HH:mm');

    final markers = <Marker>[];
    // Старт
    markers.add(Marker(
      point: LatLng(trip.startLatitude, trip.startLongitude),
      width: 32, height: 32,
      child: const Icon(Icons.play_circle, color: Colors.green, size: 32),
    ));
    // Финиш
    if (trip.endLatitude != null && trip.endLongitude != null) {
      markers.add(Marker(
        point: LatLng(trip.endLatitude!, trip.endLongitude!),
        width: 32, height: 32,
        child: const Icon(Icons.stop_circle, color: Colors.red, size: 32),
      ));
    }
    // Расходы
    for (final e in expenses) {
      markers.add(Marker(
        point: LatLng(e.latitude, e.longitude),
        width: 20, height: 20,
        child: Container(
          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)),
          child: const Icon(Icons.attach_money, color: Colors.white, size: 14),
        ),
      ));
    }

    final trackPolyline = Polyline(
      points: [
        LatLng(trip.startLatitude, trip.startLongitude),
        if (trip.endLatitude != null && trip.endLongitude != null)
          LatLng(trip.endLatitude!, trip.endLongitude!),
      ],
      color: Colors.blue,
      strokeWidth: 3,
    );

    final center = LatLng(trip.startLatitude, trip.startLongitude);

    return Scaffold(
      appBar: AppBar(title: Text(trip.routeDescription ?? 'Детали рейса')),
      body: Column(children: [
        // Карта
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.35,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 6.0),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              PolylineLayer(polylines: [trackPolyline]),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        // Детали
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row('Маршрут', trip.routeDescription ?? '—'),
          _row('Груз', trip.cargoDescription ?? '—'),
          _row('Водитель', driver?['displayName'] ?? trip.driverId.substring(0, 8)),
          _row('Машина', vehicle != null ? '${vehicle.brand} ${vehicle.model} (${vehicle.plateNumber})' : '—'),
          const SizedBox(height: 8),
          _row('Старт', df.format(trip.startTime)),
          if (trip.endTime != null) _row('Финиш', df.format(trip.endTime!)),
          _row('Пробег', '${trip.mileage.toStringAsFixed(1)} км (${trip.mileageSource == MileageSource.auto ? "авто" : "вручную"})'),
          if (trip.income != null) _row('Доход', '${trip.income!.toStringAsFixed(0)} ₽'),
          const SizedBox(height: 12),
          if (expenses.isNotEmpty) ...[
            Text('Расходы (${expenses.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            ...expenses.map((e) => Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: const Icon(Icons.receipt, color: Colors.orange, size: 18)),
              title: Text(expenseCategoryLabel(e.category)),
              subtitle: Text(e.description ?? ''),
              trailing: Text('${e.amount.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
            ))),
          ],
        ]))),
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]));
  }
}
