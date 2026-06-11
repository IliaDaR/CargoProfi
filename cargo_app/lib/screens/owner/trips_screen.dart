import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../models/trip.dart';
import '../../services/local_storage.dart';
import '../../services/waybill_pdf.dart';
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
  String? _generatingWaybill; // ID рейса, для которого генерируется PDF

  List<Trip> _filtered(LocalStorage s) {
    final ownerId = s.currentUser?['uid'] ?? '';
    final myDriverIds = s.drivers.where((d) => d['ownerId'] == ownerId).map((d) => d['uid']).toSet();
    var r = s.trips.where((t) => myDriverIds.contains(t.driverId)).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
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
        icon: _generatingWaybill == t.id
            ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.description, size: 14),
        label: Text(_generatingWaybill == t.id ? '...' : 'PDF', style: const TextStyle(fontSize: 11)),
        onPressed: _generatingWaybill != null ? null : () async {
          setState(() => _generatingWaybill = t.id);
          final store = context.read<LocalStorage>();
          bool generated = false;
          try {
            final cloudFn = context.read<dynamic>();
            final url = await cloudFn.generateWaybill(t.id);
            if (url != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF сохранён в облаке!'), backgroundColor: Colors.green));
              generated = true;
            }
          } catch (_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сервис временно недоступен'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
          }
          if (!generated) {
            // Генерируем UUID для путевого листа и сохраняем в рейс
            final waybillUuid = '${t.id}-${DateTime.now().millisecondsSinceEpoch}';
            final idx = store.trips.indexWhere((tr) => tr.id == t.id);
            if (idx != -1) {
              store.trips[idx] = Trip(
                id: t.id, driverId: t.driverId, vehicleId: t.vehicleId, status: t.status,
                startTime: t.startTime, startLatitude: t.startLatitude, startLongitude: t.startLongitude,
                endTime: t.endTime, endLatitude: t.endLatitude, endLongitude: t.endLongitude,
                mileage: t.mileage, mileageSource: t.mileageSource,
                cargoDescription: t.cargoDescription, routeDescription: t.routeDescription,
                income: t.income, createdAt: t.createdAt, track: t.track,
                manualMileage: t.manualMileage,
                waybillUrl: t.waybillUrl, waybillUuid: waybillUuid,
                signatureStatus: t.signatureStatus, signatureUrl: t.signatureUrl,
                signatureHash: t.signatureHash, signedPdfUrl: t.signedPdfUrl,
                signedAt: t.signedAt, signedBy: t.signedBy,
              );
              store.saveTrips();
            }
            final bytes = await WaybillPdf.generate(t, store);
            await Printing.layoutPdf(onLayout: (_) => bytes);
          }
          if (mounted) setState(() => _generatingWaybill = null);
        },
      ),
      const SizedBox(width: 4),
      // Кнопка «Скачать PDF для Госключа»
      IconButton(
        icon: Icon(Icons.lock_outline, size: 16, color: Colors.amber.shade700),
        tooltip: 'Скачать PDF для Госключа',
        onPressed: () async {
          final store = context.read<LocalStorage>();
          final bytes = await WaybillPdf.generate(t, store);
          await Printing.layoutPdf(onLayout: (_) => bytes);
        },
      ),
      IconButton(
        icon: const Icon(Icons.edit, size: 16, color: Colors.orange),
        tooltip: 'Редактировать',
        onPressed: () => _showEditDialog(t),
      ),
      // Кнопка подписания УКЭП (Госключ)
      if (t.waybillUrl != null && t.signatureStatus != 'signed')
        IconButton(
          icon: const Icon(Icons.fingerprint, size: 16, color: Colors.indigo),
          tooltip: 'Подписать УКЭП (Госключ)',
          onPressed: () => _signWaybill(t),
        ),
      if (t.signatureStatus == 'signed')
        Icon(
          Icons.verified_user,
          size: 16,
          color: Colors.green.shade700,
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
              manualMileage: trip.manualMileage,
              waybillUrl: trip.waybillUrl, waybillUuid: trip.waybillUuid,
              signatureStatus: trip.signatureStatus, signatureUrl: trip.signatureUrl,
              signatureHash: trip.signatureHash, signedPdfUrl: trip.signedPdfUrl,
              signedAt: trip.signedAt, signedBy: trip.signedBy,
            );
            store.saveTrips();
            try {
              context.read<dynamic>().updateTrip(tripId: trip.id, routeDescription: routeCtrl.text, cargoDescription: cargoCtrl.text, income: double.tryParse(incomeCtrl.text), mileage: double.tryParse(mileageCtrl.text));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка синхронизации: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
            }
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

  Future<void> _signWaybill(Trip trip) async {
    final store = context.read<LocalStorage>();
    final cloudFn = context.read<dynamic>();

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Row(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(strokeWidth: 2),
      SizedBox(width: 16),
      Text('Отправка на подпись в Госключ...'),
    ])))));

    try {
      final result = await cloudFn.signWaybill(trip.id);
      if (mounted) Navigator.pop(context);

      if (result != null && result['success'] == true) {
        if (result['alreadySigned'] == true) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Путевой лист уже подписан'),
            backgroundColor: Colors.blue,
          ));
        } else {
          final idx = store.trips.indexWhere((t) => t.id == trip.id);
          if (idx != -1) {
            store.trips[idx] = Trip(
              id: trip.id, driverId: trip.driverId, vehicleId: trip.vehicleId, status: trip.status,
              startTime: trip.startTime, startLatitude: trip.startLatitude, startLongitude: trip.startLongitude,
              endTime: trip.endTime, endLatitude: trip.endLatitude, endLongitude: trip.endLongitude,
              mileage: trip.mileage, mileageSource: trip.mileageSource,
              cargoDescription: trip.cargoDescription, routeDescription: trip.routeDescription,
              income: trip.income, createdAt: trip.createdAt, track: trip.track,
              waybillUrl: trip.waybillUrl, waybillUuid: trip.waybillUuid,
              signatureStatus: 'signed',
              signatureUrl: result['signatureUrl'],
              signedPdfUrl: result['signedPdfUrl'],
              signedAt: DateTime.now(),
            );
            store.saveTrips();
            setState(() {});
          }
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Путевой лист подписан УКЭП!'),
            backgroundColor: Colors.green.shade700,
            action: result['signedPdfUrl'] != null ? SnackBarAction(label: 'Скачать', textColor: Colors.white, onPressed: () async {
              final bytes = await WaybillPdf.generate(trip, store);
              await Printing.layoutPdf(onLayout: (_) => bytes);
            }) : null,
          ));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result?['error'] ?? 'Не удалось подписать. Проверьте настройки Госключа.'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Widget _chip(TripStatus s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (s == TripStatus.active ? Colors.green : Colors.blue).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(tripStatusLabel(s), style: TextStyle(color: s == TripStatus.active ? Colors.green : Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)));
}
