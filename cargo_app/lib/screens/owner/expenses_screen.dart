import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/expense.dart';
import '../../utils/constants.dart';
import '../../services/local_storage.dart';
import '../../services/export_service.dart';

Map<String, double> _byCategory(List<Expense> list) {
  final m = <String, double>{};
  for (final e in list) { m[e.category.name] = (m[e.category.name] ?? 0) + e.amount; }
  return m;
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _driver;
  int _pageSize = 20;
  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now();

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(context: context, initialDate: isStart ? _start : _end, firstDate: DateTime(2023), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { if (isStart) _start = d; else _end = d; });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    var fullList = _driver != null ? store.expenses.where((e) => e.driverId == _driver).toList() : store.expenses;
    fullList = fullList.where((e) => e.createdAt.isAfter(_start.subtract(const Duration(days: 1))) && e.createdAt.isBefore(_end.add(const Duration(days: 1)))).toList();
    final totalCount = fullList.length;
    final total = fullList.fold(0.0, (s, e) => s + e.amount);
    final list = fullList.take(_pageSize).toList();
    final df = DateFormat('dd.MM.yyyy');

    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        DropdownButtonFormField<String>(value: _driver, decoration: const InputDecoration(labelText: 'Водитель', border: OutlineInputBorder(), isDense: true),
          items: store.drivers.map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d['uid'], child: Text(d['displayName'] ?? d['uid'] ?? ''))).toList(),
          onChanged: (v) => setState(() => _driver = v)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: InkWell(onTap: () => _pickDate(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'С', border: OutlineInputBorder(), isDense: true), child: Text(DateFormat('dd.MM').format(_start))))),
          const SizedBox(width: 8),
          Expanded(child: InkWell(onTap: () => _pickDate(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'По', border: OutlineInputBorder(), isDense: true), child: Text(DateFormat('dd.MM').format(_end))))),
        ]),
      ])),
      if (list.isNotEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Card(color: Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Всего: ${total.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.download, size: 20), tooltip: 'Экспорт CSV', onPressed: () => ExportService.downloadCsv('расходы.csv', ExportService.expensesToCsv(list))),
          ]),
          const SizedBox(height: 6),
          ..._byCategory(list).entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
            Text(expenseCategoryLabel(expenseCategoryFromString(e.key)), style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const Spacer(), Text('${e.value.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ]))),
        ]))),
      Expanded(child: Column(children: [
        Expanded(child: list.isEmpty ? const Center(child: Text('Нет расходов')) : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
          DataColumn(label: Text('Дата')), DataColumn(label: Text('Категория')), DataColumn(label: Text('Сумма')), DataColumn(label: Text('Описание')), DataColumn(label: Text('Чек')), DataColumn(label: Text('')),
        ], rows: list.map((e) => DataRow(cells: [
          DataCell(Text(df.format(e.createdAt))), DataCell(Text(expenseCategoryLabel(e.category))),
          DataCell(Text('${e.amount.toStringAsFixed(0)} ₽')), DataCell(Text(e.description ?? '—')),
          DataCell(_buildReceipt(e)),
          DataCell(IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onPressed: () => _deleteExpense(e.id))),
        ])).toList()))),
        if (totalCount > _pageSize)
          Padding(padding: const EdgeInsets.all(8), child: TextButton(onPressed: () => setState(() => _pageSize += 20), child: Text('Показать ещё ($_pageSize из $totalCount)'))),
      ])),
    ]);
  }

  void _deleteExpense(String id) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Удалить расход?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          context.read<LocalStorage>().expenses.removeWhere((e) => e.id == id);
          Navigator.pop(ctx);
          setState(() {});
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Удалить')),
      ],
    ));
  }

  Widget _buildReceipt(Expense e) {
    if (e.receiptUrl == null || e.receiptUrl!.isEmpty) return const Text('—');
    final isBase64 = e.receiptUrl!.startsWith('data:');
    return GestureDetector(
      onTap: () {
        showDialog(context: context, builder: (_) => Dialog(
          child: isBase64
              ? Image.memory(base64Decode(e.receiptUrl!.split(',').last), fit: BoxFit.contain)
              : Image.network(e.receiptUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48)),
        ));
      },
      child: ClipRRect(borderRadius: BorderRadius.circular(4), child: isBase64
        ? Image.memory(base64Decode(e.receiptUrl!.split(',').last), width: 40, height: 40, fit: BoxFit.cover)
        : Image.network(e.receiptUrl!, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20)),
      ),
    );
  }
}
