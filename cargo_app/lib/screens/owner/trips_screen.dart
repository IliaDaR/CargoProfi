import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/trip.dart';
import '../../models/demo_data.dart';
import '../../utils/constants.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip> _trips = DemoData.trips;
  String _statusFilter = '';
  String _searchQuery = '';

  List<Trip> get _filtered {
    var r = _trips;
    if (_statusFilter.isNotEmpty) r = r.where((t) => t.status.name == _statusFilter).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      r = r.where((t) => (t.routeDescription?.toLowerCase().contains(q) ?? false) || (t.cargoDescription?.toLowerCase().contains(q) ?? false) || t.vehicleId.toLowerCase().contains(q)).toList();
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: TextField(
          decoration: const InputDecoration(hintText: 'Поиск...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
          onChanged: (v) => setState(() => _searchQuery = v)),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _statusFilter, hint: const Text('Статус'), underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: '', child: Text('Все')),
            DropdownMenuItem(value: 'active', child: Text('Активные')),
            DropdownMenuItem(value: 'completed', child: Text('Завершённые')),
          ],
          onChanged: (v) => setState(() => _statusFilter = v ?? ''),
        ),
      ])),
      Expanded(child: _filtered.isEmpty
        ? const Center(child: Text('Нет рейсов'))
        : isWide ? _buildTable(dateFormat) : _buildList(dateFormat)),
    ]);
  }

  Widget _buildTable(DateFormat df) {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(columnSpacing: 16, columns: const [
      DataColumn(label: Text('Дата')), DataColumn(label: Text('Маршрут')), DataColumn(label: Text('Водитель')),
      DataColumn(label: Text('Пробег')), DataColumn(label: Text('Доход')), DataColumn(label: Text('Статус')),
    ], rows: _filtered.map((t) => DataRow(cells: [
      DataCell(Text(df.format(t.startTime))),
      DataCell(Text(t.routeDescription ?? '—', maxLines: 2)),
      DataCell(Text(_driverName(t.driverId))),
      DataCell(Text('${t.mileage.toStringAsFixed(1)} км')),
      DataCell(Text(t.income != null ? '${t.income!.toStringAsFixed(0)} ₽' : '—
    ')),
      DataCell(_chip(t.status)),
    ])).toList())));
  }

  Widget _buildList(DateFormat df) {
    return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: _filtered.length, itemBuilder: (ctx, i) {
      final t = _filtered[i];
      return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(t.routeDescription ?? 'Без названия', style: const TextStyle(fontWeight: FontWeight.bold))), _chip(t.status)]),
        const SizedBox(height: 6),
        Text(df.format(t.startTime), style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${t.mileage.toStringAsFixed(1)} км'),
          if (t.income != null) Text('${t.income!.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ])));
    });
  }

  Widget _chip(TripStatus s) {
    final c = s == TripStatus.active ? Colors.green : Colors.blue;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(tripStatusLabel(s), style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)));
  }

  String _driverName(String id) {
    final d = DemoData.drivers.where((d) => d['uid'] == id).firstOrNull;
    return d?['displayName'] ?? id.substring(0, 8);
  }
}
