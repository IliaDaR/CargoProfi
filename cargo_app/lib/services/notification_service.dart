import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../models/expense.dart';

/// Система уведомлений: сохраняет события локально,
/// показывает в дашборде владельца и водителя.
class NotificationService {
  static const _kNotifications = 'notifications';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static List<Map<String, dynamic>> get all {
    final raw = _prefs?.getString(_kNotifications);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
  }

  static List<Map<String, dynamic>> get unread => all.where((n) => n['read'] != true).toList();

  static int get unreadCount => unread.length;

  static void _save(List<Map<String, dynamic>> list) {
    _prefs?.setString(_kNotifications, jsonEncode(list));
  }

  static void add(String title, String body, {String? type}) {
    final list = all;
    list.insert(0, {
      'title': title,
      'body': body,
      'type': type ?? 'info',
      'time': DateTime.now().toIso8601String(),
      'read': false,
    });
    // Оставляем только последние 50
    if (list.length > 50) list.removeRange(50, list.length);
    _save(list);
  }

  static void markAllRead() {
    final list = all;
    for (var n in list) { n['read'] = true; }
    _save(list);
  }

  static void clear() {
    _prefs?.remove(_kNotifications);
  }

  // ===== Автоматические уведомления =====

  /// Рейс начат
  static void tripStarted(Trip trip, String driverName) {
    add('🚛 Рейс начат', '$driverName начал рейс: ${trip.routeDescription ?? "без маршрута"}', type: 'trip_start');
  }

  /// Рейс завершён
  static void tripCompleted(Trip trip, String driverName) {
    add('✅ Рейс завершён', '$driverName завершил рейс. Пробег: ${trip.mileage.toStringAsFixed(1)} км, доход: ${trip.income?.toStringAsFixed(0) ?? 0} ₽', type: 'trip_end');
  }

  /// Превышение расхода (> 10 000 ₽)
  static void highExpense(Expense expense, String driverName) {
    if (expense.amount >= 10000) {
      add('⚠️ Крупный расход', '$driverName: ${expense.amount.toStringAsFixed(0)} ₽ (${expense.description ?? "без описания"})', type: 'warning');
    }
  }

  /// Напоминание о ТО
  static void maintenanceReminder(String plateNumber, double mileage) {
    if (mileage > 0 && mileage % 10000 < 100) {
      add('🔧 ТО: $plateNumber', 'Пробег $mileage км — пора на техобслуживание', type: 'maintenance');
    }
  }
}
