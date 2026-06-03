import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../models/trip.dart';
import '../../services/local_storage.dart';
import '../../services/waybill_pdf.dart';
import '../../services/cloud_functions_service.dart';
import '../../utils/constants.dart';
import 'trip_detail_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  String _statusFilter = '';
  String _search = '';
  int _pageSize = 20;

  List<Trip> _filtered(LocalStorage s) {
    var r = s.trips.reversed.toList();
    if (_statusFilter.isNotEmpty) r = r.where((t) => t.status.name == _statusFilter).toList();
    if (_search.isNotEmpty) { final q = _search.toLowerCase(); r = r.where((t) => (t.routeDescription?.toLowerCase().contains(q) ?? false) || (t.cargoDescription?.toLowerCase().contains(q) ?? false)).toList(); }
    _totalFiltered = r.length;
    return r.take(_pageSize).toList();
  }
  int _totalFiltered = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final list = _filtered(store);
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Поиск...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() => _search = v))),
        const SizedBox(width: 12),
        DropdownButton<String>(value: _statusFilter, hint: const Text('Статус'), underline: const SizedBox(), items: const [
          DropdownMenuItem(value: '', child: Text('Все')), DropdownMenuItem(value: 'active', child: Text('Активные')), DropdownMenuItem(value: 'completed', child: Text('Завершённые')),
        ], onChanged: (v) => setState(() => _statusFilter = v ?? '')),
      ])),
      Expanded(child: list.isEmpty ? const Center(child: Text('Нет рейсов'))
        : isWide ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
            DataColumn(label: Text('Дата')), DataColumn(label: Text('Водитель')), DataColumn(label: Text('Маршрут')), DataColumn(label: Text('Пробег')), DataColumn(label: Text('Доход')), DataColumn(label: Text('Статус')), DataColumn(label: Text('')), DataColumn(label: Text('')),
          ], rows: list.map((t) => DataRow(cells: [
            DataCell(Text(df.format(t.startTime))), DataCell(Text(_driverName(t.driverId))), DataCell(Text(t.routeDescription ?? '—')), DataCell(Text('${t.mileage.toStringAsFixed(1)} км')),
            DataCell(Text(t.income != null ? '${t.income!.toStringAsFixed(0)} ₽' : '—')), DataCell(_chip(t.status)),
            DataCell(_buildWaybillBtn(t)),
            DataCell(IconButton(icon: const Icon(Icons.map, size: 18, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: t.id))))),
          ])).toList()))
        : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: list.length, itemBuilder: (ctx, i) {
            final t = list[i];
            return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(t.routeDescription ?? 'Без названия', style: const TextStyle(fontWeight: FontWeight.bold))), _chip(t.status)]),
              const SizedBox(height: 4),
              Text(df.format(t.startTime), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text('${t.mileage.toStringAsFixed(1)} км${t.income != null ? ' • ${t.income!.toStringAsFixed(0)} ₽' : ''}'),
              if (t.status == TripStatus.completed) _buildWaybillBtn(t),
            ])));
          }          )),
      if (_totalFiltered > _pageSize)
        Padding(padding: const EdgeInsets.all(8), child: TextButton(onPressed: () => setState(() => _pageSize += 20), child: Text('Показать ещё ($_pageSize из $_totalFiltered)'))),
    ]);
  }

  Widget _buildWaybillBtn(Trip t) {
    if (t.status != TripStatus.completed) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      OutlinedButton.icon(
        icon: const Icon(Icons.description, size: 14),
        label: const Text('PDF', style: TextStyle(fontSize: 11)),
        onPressed: () async {
          final store = context.read<LocalStorage>();
          try {
            final cloudFn = context.read<CloudFunctionsService>();
            final url = await cloudFn.generateWaybill(t.id);
            if (url != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF сохранён в облаке!'), backgroundColor: Colors.green));
              return;
            }
          } catch (_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сервис временно недоступен. PDF сгенерирован локально.'), backgroundColor: Colors.orange, duration: Duration(seconds: 3)));
          }
          final bytes = await WaybillPdf.generate(t, store);
          await Printing.layoutPdf(onLayout: (_) => bytes);
        },
      ),
      const SizedBox(width: 4),
      IconButton(
        icon: const Icon(Icons.edit, size: 16, color: Colors.orange),
        tooltip: 'Редактировать',
        onPressed: () => _showEditDialog(t),
      ),
    ]);
  }

  void _showEditDialog(Trip trip) {
    final routeCtrl = TextEditingController(text: trip.routeDescription);
    final cargoCtrl = TextEditingController(text: trip.cargoDescription);
    final incomeCtrl = TextEditingController(text: trip.income?.toString() ?? '');
    final mileageCtrl = TextEditingController(text: trip.mileage.toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Редактировать рейс'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: routeCtrl, decoration: const InputDecoration(labelText: 'Маршрут', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: cargoCtrl, decoration: const InputDecoration(labelText: 'Груз', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: incomeCtrl, decoration: const InputDecoration(labelText: 'Доход (₽)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        TextField(controller: mileageCtrl, decoration: const InputDecoration(labelText: 'Пробег (км)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          final store = context.read<LocalStorage>();
          final idx = store.trips.indexWhere((t) => t.id == trip.id);
          if (idx != -1) {
            store.trips[idx] = Trip(
              id: trip.id, driverId: trip.driverId, vehicleId: trip.vehicleId, status: trip.status,
              startTime: trip.startTime, startLatitude: trip.startLatitude, startLongitude: trip.startLongitude,
              endTime: trip.endTime, endLatitude: trip.endLatitude, endLongitude: trip.endLongitude,
              mileage: double.tryParse(mileageCtrl.text) ?? trip.mileage,
              mileageSource: trip.mileageSource, cargoDescription: cargoCtrl.text, routeDescription: routeCtrl.text,
              income: double.tryParse(incomeCtrl.text), createdAt: trip.createdAt, track: trip.track,
            );
            store.saveTrips();
          }
          Navigator.pop(ctx);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Изменения сохранены'), backgroundColor: Colors.green));
        }, child: const Text('Сохранить')),
      ],
    ));
  }

  String _driverName(String id) {
    final store = context.read<LocalStorage>();
    final d = store.drivers.where((d) => d['uid'] == id).firstOrNull;
    return d?['displayName'] ?? id.substring(0, 8);
  }

  Widget _chip(TripStatus s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (s == TripStatus.active ? Colors.green : Colors.blue).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(tripStatusLabel(s), style: TextStyle(color: s == TripStatus.active ? Colors.green : Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)));
}
