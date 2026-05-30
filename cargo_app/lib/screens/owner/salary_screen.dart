import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/salary_payment.dart';
import '../../services/local_storage.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});
  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  String? _driver;
  final _percentCtrl = TextEditingController();
  bool _usePercent = true;

  @override
  void dispose() { _percentCtrl.dispose(); super.dispose(); }

  void _calc(LocalStorage store) {
    if (_driver == null) return;
    final trips = store.trips.where((t) => t.driverId == _driver && t.status == TripStatus.completed).toList();
    if (trips.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет завершённых рейсов'))); return; }
    final income = trips.fold(0.0, (s, t) => s + (t.income ?? 0));
    final value = double.tryParse(_percentCtrl.text) ?? 15;
    final salary = (_usePercent ? income * value / 100 : trips.length * value).roundToDouble();
    store.addSalaryPayment(SalaryPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: 'local', driverId: _driver!, periodStart: DateTime.now().subtract(const Duration(days: 30)),
      periodEnd: DateTime.now(), tripIds: trips.map((t) => t.id).toList(),
      totalIncome: income, calculatedSalary: salary,
      ruleType: _usePercent ? SalaryRuleType.percent : SalaryRuleType.fixed,
      ruleValue: value, status: SalaryPaymentStatus.calculated,
      createdAt: DateTime.now(),
    ));
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Рассчитано: $salary ₽'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    final payments = _driver != null ? store.salaryPayments.where((p) => p.driverId == _driver).toList() : store.salaryPayments;
    final df = DateFormat('dd.MM.yyyy');

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Расчёт зарплаты', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: _driver, decoration: const InputDecoration(labelText: 'Водитель', border: OutlineInputBorder()),
          items: store.drivers.map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d['uid'], child: Text(d['displayName'] ?? d['uid'] ?? ''))).toList(),
          onChanged: (v) => setState(() => _driver = v)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _percentCtrl, decoration: InputDecoration(labelText: _usePercent ? 'Процент (%)' : 'Сумма за рейс (₽)', border: const OutlineInputBorder()), keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('%')), ButtonSegment(value: false, label: Text('₽'))], selected: {_usePercent}, onSelectionChanged: (v) => setState(() => _usePercent = v.first), style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _calc(store), child: const Text('Рассчитать зарплату'))),
      ]))),
      const SizedBox(height: 16),
      if (payments.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('История', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
        ...payments.map((p) => ListTile(
          leading: CircleAvatar(backgroundColor: p.status == SalaryPaymentStatus.paid ? Colors.green.shade100 : Colors.orange.shade100, child: Icon(p.status == SalaryPaymentStatus.paid ? Icons.check_circle : Icons.calculate, color: p.status == SalaryPaymentStatus.paid ? Colors.green : Colors.orange, size: 20)),
          title: Text('${p.calculatedSalary.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${df.format(p.periodStart)} – ${df.format(p.periodEnd)} • ${p.tripIds.length} рейсов'),
        )),
      ]))),
    ]));
  }
}
