import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/expense.dart';
import '../../utils/constants.dart';
import '../../services/local_storage.dart';
import '../../utils/constants.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _driver;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    final list = _driver != null ? store.expenses.where((e) => e.driverId == _driver).toList() : store.expenses;
    final total = list.fold(0.0, (s, e) => s + e.amount);
    final isWide = MediaQuery.of(context).size.width >= 800;
    final df = DateFormat('dd.MM.yyyy');

    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: DropdownButtonFormField<String>(
        value: _driver, decoration: const InputDecoration(labelText: 'Водитель', border: OutlineInputBorder(), isDense: true),
        items: store.drivers.map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d['uid'], child: Text(d['displayName'] ?? d['uid'] ?? ''))).toList(),
        onChanged: (v) => setState(() => _driver = v),
      )),
      if (list.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Card(color: Colors.green.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Text('Всего: ${total.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])))),
      Expanded(child: list.isEmpty ? const Center(child: Text('Выберите водителя')) : isWide ? _table(list, df) : _list(list, df)),
    ]);
  }

  Widget _table(List<Expense> list, DateFormat df) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
    DataColumn(label: Text('Дата')), DataColumn(label: Text('Категория')), DataColumn(label: Text('Сумма')), DataColumn(label: Text('Описание')),
  ], rows: list.map((e) => DataRow(cells: [
    DataCell(Text(df.format(e.createdAt))), DataCell(Text(expenseCategoryLabel(e.category))),
    DataCell(Text('${e.amount.toStringAsFixed(0)} ₽')), DataCell(Text(e.description ?? '—')),
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
