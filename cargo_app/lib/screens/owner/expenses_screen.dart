import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../models/demo_data.dart';
import '../../utils/constants.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  String? _selectedDriverId;
  List<Expense> _filtered = [];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final total = _filtered.fold(0.0, (s, e) => s + e.amount);
    final byCat = <String, double>{};
    for (final e in _filtered) { byCat[e.category.name] = (byCat[e.category.name] ?? 0) + e.amount; }

    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: isWide ? Row(children: _buildFilters()) : Wrap(spacing: 8, runSpacing: 8, children: _buildFilters())),
      if (_filtered.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Card(color: Colors.blue.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Text('Всего: ${total.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, children: byCat.entries.map((e) => Chip(avatar: Icon(_catIcon(e.key), size: 18), label: Text('${expenseCategoryLabel(expenseCategoryFromString(e.key))}: ${e.value.toStringAsFixed(0)} ₽'))).toList()),
      ])))),
      Expanded(child: _filtered.isEmpty
        ? const Center(child: Text('Выберите водителя для просмотра расходов'))
        : isWide ? _buildTable() : _buildList()),
    ]);
  }

  List<Widget> _buildFilters() {
    return [
      SizedBox(width: 220, child: DropdownButtonFormField<String>(
        value: _selectedDriverId, decoration: const InputDecoration(labelText: 'Водитель', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        items: DemoData.drivers.map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d['uid'] as String, child: Text(d['displayName'] as String))).toList(),
        onChanged: (v) { setState(() { _selectedDriverId = v; _filtered = DemoData.expenses.where((e) => e.driverId == v).toList(); }); },
      )),
    ];
  }

  Widget _buildTable() => SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(columns: const [
    DataColumn(label: Text('Дата')), DataColumn(label: Text('Категория')), DataColumn(label: Text('Сумма')), DataColumn(label: Text('Описание')),
  ], rows: _filtered.map((e) => DataRow(cells: [
    DataCell(Text(_dateFormat.format(e.createdAt))),
    DataCell(Text(expenseCategoryLabel(e.category))),
    DataCell(Text('${e.amount.toStringAsFixed(0)} ₽')),
    DataCell(Text(e.description ?? '—')),
  ])).toList())));

  Widget _buildList() => ListView.builder(itemCount: _filtered.length, itemBuilder: (ctx, i) {
    final e = _filtered[i];
    return Card(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: ListTile(
      leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: Icon(_catIcon(e.category.name), color: Colors.orange.shade700)),
      title: Text(expenseCategoryLabel(e.category)),
      subtitle: Text('${_dateFormat.format(e.createdAt)} — ${e.description ?? ''}'),
      trailing: Text('${e.amount.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
    ));
  });

  IconData _catIcon(String c) {
    switch (c) {
      case 'fuel': return Icons.local_gas_station;
      case 'parking': return Icons.local_parking;
      case 'repair': return Icons.build;
      case 'toll': return Icons.toll;
      case 'washing': return Icons.local_car_wash;
      default: return Icons.receipt;
    }
  }
}
