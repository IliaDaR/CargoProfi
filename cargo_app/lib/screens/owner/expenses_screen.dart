import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/salary_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

/// Вкладка «Расходы» для владельца.
/// Сводная таблица с фото чеков, фильтрация по водителю и периоду.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');

  String? _selectedDriverId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<SalaryProvider>().loadDrivers(auth.profile!.uid);
    });
  }

  Future<void> _loadReport() async {
    if (_selectedDriverId == null) return;

    await context.read<ExpenseProvider>().loadDriverExpensesReport(
      driverId: _selectedDriverId!,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final salaryProvider = context.watch<SalaryProvider>();
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Column(
      children: [
        // Фильтры
        Padding(
          padding: const EdgeInsets.all(12),
          child: isWide
              ? Row(
                  children: [..._buildFilters()],
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [..._buildFilters()],
                ),
        ),

        // Сумма по категориям
        if (expenseProvider.expenses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text('Всего: ${expenseProvider.total.toStringAsFixed(0)} ₽',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: expenseProvider.expensesByCategory.entries.map((e) {
                        return Chip(
                          avatar: Icon(_categoryIcon(e.key), size: 18),
                          label: Text('${expenseCategoryLabel(expenseCategoryFromString(e.key))}: ${e.value.toStringAsFixed(0)} ₽'),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Таблица расходов
        Expanded(
          child: expenseProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : expenseProvider.expenses.isEmpty
                  ? const Center(child: Text('Выберите водителя и период для загрузки отчёта'))
                  : _buildTable(expenseProvider.expenses, isWide),
        ),
      ],
    );
  }

  List<Widget> _buildFilters() {
    final salaryProvider = context.read<SalaryProvider>();

    return [
      SizedBox(
        width: 200,
        child: DropdownButtonFormField<String>(
          value: _selectedDriverId,
          decoration: const InputDecoration(
            labelText: 'Водитель',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: salaryProvider.drivers.map((d) {
            return DropdownMenuItem(
              value: d['uid'],
              child: Text(d['displayName'] ?? d['uid'] ?? '', overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (v) {
            setState(() => _selectedDriverId = v);
            _loadReport();
          },
        ),
      ),
      const SizedBox(width: 8),
      InkWell(
        onTap: () => _pickDate(true),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'С',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          child: Text(_dateFormat.format(_startDate)),
        ),
      ),
      const SizedBox(width: 8),
      InkWell(
        onTap: () => _pickDate(false),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'По',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          child: Text(_dateFormat.format(_endDate)),
        ),
      ),
    ];
  }

  Widget _buildTable(List<Expense> expenses, bool isWide) {
    if (isWide) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Дата')),
              DataColumn(label: Text('Категория')),
              DataColumn(label: Text('Сумма')),
              DataColumn(label: Text('Описание')),
              DataColumn(label: Text('Чек')),
            ],
            rows: expenses.map((e) {
              return DataRow(cells: [
                DataCell(Text(_dateFormat.format(e.createdAt))),
                DataCell(Text(expenseCategoryLabel(e.category))),
                DataCell(Text('${e.amount.toStringAsFixed(0)} ₽')),
                DataCell(Text(e.description ?? '—', maxLines: 2)),
                DataCell(
                  e.receiptUrl != null
                      ? IconButton(
                          icon: const Icon(Icons.image, color: Colors.blue),
                          onPressed: () => launchUrl(Uri.parse(e.receiptUrl!), mode: LaunchMode.externalApplication),
                          tooltip: 'Открыть чек',
                        )
                      : const Text('—'),
                ),
              ]);
            }).toList(),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (ctx, i) {
        final e = expenses[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(_categoryIcon(e.category.name), color: Colors.orange.shade700),
            ),
            title: Text(expenseCategoryLabel(e.category)),
            subtitle: Text('${_dateFormat.format(e.createdAt)}${e.description != null ? ' — ${e.description}' : ''}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${e.amount.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (e.receiptUrl != null)
                  GestureDetector(
                    onTap: () => launchUrl(Uri.parse(e.receiptUrl!), mode: LaunchMode.externalApplication),
                    child: const Text('📷 чек', style: TextStyle(fontSize: 11, color: Colors.blue)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'fuel': return Icons.local_gas_station;
      case 'parking': return Icons.local_parking;
      case 'repair': return Icons.build;
      case 'toll': return Icons.toll;
      case 'washing': return Icons.local_car_wash;
      case 'tires': return Icons.tire_repair;
      case 'insurance': return Icons.verified_user;
      default: return Icons.receipt;
    }
  }
}
