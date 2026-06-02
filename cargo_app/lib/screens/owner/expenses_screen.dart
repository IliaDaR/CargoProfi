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
  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now();

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(context: context, initialDate: isStart ? _start : _end, firstDate: DateTime(2023), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { if (isStart) _start = d; else _end = d; });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    var list = _driver != null ? store.expenses.where((e) => e.driverId == _driver).toList() : store.expenses;
    list = list.where((e) => e.createdAt.isAfter(_start.subtract(const Duration(days: 1))) && e.createdAt.isBefore(_end.add(const Duration(days: 1)))).toList();
    final total = list.fold(0.0, (s, e) => s + e.amount);
    final isWide = MediaQuery.of(context).size.width >= 800;
    final df = DateFormat('dd.MM.yyyy');

    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        DropdownButtonFormField<String>(
          value: _driver, decoration: const InputDecoration(labelText: 'Водитель', border: OutlineInputBorder(), isDense: true),
          items: store.drivers.map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d['uid'], child: Text(d['displayName'] ?? d['uid'] ?? ''))).toList(),
          onChanged: (v) => setState(() => _driver = v),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: InkWell(onTap: () => _pickDate(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'С', border: OutlineInputBorder(), isDense: true), child: Text(DateFormat('dd.MM').format(_start))))),
          const SizedBox(width: 8),
          Expanded(child: InkWell(onTap: () => _pickDate(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'По', border: OutlineInputBorder(), isDense: true), child: Text(DateFormat('dd.MM').format(_end))))),
        ]),
      ])),
      if (list.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(color: Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Всего: ${total.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.download, size: 20),
                tooltip: 'Экспорт CSV',
                onPressed: () => ExportService.downloadCsv('расходы.csv', ExportService.expensesToCsv(list)),
              ),
            ]),
            const SizedBox(height: 6),
            ..._byCategory(list).entries.map((e) => 
              Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
                Text(expenseCategoryLabel(expenseCategoryFromString(e.key)), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const Spacer(),
                Text('${e.value.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ])),
            ),
          ]))),
        ),
      ],      Expanded(child: list.isEmpty ? const Center(child: Text('Нет расходов')) : isWide ? _table(list, df) : _list(list, df)),
    ]);
  }

  Widget _table(List<Expense> list, DateFormat df) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
    DataColumn(label: Text('Дата')), DataColumn(label: Text('Категория')), DataColumn(label: Text('Сумма')), DataColumn(label: Text('Описание')), DataColumn(label: Text('Чек')),
  ], rows: list.map((e) => DataRow(cells: [
    DataCell(Text(df.format(e.createdAt))), DataCell(Text(expenseCategoryLabel(e.category))),
    DataCell(Text('${e.amount.toStringAsFixed(0)} ₽')), DataCell(Text(e.description ?? '—')),
    DataCell(_receiptThumb(e)),
  ])).toList()));

  Widget _list(List<Expense> list, DateFormat df) => ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) {
    final e = list[i];
    return Card(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: ListTile(
      leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: const Icon(Icons.receipt, color: Colors.orange)),
      title: Text(expenseCategoryLabel(e.category)), subtitle: Text('${df.format(e.createdAt)} — ${e.description ?? ''}'),
      trailing: Text('${e.amount.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
    ));
  });
}
