import '../utils/constants.dart';

class SalaryRule {
  final String id;
  final String ownerId;
  final String driverId;
  final SalaryRuleType type;
  final double? percentValue;
  final double? fixedValue;
  final bool isActive;
  final DateTime createdAt;

  SalaryRule({
    required this.id,
    required this.ownerId,
    required this.driverId,
    required this.type,
    this.percentValue,
    this.fixedValue,
    required this.isActive,
    required this.createdAt,
  });

  factory SalaryRule.fromMap(String id, Map<String, dynamic> data) {
    return SalaryRule(
      id: id,
      ownerId: data['ownerId'] ?? '',
      driverId: data['driverId'] ?? '',
      type: data['type'] == 'fixed' ? SalaryRuleType.fixed : SalaryRuleType.percent,
      percentValue: data['percentValue']?.toDouble(),
      fixedValue: data['fixedValue']?.toDouble(),
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  double get displayValue {
    if (type == SalaryRuleType.percent) {
      return percentValue ?? 0;
    }
    return fixedValue ?? 0;
  }

  String get displayLabel {
    if (type == SalaryRuleType.percent) {
      return '${(percentValue ?? 0).toStringAsFixed(0)}% от дохода';
    }
    return '${(fixedValue ?? 0).toStringAsFixed(0)} ₽ за рейс';
  }
}
