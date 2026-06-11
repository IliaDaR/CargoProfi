import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/local_storage.dart';
import '../../models/trip.dart';
import '../../models/expense.dart';
import '../../utils/constants.dart';

class TripDetailScreen extends StatelessWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    final trip = store.trips.where((t) => t.id == tripId).firstOrNull;

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Детали рейса')),
        body: const Center(child: Text('Рейс не найден')),
      );
    }

    if (trip.status != TripStatus.completed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Детали рейса')),
        body: const Center(child: Text('Рейс ещё не завершён')),
      );
    }

    final tripExpenses =
        store.expenses.where((e) => e.tripId == tripId).toList();
    final vehicle =
        store.vehicles.where((v) => v.id == trip.vehicleId).firstOrNull;
    final df = DateFormat('dd.MM.yyyy');

    final duration = trip.endTime != null
        ? trip.endTime!.difference(trip.startTime)
        : Duration.zero;

    return Scaffold(
      appBar: AppBar(title: const Text('Детали рейса')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, trip, df),
            const SizedBox(height: 16),
            _buildMainCard(context, trip, vehicle, duration),
            const SizedBox(height: 16),
            _buildRouteCard(context, trip, tripExpenses),
            const SizedBox(height: 16),
            _buildExpensesCard(context, tripExpenses),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader(BuildContext context, Trip trip, DateFormat df) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trip.routeDescription ?? 'Без маршрута',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              df.format(trip.startTime),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            _badge(tripStatusLabel(TripStatus.completed), Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }


  Widget _buildMainCard(
    BuildContext context,
    Trip trip,
    dynamic vehicle,
    Duration duration,
  ) {
    final durHours = duration.inHours;
    final durMinutes = duration.inMinutes.remainder(60);
    final durStr =
        '${durHours.toString().padLeft(2, '0')}:${durMinutes.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Основное',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _infoRow(
              Icons.directions_car,
              'Машина',
              vehicle != null
                  ? '${vehicle.plateNumber} — ${vehicle.brand} ${vehicle.model}'
                  : 'Не указана',
            ),
            _infoRow(
              Icons.speed,
              'Пробег',
              '${trip.mileage.toStringAsFixed(1)} км',
            ),
            _infoRow(
              Icons.attach_money,
              'Доход',
              '${(trip.income ?? 0).toStringAsFixed(0)} ₽',
            ),
            _infoRow(Icons.timer, 'Время в пути', durStr),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRouteCard(
    BuildContext context,
    Trip trip,
    List<Expense> expenses,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Маршрут',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (trip.track.isEmpty)
              const SizedBox(
                height: 250,
                child: Center(
                  child: Text(
                    'Нет данных GPS-трека',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              SizedBox(
                height: 250,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FlutterMap(
                    options: _mapOptions(trip),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.numino.cargoprofi',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: trip.track
                                .map((p) => LatLng(p.latitude, p.longitude))
                                .toList(),
                            color: Colors.blue,
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: _buildMarkers(trip, expenses),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  MapOptions _mapOptions(Trip trip) {
    if (trip.track.isEmpty) {
      return MapOptions(
        initialCenter: LatLng(trip.startLatitude, trip.startLongitude),
        initialZoom: 13,
      );
    }

    final allPoints = <LatLng>[
      LatLng(trip.startLatitude, trip.startLongitude),
      ...trip.track.map((p) => LatLng(p.latitude, p.longitude)),
      if (trip.endLatitude != null && trip.endLongitude != null)
        LatLng(trip.endLatitude!, trip.endLongitude!),
    ];

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    return MapOptions(
      initialCenter: center,
      initialZoom: 13,
    );
  }

  List<Marker> _buildMarkers(Trip trip, List<Expense> expenses) {
    final markers = <Marker>[];

    final firstPt = trip.track.isNotEmpty
        ? trip.track.first
        : TrackPoint(
            latitude: trip.startLatitude,
            longitude: trip.startLongitude,
            timestamp: trip.startTime,
          );
    markers.add(
      Marker(
        point: LatLng(firstPt.latitude, firstPt.longitude),
        width: 32,
        height: 32,
        child: const Icon(Icons.trip_origin, color: Colors.green, size: 28),
      ),
    );

    if (trip.endLatitude != null && trip.endLongitude != null) {
      markers.add(
        Marker(
          point: LatLng(trip.endLatitude!, trip.endLongitude!),
          width: 32,
          height: 32,
          child:
              const Icon(Icons.flag_circle, color: Colors.red, size: 28),
        ),
      );
    } else if (trip.track.isNotEmpty) {
      final lastPt = trip.track.last;
      markers.add(
        Marker(
          point: LatLng(lastPt.latitude, lastPt.longitude),
          width: 32,
          height: 32,
          child:
              const Icon(Icons.flag_circle, color: Colors.red, size: 28),
        ),
      );
    }

    for (final exp in expenses) {
      if (exp.latitude != 0 || exp.longitude != 0) {
        markers.add(
          Marker(
            point: LatLng(exp.latitude, exp.longitude),
            width: 28,
            height: 28,
            child: const Icon(
              Icons.monetization_on,
              color: Colors.orange,
              size: 24,
            ),
          ),
        );
      }
    }

    return markers;
  }


  Widget _buildExpensesCard(BuildContext context, List<Expense> expenses) {
    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Расходы',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Нет расходов',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...expenses.map((e) => _expenseItem(context, e)),
            if (expenses.isNotEmpty) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Итого',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${total.toStringAsFixed(0)} ₽',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expenseItem(BuildContext context, Expense e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _expenseIcon(e.category),
            color: _expenseColor(e.category),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      expenseCategoryLabel(e.category),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${e.amount.toStringAsFixed(0)} ₽',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (e.description != null && e.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      e.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (e.receiptUrl != null && e.receiptUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _receiptThumbnail(context, e.receiptUrl!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _receiptThumbnail(BuildContext context, String receiptUrl) {
    final Widget image;
    final bool isBase64 = receiptUrl.startsWith('data:');

    if (isBase64 && receiptUrl.contains('base64,')) {
      image = Image.memory(
        base64Decode(receiptUrl.split('base64,').last),
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 60, color: Colors.grey),
      );
    } else if (receiptUrl.startsWith('http')) {
      image = Image.network(
        receiptUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 60, color: Colors.grey),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: 60,
            height: 60,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _showFullscreenReceipt(context, receiptUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: image,
      ),
    );
  }

  void _showFullscreenReceipt(BuildContext context, String receiptUrl) {
    final bool isBase64 = receiptUrl.startsWith('data:');
    Widget fullImage;

    if (isBase64 && receiptUrl.contains('base64,')) {
      fullImage = Image.memory(
        base64Decode(receiptUrl.split('base64,').last),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 80)),
      );
    } else if (receiptUrl.startsWith('http')) {
      fullImage = Image.network(
        receiptUrl,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 80)),
      );
    } else {
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Center(child: fullImage),
            ),
            Positioned(
              top: 40,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _expenseIcon(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.fuel:
        return Icons.local_gas_station;
      case ExpenseCategory.parking:
        return Icons.local_parking;
      case ExpenseCategory.repair:
        return Icons.build;
      case ExpenseCategory.toll:
        return Icons.toll;
      case ExpenseCategory.washing:
        return Icons.local_car_wash;
      case ExpenseCategory.tires:
        return Icons.tire_repair;
      case ExpenseCategory.insurance:
        return Icons.verified_user;
      case ExpenseCategory.other:
        return Icons.receipt_long;
    }
  }

  Color _expenseColor(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.fuel:
        return Colors.orange;
      case ExpenseCategory.parking:
        return Colors.blueGrey;
      case ExpenseCategory.repair:
        return Colors.red;
      case ExpenseCategory.toll:
        return Colors.teal;
      case ExpenseCategory.washing:
        return Colors.lightBlue;
      case ExpenseCategory.tires:
        return Colors.brown;
      case ExpenseCategory.insurance:
        return Colors.indigo;
      case ExpenseCategory.other:
        return Colors.grey;
    }
  }
}
