import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/salary_payment.dart';
import '../../models/salary_rule.dart';
import '../../models/trip.dart';
import '../../utils/constants.dart';
import '../../services/local_storage.dart';
import '../../services/export_service.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});
  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  String? _driver;
  bool _usePercent = true;
  bool _calculating = false;
  final _valueCtrl = TextEditingController(text: '15');
  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now();

  String get _ownerId => context.read<LocalStorage>().currentUser?['uid'] ?? 'local';

  @override
  void dispose() { _valueCtrl.dispose(); super.dispose(); }

  void _loadRule(LocalStorage store) {
    if (_driver == null) return;
    final rule = store.salaryRules.where((r) => r.driverId == _driver && r.isActive).firstOrNull;
    if (rule != null) {
      _usePercent = rule.type == SalaryRuleType.percent;
      _valueCtrl.text = (rule.type == SalaryRuleType.percent ? rule.percentValue : rule.fixedValue)?.toStringAsFixed(0) ?? '15';
      setState(() {});
    }
  }

  void _calc(LocalStorage store) async {
    if (_driver == null) return;
    if (_calculating) return;
    setState(() => _calculating = true);

    final trips = store.trips.where((t) => t.driverId == _driver && t.status == TripStatus.completed && t.startTime.isAfter(_start) && t.startTime.isBefore(_end)).toList();
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет завершённых рейсов за период')));
      setState(() => _calculating = false);
      return;
    }
    final income = trips.fold(0.0, (s, t) => s + (t.income ?? 0));
    final value = double.tryParse(_valueCtrl.text) ?? 15;
    final salary = (_usePercent ? income * value / 100 : trips.length * value).roundToDouble();

    // Удаляем старые правила для этого водителя, сохраняем новое
    store.salaryRules.removeWhere((r) => r.driverId == _driver);
    store.addSalaryRule(SalaryRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(), ownerId: _ownerId, driverId: _driver!,
      type: _usePercent ? SalaryRuleType.percent : SalaryRuleType.fixed,
      percentValue: _usePercent ? value : null, fixedValue: _usePercent ? null : value,
      isActive: true, createdAt: DateTime.now(),
    ));

    store.addSalaryPayment(SalaryPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(), ownerId: _ownerId, driverId: _driver!,
      periodStart: _start, periodEnd: _end, tripIds: trips.map((t) => t.id).toList(),
      totalIncome: income, calculatedSalary: salary,
      ruleType: _usePercent ? SalaryRuleType.percent : SalaryRuleType.fixed,
      ruleValue: value, status: SalaryPaymentStatus.calculated, createdAt: DateTime.now(),
    ));
    setState(() { _calculating = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Рассчитано: $salary ₽'), backgroundColor: Colors.green));
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(context: context, initialDate: isStart ? _start : _end, firstDate: DateTime(2023), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d != null) setState(() { if (isStart) _start = d; else _end = d; });
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
          onChanged: (v) { setState(() => _driver = v); if (v != null) _loadRule(store); }),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: InkWell(onTap: () => _pickDate(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'Начало', border: OutlineInputBorder()), child: Text(df.format(_start))))),
          const SizedBox(width: 10),
          Expanded(child: InkWell(onTap: () => _pickDate(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'Конец', border: OutlineInputBorder()), child: Text(df.format(_end))))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _valueCtrl, decoration: InputDecoration(labelText: _usePercent ? 'Процент (%)' : 'Сумма за рейс (₽)', border: const OutlineInputBorder()), keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('%')), ButtonSegment(value: false, label: Text('₽'))], selected: {_usePercent}, onSelectionChanged: (v) => setState(() => _usePercent = v.first), style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _calculating ? null : () => _calc(store), child: _calculating ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Рассчитать зарплату'))),
      ]))),
      const SizedBox(height: 16),
      if (payments.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('История', style: Theme.of(context).textTheme.titleMedium),
        if (payments.isNotEmpty)
          TextButton.icon(onPressed: () {
            ExportService.downloadCsv('зарплата.csv', ExportService.salaryToCsv(payments));
          }, icon: const Icon(Icons.download, size: 16), label: const Text('CSV')),
        const SizedBox(height: 8),
        ...payments.reversed.map((p) => ListTile(
          leading: CircleAvatar(backgroundColor: p.status == SalaryPaymentStatus.paid ? Colors.green.shade100 : p.status == SalaryPaymentStatus.cancelled ? Colors.red.shade100 : Colors.orange.shade100, child: Icon(p.status == SalaryPaymentStatus.paid ? Icons.check_circle : p.status == SalaryPaymentStatus.cancelled ? Icons.cancel : Icons.calculate, color: p.status == SalaryPaymentStatus.paid ? Colors.green : p.status == SalaryPaymentStatus.cancelled ? Colors.red : Colors.orange, size: 20)),
          title: Text('${p.calculatedSalary.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${df.format(p.periodStart)} – ${df.format(p.periodEnd)} • ${p.tripIds.length} рейсов'),
          trailing: p.status == SalaryPaymentStatus.calculated ? PopupMenuButton<String>(
            itemBuilder: (_) => [const PopupMenuItem(value: 'paid', child: Text('Оплачено')), const PopupMenuItem(value: 'cancelled', child: Text('Отменить'))],
            onSelected: (v) { setState(() {
              final idx = store.salaryPayments.indexOf(p);
              if (idx >= 0) { store.salaryPayments[idx] = SalaryPayment(id: p.id, ownerId: p.ownerId, driverId: p.driverId, periodStart: p.periodStart, periodEnd: p.periodEnd, tripIds: p.tripIds, totalIncome: p.totalIncome, calculatedSalary: p.calculatedSalary, ruleType: p.ruleType, ruleValue: p.ruleValue, status: v == 'paid' ? SalaryPaymentStatus.paid : SalaryPaymentStatus.cancelled, createdAt: p.createdAt); }
              store.saveSalaryPayments();
            }); },
          ) : Text(p.status == SalaryPaymentStatus.paid ? 'Оплачено' : 'Отменено', style: TextStyle(color: p.status == SalaryPaymentStatus.paid ? Colors.green : Colors.red, fontSize: 11)),
        )),
      ]))),
    ]));
  }
}
