import '../utils/constants.dart';

class Expense {
  final String id;
  final String tripId;
  final String driverId;
  final double amount;
  final ExpenseCategory category;
  final String? description;
  final String? receiptUrl;
  final double latitude;
  final double longitude;
  final DateTime photoTimestamp;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.amount,
    required this.category,
    this.description,
    this.receiptUrl,
    required this.latitude,
    required this.longitude,
    required this.photoTimestamp,
    required this.createdAt,
  });

  factory Expense.fromMap(String id, Map<String, dynamic> data) {
    return Expense(
      id: id,
      tripId: data['tripId'] ?? '',
      driverId: data['driverId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      category: expenseCategoryFromString(data['category'] ?? 'other'),
      description: data['description'],
      receiptUrl: data['receiptUrl'],
      latitude: (data['location']?['latitude'] ?? 0.0).toDouble(),
      longitude: (data['location']?['longitude'] ?? 0.0).toDouble(),
      photoTimestamp: (data['photoTimestamp'] as dynamic).toDate(),
      createdAt: (data['createdAt'] as dynamic).toDate(),
    );
  }
}
