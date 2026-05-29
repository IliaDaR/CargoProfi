import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

/// Экран добавления расхода во время рейса.
class AddExpenseScreen extends StatefulWidget {
  final String tripId;
  const AddExpenseScreen({super.key, required this.tripId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.fuel;
  File? _receiptFile;
  bool _isSaving = false;

  final _firestore = FirestoreService();
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, maxWidth: 1600);
    if (image != null) {
      setState(() => _receiptFile = File(image.path));
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Камера'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Галерея'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Получаем текущие GPS-координаты
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } catch (_) {}

      // Загружаем чек в Storage (если есть фото)
      String? receiptUrl;
      if (_receiptFile != null) {
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        receiptUrl = await _firestore.uploadReceipt(_receiptFile!, tempId);
      }

      // Создаём расход через Cloud Function
      await _firestore.addExpense(
        tripId: widget.tripId,
        amount: double.parse(_amountCtrl.text),
        category: _selectedCategory.name,
        latitude: position?.latitude,
        longitude: position?.longitude,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        receiptUrl: receiptUrl,
      );

      if (mounted) {
        AppWidgets.showSuccess(context, 'Расход добавлен!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppWidgets.showError(context, 'Ошибка: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить расход')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Категория
              DropdownButtonFormField<ExpenseCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: ExpenseCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(expenseCategoryLabel(cat)),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 14),

              // Сумма
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Сумма',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                  suffixText: '₽',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите сумму';
                  if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Некорректная сумма';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Описание
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Описание (опционально)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Фото чека
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showImageSourceDialog,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(_receiptFile != null ? 'Фото выбрано' : 'Фото чека'),
                    ),
                  ),
                  if (_receiptFile != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _receiptFile = null),
                      icon: const Icon(Icons.close, color: Colors.red),
                    ),
                  ],
                ],
              ),
              if (_receiptFile != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_receiptFile!, height: 150, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 24),

              // Кнопка сохранения
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить расход', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
