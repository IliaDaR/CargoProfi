import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/trip.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';

/// Экран истории рейсов водителя.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _firestore = FirestoreService();

  List<Trip> _trips = [];
  bool _isLoading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    try {
      _trips = await _firestore.getDriverTrips();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<Trip> get _filteredTrips {
    if (_statusFilter == null || _statusFilter!.isEmpty) return _trips;
    if (_statusFilter == 'active') {
      return _trips.where((t) => t.status == TripStatus.active).toList();
    }
    if (_statusFilter == 'completed') {
      return _trips.where((t) => t.status == TripStatus.completed).toList();
    }
    return _trips;
  }

  Color _statusColor(TripStatus status) {
    switch (status) {
      case TripStatus.active:
        return Colors.green;
      case TripStatus.completed:
        return Colors.blue;
      case TripStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('История рейсов'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('Все')),
              const PopupMenuItem(value: 'active', child: Text('Активные')),
              const PopupMenuItem(value: 'completed', child: Text('Завершённые')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrips,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredTrips.isEmpty
                ? const Center(child: Text('Нет рейсов'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredTrips.length,
                    itemBuilder: (ctx, i) {
                      final trip = _filteredTrips[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(trip.status).withOpacity(0.15),
                            child: Icon(
                              trip.status == TripStatus.active
                                  ? Icons.drive_eta
                                  : Icons.check_circle,
                              color: _statusColor(trip.status),
                            ),
                          ),
                          title: Text(trip.routeDescription ?? 'Рейс без названия'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateFormat.format(trip.startTime)),
                              Row(
                                children: [
                                  Text('${trip.mileage.toStringAsFixed(1)} км'),
                                  const SizedBox(width: 12),
                                  Text(mileageSourceLabel(trip.mileageSource),
                                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _statusColor(trip.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tripStatusLabel(trip.status),
                                  style: TextStyle(color: _statusColor(trip.status), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (trip.income != null) ...[
                                const SizedBox(height: 4),
                                Text('${trip.income!.toStringAsFixed(0)} ₽',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
