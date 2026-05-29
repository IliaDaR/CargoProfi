import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/trip.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

/// Вкладка «Рейсы» для владельца.
/// Таблица с фильтрацией, кнопка «Путевой лист» (генерирует PDF).
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final _firestore = FirestoreService();

  List<Trip> _trips = [];
  bool _isLoading = true;
  String _statusFilter = '';
  String _searchQuery = '';
  String? _generatingWaybillFor;

  @override
  void initState() {
    super.initState();
    // Слушаем рейсы в реальном времени
    _firestore.allTripsStream().listen((trips) {
      if (mounted) {
        setState(() {
          _trips = trips;
          _isLoading = false;
        });
      }
    });
  }

  List<Trip> get _filteredTrips {
    var result = _trips;
    if (_statusFilter.isNotEmpty) {
      result = result.where((t) => t.status.name == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) =>
        (t.routeDescription?.toLowerCase().contains(q) ?? false) ||
        (t.cargoDescription?.toLowerCase().contains(q) ?? false) ||
        t.vehicleId.toLowerCase().contains(q)
      ).toList();
    }
    return result;
  }

  Future<void> _generateWaybill(String tripId) async {
    setState(() => _generatingWaybillFor = tripId);
    try {
      final url = await _firestore.generateWaybill(tripId);
      if (mounted) {
        AppWidgets.showSuccess(context, 'Путевой лист сформирован!');
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) AppWidgets.showError(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _generatingWaybillFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Column(
      children: [
        // Фильтры
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Поиск по маршруту или грузу...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                hint: const Text('Статус'),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Все')),
                  DropdownMenuItem(value: 'active', child: Text('Активные')),
                  DropdownMenuItem(value: 'completed', child: Text('Завершённые')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Отменённые')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? ''),
              ),
            ],
          ),
        ),

        // Таблица рейсов
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredTrips.isEmpty
                  ? const Center(child: Text('Нет рейсов'))
                  : isWide
                      ? _buildDataTable(dateFormat)
                      : _buildMobileList(dateFormat),
        ),
      ],
    );
  }

  Widget _buildDataTable(DateFormat dateFormat) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Дата')),
            DataColumn(label: Text('Маршрут')),
            DataColumn(label: Text('Водитель')),
            DataColumn(label: Text('Пробег')),
            DataColumn(label: Text('Доход')),
            DataColumn(label: Text('Статус')),
            DataColumn(label: Text('Действия')),
          ],
          rows: _filteredTrips.map((trip) {
            return DataRow(cells: [
              DataCell(Text(dateFormat.format(trip.startTime))),
              DataCell(Text(trip.routeDescription ?? '—', maxLines: 2)),
              DataCell(Text(trip.driverId.substring(0, 8))),
              DataCell(Text('${trip.mileage.toStringAsFixed(1)} км')),
              DataCell(Text(trip.income != null ? '${trip.income!.toStringAsFixed(0)} ₽' : '—')),
              DataCell(_statusChip(trip.status)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trip.status == TripStatus.completed)
                      _generatingWaybillFor == trip.id
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton.icon(
                              icon: const Icon(Icons.description, size: 16),
                              label: const Text('Путевой лист', style: TextStyle(fontSize: 12)),
                              onPressed: () => _generateWaybill(trip.id),
                            ),
                    if (trip.waybillUrl != null)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        tooltip: 'Открыть PDF',
                        onPressed: () => launchUrl(Uri.parse(trip.waybillUrl!), mode: LaunchMode.externalApplication),
                      ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileList(DateFormat dateFormat) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _filteredTrips.length,
      itemBuilder: (ctx, i) {
        final trip = _filteredTrips[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(trip.routeDescription ?? 'Без названия',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                    _statusChip(trip.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(dateFormat.format(trip.startTime), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${trip.mileage.toStringAsFixed(1)} км'),
                    if (trip.income != null) Text('${trip.income!.toStringAsFixed(0)} ₽',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if (trip.status == TripStatus.completed) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: _generatingWaybillFor == trip.id
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : OutlinedButton.icon(
                            icon: const Icon(Icons.description, size: 14),
                            label: const Text('Путевой лист', style: TextStyle(fontSize: 11)),
                            onPressed: () => _generateWaybill(trip.id),
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(TripStatus status) {
    Color color;
    switch (status) {
      case TripStatus.active:
        color = Colors.green;
      case TripStatus.completed:
        color = Colors.blue;
      case TripStatus.cancelled:
        color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(tripStatusLabel(status),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
