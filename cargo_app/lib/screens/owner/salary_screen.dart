import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/salary_payment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/salary_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

/// Вкладка «Зарплата» для владельца.
/// Задание правил, расчёт за период, ведомость.
class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');

  String? _selectedDriverId;
  String _ruleType = 'percent';
  final _ruleValueCtrl = TextEditingController();

  DateTime _periodStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<SalaryProvider>().loadDrivers(auth.profile!.uid);
    });
  }

  @override
  void dispose() {
    _ruleValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRule() async {
    if (_selectedDriverId == null || _ruleValueCtrl.text.isEmpty) {
      AppWidgets.showError(context, 'Выберите водителя и укажите значение');
      return;
    }

    final value = double.tryParse(_ruleValueCtrl.text);
    if (value == null || value <= 0) {
      AppWidgets.showError(context, 'Введите корректное значение');
      return;
    }

    final ok = await context.read<SalaryProvider>().setSalaryRule(
      driverId: _selectedDriverId!,
      type: _ruleType,
      percentValue: _ruleType == 'percent' ? value : null,
      fixedValue: _ruleType == 'fixed' ? value : null,
    );

    if (ok && mounted) {
      AppWidgets.showSuccess(context, 'Правило сохранено');
      _loadRule();
    }
  }

  Future<void> _loadRule() async {
    if (_selectedDriverId == null) return;
    await context.read<SalaryProvider>().loadSalaryRule(_selectedDriverId!);
  }

  Future<void> _calculate() async {
    if (_selectedDriverId == null) {
      AppWidgets.showError(context, 'Выберите водителя');
      return;
    }

    final ok = await context.read<SalaryProvider>().calculateSalary(
      driverId: _selectedDriverId!,
      periodStart: DateFormat('yyyy-MM-dd').format(_periodStart),
      periodEnd: DateFormat('yyyy-MM-dd').format(_periodEnd),
    );

    if (ok && mounted) {
      AppWidgets.showSuccess(context, 'Зарплата рассчитана!');
      await context.read<SalaryProvider>().loadSalaryHistory(_selectedDriverId!);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _periodStart : _periodEnd,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _periodStart = picked;
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final salaryProvider = context.watch<SalaryProvider>();
    final isWide = MediaQuery.of(context).size.width >= 800;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: isWide ? _buildWideLayout(salaryProvider) : _buildNarrowLayout(salaryProvider),
    );
  }

  Widget _buildWideLayout(SalaryProvider salaryProvider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Левая колонка: правило и расчёт
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _buildRuleCard(salaryProvider),
              const SizedBox(height: 20),
              _buildCalculationCard(salaryProvider),
              const SizedBox(height: 20),
              _buildResultCard(salaryProvider),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Правая колонка: история выплат
        Expanded(
          flex: 3,
          child: _buildHistoryCard(salaryProvider),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(SalaryProvider salaryProvider) {
    return Column(
      children: [
        _buildRuleCard(salaryProvider),
        const SizedBox(height: 16),
        _buildCalculationCard(salaryProvider),
        const SizedBox(height: 16),
        _buildResultCard(salaryProvider),
        const SizedBox(height: 16),
        _buildHistoryCard(salaryProvider),
      ],
    );
  }

  // === Карточка правила зарплаты ===
  Widget _buildRuleCard(SalaryProvider salaryProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Правило начисления', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedDriverId,
              decoration: const InputDecoration(
                labelText: 'Водитель',
                border: OutlineInputBorder(),
              ),
              items: salaryProvider.drivers.map((d) {
                return DropdownMenuItem(
                  value: d['uid'],
                  child: Text(d['displayName'] ?? d['uid'] ?? ''),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _selectedDriverId = v);
                if (v != null) _loadRule();
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'percent', label: Text('% от дохода')),
                ButtonSegment(value: 'fixed', label: Text('Фикс за рейс')),
              ],
              selected: {_ruleType},
              onSelectionChanged: (v) => setState(() => _ruleType = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ruleValueCtrl,
              decoration: InputDecoration(
                labelText: _ruleType == 'percent' ? 'Процент (%)' : 'Сумма за рейс (₽)',
                border: const OutlineInputBorder(),
                suffixText: _ruleType == 'percent' ? '%' : '₽',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            if (salaryProvider.currentRule != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Текущее правило: ${salaryProvider.currentRule!.displayLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            AppWidgets.loadingButton(
              label: 'Сохранить правило',
              isLoading: salaryProvider.isLoading,
              onPressed: _saveRule,
            ),
          ],
        ),
      ),
    );
  }

  // === Карточка расчёта зарплаты ===
  Widget _buildCalculationCard(SalaryProvider salaryProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Расчёт зарплаты', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Начало периода',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_dateFormat.format(_periodStart)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Конец периода',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_dateFormat.format(_periodEnd)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppWidgets.loadingButton(
              label: 'Рассчитать зарплату',
              isLoading: salaryProvider.isLoading,
              onPressed: _calculate,
            ),
          ],
        ),
      ),
    );
  }

  // === Карточка результата расчёта ===
  Widget _buildResultCard(SalaryProvider salaryProvider) {
    if (salaryProvider.lastCalculation == null) return const SizedBox.shrink();

    final calc = salaryProvider.lastCalculation!;
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Результат расчёта', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green.shade800)),
            const SizedBox(height: 10),
            _resultRow('Период', '${_dateFormat.format(calc.periodStart)} – ${_dateFormat.format(calc.periodEnd)}'),
            _resultRow('Рейсов', '${calc.tripIds.length}'),
            _resultRow('Общий доход', '${calc.totalIncome.toStringAsFixed(0)} ₽'),
            _resultRow('Правило', calc.ruleType == SalaryRuleType.fixed
                ? 'Фикс ${calc.ruleValue.toStringAsFixed(0)} ₽/рейс'
                : '${calc.ruleValue.toStringAsFixed(0)}% от дохода'),
            const Divider(),
            _resultRow('К ВЫПЛАТЕ', '${calc.calculatedSalary.toStringAsFixed(0)} ₽',
              valueBold: true, valueSize: 18),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, {bool valueBold = false, double valueSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(
            fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
            fontSize: valueSize,
          )),
        ],
      ),
    );
  }

  // === История выплат ===
  Widget _buildHistoryCard(SalaryProvider salaryProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('История выплат', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            salaryProvider.payments.isEmpty
                ? const Text('Нет данных. Выполните расчёт.')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: salaryProvider.payments.length,
                    itemBuilder: (ctx, i) {
                      final p = salaryProvider.payments[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _paymentStatusColor(p.status).withOpacity(0.15),
                            child: Icon(_paymentStatusIcon(p.status),
                              color: _paymentStatusColor(p.status), size: 20),
                          ),
                          title: Text('${p.calculatedSalary.toStringAsFixed(0)} ₽',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${_dateFormat.format(p.periodStart)} – ${_dateFormat.format(p.periodEnd)}\n'
                            '${p.tripIds.length} рейсов, доход: ${p.totalIncome.toStringAsFixed(0)} ₽',
                          ),
                          isThreeLine: true,
                          trailing: Text(_paymentStatusLabel(p.status),
                            style: TextStyle(color: _paymentStatusColor(p.status), fontSize: 11)),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Color _paymentStatusColor(SalaryPaymentStatus s) {
    switch (s) {
      case SalaryPaymentStatus.calculated:
        return Colors.orange;
      case SalaryPaymentStatus.paid:
        return Colors.green;
      case SalaryPaymentStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _paymentStatusIcon(SalaryPaymentStatus s) {
    switch (s) {
      case SalaryPaymentStatus.calculated:
        return Icons.calculate;
      case SalaryPaymentStatus.paid:
        return Icons.check_circle;
      case SalaryPaymentStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _paymentStatusLabel(SalaryPaymentStatus s) {
    switch (s) {
      case SalaryPaymentStatus.calculated:
        return 'Рассчитано';
      case SalaryPaymentStatus.paid:
        return 'Выплачено';
      case SalaryPaymentStatus.cancelled:
        return 'Отменено';
    }
  }
}
