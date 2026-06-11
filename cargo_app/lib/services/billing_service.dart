import 'dart:convert';
import 'package:crypto/crypto.dart';

class BillingService {
  static const String _shopId = '';
  static const String _secretKey = '';

  static bool get isConfigured => _shopId.isNotEmpty;

  static String createPaymentUrl({
    required double amount,
    required String orderId,
    required String description,
    String? email,
  }) {
    if (!isConfigured) return '';
    final params = {
      'shopId': _shopId,
      'scid': _shopId,
      'sum': amount.toStringAsFixed(2),
      'customerNumber': email ?? 'user',
      'orderNumber': orderId,
      'orderDescription': description,
    };
    final qs = Uri(queryParameters: params).query;
    return 'https://yoomoney.ru/checkout/payments/v2/contract?$qs';
  }

  static bool verifyCallback(Map<String, String> params) {
    if (!isConfigured) return false;
    final hash = params['sha1_hash'];
    final toHash = '${params['notification_type']}&'
        '${params['operation_id']}&'
        '${params['amount']}&'
        '${params['datetime']}&'
        '${params['sender']}&'
        '${params['codepro']}&'
        '$_secretKey&'
        '${params['label']}';
    return hash == _sha1(toHash);
  }

  static String _sha1(String input) {
    return sha1.convert(utf8.encode(input)).toString();
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final int maxVehicles;
  final int trialDays;
  final String sticker;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.maxVehicles,
    this.trialDays = 30,
    this.sticker = '',
  });

  static const start = SubscriptionPlan(id: 'start', name: 'Старт', price: 990, maxVehicles: 2, sticker: '');
  static const business = SubscriptionPlan(id: 'business', name: 'Бизнес', price: 1990, maxVehicles: 5, sticker: 'Популярный');
  static const corp = SubscriptionPlan(id: 'corp', name: 'Корпоративный', price: 0, maxVehicles: 999, sticker: '');

  static const List<SubscriptionPlan> all = [start, business, corp];
}
