import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/local_storage.dart';
import '../../utils/constants.dart';

class DriverProfileScreen extends StatelessWidget {
  final String driverId;

  const DriverProfileScreen({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    final driver = store.drivers.where((d) => d['uid'] == driverId).firstOrNull;

    if (driver == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Профиль'),
        ),
        body: const Center(child: Text('Водитель не найден')),
      );
    }

    final displayName = driver['displayName'] as String? ?? '';
    final email = driver['email'] as String? ?? '';
    final phone = driver['phone'] as String?;
    final licenseNumber = driver['licenseNumber'] as String?;

    final completedTrips = store.trips
        .where((t) =>
            t.driverId == driverId && t.status == TripStatus.completed)
        .toList();
    final totalTrips = completedTrips.length;
    final totalMileage =
        completedTrips.fold<double>(0, (sum, t) => sum + t.mileage);
    final totalIncome = completedTrips.fold<double>(
        0, (sum, t) => sum + (t.income ?? 0));

    final medExamDateStr = driver['medExamDate'] as String?;
    final medExamDate =
        medExamDateStr != null ? DateTime.tryParse(medExamDateStr) : null;
    final medExamValid = medExamDate != null &&
        medExamDate.isAfter(
            DateTime.now().subtract(const Duration(days: 365)));
    final medExamValidUntil =
        medExamDate?.add(const Duration(days: 365));

    final currencyFormat = NumberFormat('#,##0', 'ru');
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Профиль'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(displayName, email),
            const SizedBox(height: 16),
            _buildDataCard(
              context,
              store,
              driverId,
              phone,
              email,
              licenseNumber,
            ),
            const SizedBox(height: 12),
            _buildMedExamCard(
              context,
              store,
              driverId,
              medExamDate,
              medExamValid,
              medExamValidUntil,
              dateFormat,
            ),
            const SizedBox(height: 12),
            _buildStatsCard(
              totalTrips,
              totalMileage,
              totalIncome,
              currencyFormat,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String displayName, String email) {
    final firstLetter = displayName.isNotEmpty ? displayName[0] : '?';

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue.shade700,
            child: Text(
              firstLetter.toUpperCase(),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(
    BuildContext context,
    LocalStorage store,
    String driverId,
    String? phone,
    String email,
    String? licenseNumber,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Данные',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue),
              title: const Text('Телефон'),
              subtitle: Text(phone ?? '—'),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Email'),
              subtitle: Text(email),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              leading: const Icon(Icons.badge, color: Colors.blue),
              title: const Text('Водительское удостоверение'),
              subtitle: Text(licenseNumber ?? 'Не указано'),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () => _showEditLicenseDialog(
                  context, store, driverId, licenseNumber),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedExamCard(
    BuildContext context,
    LocalStorage store,
    String driverId,
    DateTime? medExamDate,
    bool medExamValid,
    DateTime? medExamValidUntil,
    DateFormat dateFormat,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Медосмотр',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.medical_services, color: Colors.teal),
              title: const Text('Дата последнего осмотра'),
              subtitle: Text(medExamDate != null
                  ? dateFormat.format(medExamDate)
                  : 'Нет данных'),
              trailing: medExamDate != null
                  ? _buildMedExamBadge(medExamValid, medExamValidUntil,
                      dateFormat)
                  : null,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showUpdateMedExamDialog(
                      context, store, driverId),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Обновить'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedExamBadge(
    bool valid,
    DateTime? validUntil,
    DateFormat dateFormat,
  ) {
    if (valid && validUntil != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅ ', style: TextStyle(fontSize: 12)),
            Text(
              'Действителен до ${dateFormat.format(validUntil)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚠️ ', style: TextStyle(fontSize: 12)),
          Text(
            'Просрочен',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    int totalTrips,
    double totalMileage,
    double totalIncome,
    NumberFormat currencyFormat,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Статистика',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.route, color: Colors.indigo),
              title: const Text('Всего рейсов'),
              trailing: Text(
                totalTrips.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.indigo),
              title: const Text('Общий пробег'),
              trailing: Text(
                '${totalMileage.toStringAsFixed(0)} км',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1, indent: 72),
            ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.indigo),
              title: const Text('Общий доход'),
              trailing: Text(
                '${currencyFormat.format(totalIncome.toInt())} ₽',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLicenseDialog(
    BuildContext context,
    LocalStorage store,
    String driverId,
    String? currentLicense,
  ) {
    final controller = TextEditingController(text: currentLicense ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Водительское удостоверение'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Номер удостоверения',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final idx =
                  store.drivers.indexWhere((d) => d['uid'] == driverId);
              if (idx != -1) {
                store.drivers[idx]['licenseNumber'] =
                    controller.text.trim();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showUpdateMedExamDialog(
    BuildContext context,
    LocalStorage store,
    String driverId,
  ) {
    final numberCtrl = TextEditingController();
    DateTime? selectedDate;
    Uint8List? photoBytes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final dateFormat = DateFormat('dd.MM.yyyy');

          return AlertDialog(
            title: const Text('Обновить медосмотр'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: numberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Номер медосмотра',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setLocal(() => selectedDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата осмотра',
                        border: OutlineInputBorder(),
                        suffixIcon:
                            Icon(Icons.calendar_today, size: 20),
                      ),
                      child: Text(
                        selectedDate != null
                            ? dateFormat.format(selectedDate!)
                            : 'Выберите дату',
                        style: TextStyle(
                          color: selectedDate != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final img = await ImagePicker().pickImage(
                            source: ImageSource.camera,
                            maxWidth: 800,
                            imageQuality: 70,
                          );
                          if (img != null) {
                            final bytes = await img.readAsBytes();
                            setLocal(() => photoBytes = bytes);
                          }
                        },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Камера',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final img = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            imageQuality: 70,
                          );
                          if (img != null) {
                            final bytes = await img.readAsBytes();
                            setLocal(() => photoBytes = bytes);
                          }
                        },
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Галерея',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (photoBytes != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        photoBytes!,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  final idx =
                      store.drivers.indexWhere((d) => d['uid'] == driverId);
                  if (idx != -1) {
                    final number = numberCtrl.text.trim();
                    if (number.isNotEmpty) {
                      store.drivers[idx]['medExamNumber'] = number;
                    }
                    if (selectedDate != null) {
                      store.drivers[idx]['medExamDate'] =
                          selectedDate!.toIso8601String();
                    }
                    if (photoBytes != null) {
                      store.drivers[idx]['medExamPhotoUrl'] =
                          'data:image/jpeg;base64,${base64Encode(photoBytes!)}';
                    }
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }
}
