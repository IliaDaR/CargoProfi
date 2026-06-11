import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../utils/constants.dart';
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

    final waybillUuid = trip.waybillUuid ?? '${trip.id}-${DateTime.now().millisecondsSinceEpoch}';
    final checkUrl = 'https://numino.ru/check?id=$waybillUuid';

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
          if (driver?['licenseNumber'] != null && driver!['licenseNumber'].toString().isNotEmpty) _row('Вод. удост.:', driver['licenseNumber'].toString()),
          if (driver?['medExamNumber'] != null && driver!['medExamNumber'].toString().isNotEmpty) _row('Медосмотр №:', driver['medExamNumber'].toString()),
          if (vehicle?.techExamNumber != null && vehicle!.techExamNumber!.isNotEmpty) _row('Техосмотр №:', vehicle.techExamNumber!),
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
          pw.SizedBox(height: 10),
          _divider(),
          pw.SizedBox(height: 8),
          pw.Text('Код проверки: ${waybillUuid.substring(0, 8)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          pw.Text('Проверка: $checkUrl', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
          pw.SizedBox(height: 6),
          _qrCodeWidget(checkUrl),
          pw.SizedBox(height: 12),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(children: [
              pw.Divider(),
              pw.Text('Водитель', style: pw.TextStyle(fontSize: 10)),
            ]),
            pw.Column(children: [
              pw.Divider(),
              pw.Text('Владелец', style: pw.TextStyle(fontSize: 10)),
            ]),
          ]),
          pw.SizedBox(height: 10),
          if (trip.signatureStatus == 'signed') ...[
            pw.Text('ЭЦП: документ подписан УКЭП (Госключ)', style: pw.TextStyle(fontSize: 9, color: PdfColors.green)),
            if (trip.signatureHash != null)
              pw.Text('Хэш: ${trip.signatureHash}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
            if (trip.signedAt != null)
              pw.Text('Подписан: ${df.format(trip.signedAt!)} ${DateFormat('HH:mm').format(trip.signedAt!)}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
          ] else ...[
            pw.Text('Место для УКЭП (Госключ)', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          ],
        ];
      },
    ));

    return pdf.save();
  }

  static pw.Widget _header(Trip trip) {
    final df = DateFormat('dd.MM.yyyy');
    return pw.Center(
      child: pw.Column(children: [
        pw.Text('ПУТЕВОЙ ЛИСТ ГРУЗОВОГО АВТОМОБИЛЯ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
    return pw.Text(text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline));
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

  static pw.Widget _qrCodeWidget(String data) {
    return pw.Text('numino.ru/check', style: pw.TextStyle(fontSize: 6, color: PdfColors.grey));
  }
}
