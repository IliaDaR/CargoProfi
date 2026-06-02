import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../services/local_storage.dart';

/// Генерирует PDF путевого листа по форме Минтранса.
class WaybillPdf {
  static Future<Uint8List> generate(Trip trip, LocalStorage store) async {
    final pdf = pw.Document();
    final df = DateFormat('dd.MM.yyyy');
    final tf = DateFormat('HH:mm');

    final vehicle = store.vehicles.where((v) => v.id == trip.vehicleId).firstOrNull;
    final driver = store.drivers.where((d) => d['uid'] == trip.driverId).firstOrNull;
    final driverName = driver?['displayName'] ?? trip.driverId;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context ctx) {
        return [
          _header(trip),
          pw.SizedBox(height: 8),
          _divider(),
          pw.SizedBox(height: 10),
          _sectionTitle('РЕЖИМ РАБОТЫ'),
          pw.SizedBox(height: 6),
          _row('Время выезда:', '${tf.format(trip.startTime)}    ${df.format(trip.startTime)}'),
          _row('Время возврата:', trip.endTime != null ? '${tf.format(trip.endTime!)}    ${df.format(trip.endTime!)}' : '______________'),
          pw.SizedBox(height: 4),
          _row('Автомобиль:', '${vehicle?.brand ?? '—'} ${vehicle?.model ?? ''}'),
          _row('Гос. номер:', vehicle?.plateNumber ?? '—'),
          _row('Водитель:', driverName),
          pw.SizedBox(height: 4),
          _row('Пробег:', '${trip.mileage.toStringAsFixed(1)} км (${trip.mileageSource == MileageSource.auto ? "автоматически" : "вручную"})'),
          pw.SizedBox(height: 10),
          _divider(),
          pw.SizedBox(height: 10),
          _sectionTitle('ЗАДАНИЕ ВОДИТЕЛЮ'),
          pw.SizedBox(height: 6),
          _row('Маршрут:', trip.routeDescription ?? '—'),
          pw.SizedBox(height: 4),
          _row('Груз:', trip.cargoDescription ?? '—'),
          pw.SizedBox(height: 10),
          _divider(),
          pw.SizedBox(height: 10),
          if (trip.income != null) ...[
            _row('Доход за рейс:', '${trip.income!.toStringAsFixed(0)} ₽'),
            pw.SizedBox(height: 10),
            _divider(),
            pw.SizedBox(height: 10),
          ],
          pw.SizedBox(height: 20),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(children: [
              pw.Container(width: 150, child: const pw.Divider()),
              pw.Text('Водитель', style: const pw.TextStyle(fontSize: 10)),
            ]),
            pw.Column(children: [
              pw.Container(width: 150, child: const pw.Divider()),
              pw.Text('Владелец', style: const pw.TextStyle(fontSize: 10)),
            ]),
          ]),
        ];
      },
    ));

    return pdf.save();
  }

  static pw.Widget _header(Trip trip) {
    final df = DateFormat('dd.MM.yyyy');
    return pw.Center(
      child: pw.Column(children: [
        pw.Text('ПУТЕВОЙ ЛИСТ ГРУЗОВОГО АВТОМОБИЛЯ', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Форма по Приказу Минтранса России', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
        pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Дата: ${df.format(trip.startTime)}', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('Рейс № ${trip.id.substring(0, 8)}', style: const pw.TextStyle(fontSize: 11)),
        ]),
      ]),
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Text(text, style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline));
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.SizedBox(width: 100, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
        pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
      ]),
    );
  }

  static pw.Widget _divider() {
    return pw.Container(height: 1, color: PdfColors.grey300);
  }
}
