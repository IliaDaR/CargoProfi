import '../utils/constants.dart';

class SalaryPayment {
  final String id;
  final String ownerId;
  final String driverId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<String> tripIds;
  final double totalIncome;
  final double calculatedSalary;
  final SalaryRuleType ruleType;
  final double ruleValue;
  final SalaryPaymentStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;

  SalaryPayment({
    required this.id,
    required this.ownerId,
    required this.driverId,
    required this.periodStart,
    required this.periodEnd,
    required this.tripIds,
    required this.totalIncome,
    required this.calculatedSalary,
    required this.ruleType,
    required this.ruleValue,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  factory SalaryPayment.fromMap(String id, Map<String, dynamic> data) {
    return SalaryPayment(
      id: id,
      ownerId: data['ownerId'] ?? '',
      driverId: data['driverId'] ?? '',
      periodStart: _parseDate(data['periodStart']),
      periodEnd: _parseDate(data['periodEnd']),
      tripIds: List<String>.from(data['tripIds'] ?? []),
      totalIncome: (data['totalIncome'] ?? 0.0).toDouble(),
      calculatedSalary: (data['calculatedSalary'] ?? 0.0).toDouble(),
      ruleType:
          data['ruleType'] == 'fixed' ? SalaryRuleType.fixed : SalaryRuleType.percent,
      ruleValue: (data['ruleValue'] ?? 0.0).toDouble(),
      status: _parseStatus(data['status'] ?? 'calculated'),
      createdAt: _parseDate(data['createdAt']),
      paidAt: data['paidAt'] != null ? _parseDate(data['paidAt']) : null,
    );
  }

  static SalaryPaymentStatus _parseStatus(String s) {
    switch (s) {
      case 'paid':
        return SalaryPaymentStatus.paid;
      case 'cancelled':
        return SalaryPaymentStatus.cancelled;
      default:
        return SalaryPaymentStatus.calculated;
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value != null) return (value as dynamic).toDate() as DateTime;
    return DateTime.now();
  }
}
