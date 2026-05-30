import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/salary_payment.dart';
import '../../models/salary_rule.dart';
import '../../models/demo_data.dart';
import '../../utils/constants.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});
  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  String? _selectedDriverId;
  SalaryRule? _rule;

  void _loadRule(String driverId) {
    _rule = DemoData.salaryRules.where((r) => r.driverId == driverId).firstOrNull;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final payments = DemoData.salaryPayments.where((p) => _selectedDriverId == null || p.driverId == _selectedDriverId).toList();
    final isWide = MediaQuery.of(context).size.width >= 800;

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      // Driver selector + rule card
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Водитель и правило', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedDriverId, decoration: const InputDecoration(labelText: 'Водитель', border: OutlineInputBorder()),
          items: DemoData.drivers.map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d['uid'] as String, child: Text(d['displayName'] as String))).toList(),
          onChanged: (v) { _selectedDriverId = v; if (v != null) _loadRule(v); },
        ),
        if (_rule != null) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text('Правило: ${_rule!.displayLabel}', style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ]))),
      const SizedBox(height: 16),
      // History
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('История расчётов', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        payments.isEmpty ? const Text('Нет данных') : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: payments.length, itemBuilder: (ctx, i) {
          final p = payments[i];
          return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
            leading: CircleAvatar(backgroundColor: p.status == SalaryPaymentStatus.paid ? Colors.green.shade100 : Colors.orange.shade100, child: Icon(p.status == SalaryPaymentStatus.paid ? Icons.check_circle : Icons.calculate, color: p.status == SalaryPaymentStatus.paid ? Colors.green : Colors.orange, size: 20)),
            title: Text('${p.calculatedSalary.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${_dateFormat.format(p.periodStart)} – ${_dateFormat.format(p.periodEnd)}\n${p.tripIds.length} рейсов, доход: ${p.totalIncome.toStringAsFixed(0)} ₽'),
            isThreeLine: true,
            trailing: Text(p.status == SalaryPaymentStatus.paid ? 'Выплачено' : 'Рассчитано', style: TextStyle(color: p.status == SalaryPaymentStatus.paid ? Colors.green : Colors.orange, fontSize: 11)),
          ));
        }),
      ]))),
    ]));
  }
}
