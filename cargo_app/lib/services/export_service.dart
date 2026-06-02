import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/salary_payment.dart';

class ExportService {
  static final df = DateFormat('dd.MM.yyyy');

  /// CSV расходов
  static Uint8List expensesToCsv(List<Expense> list) {
    final buf = StringBuffer();
    buf.writeln('Дата,Категория,Сумма,Описание');
    for (final e in list) {
      buf.writeln('${df.format(e.createdAt)},"${categoryLabel(e.category.name)}",${e.amount},"${e.description ?? ''}"');
    }
    return Uint8List.fromList(utf8.encode('\uFEFF${buf.toString()}')); // BOM for Excel
  }

  /// CSV зарплатной ведомости
  static Uint8List salaryToCsv(List<SalaryPayment> list) {
    final buf = StringBuffer();
    buf.writeln('Период с,Период по,Рейсов,Доход,Зарплата,Правило,Статус');
    for (final p in list) {
      final rule = p.ruleType.name == 'percent' ? '${p.ruleValue}%' : '${p.ruleValue} ₽';
      final status = p.status.name == 'paid' ? 'Оплачено' : p.status.name == 'cancelled' ? 'Отменено' : 'Рассчитано';
      buf.writeln('${df.format(p.periodStart)},${df.format(p.periodEnd)},${p.tripIds.length},${p.totalIncome},${p.calculatedSalary},$rule,$status');
    }
    return Uint8List.fromList(utf8.encode('\uFEFF${buf.toString()}'));
  }

  static String categoryLabel(String c) {
    switch (c) {
      case 'fuel': return 'Топливо';
      case 'parking': return 'Стоянка';
      case 'repair': return 'Ремонт';
      case 'toll': return 'Дорожный сбор';
      case 'washing': return 'Мойка';
      case 'tires': return 'Шины';
      case 'insurance': return 'Страховка';
      default: return 'Прочее';
    }
  }
}
