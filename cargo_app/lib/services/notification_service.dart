import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static SharedPreferences? _prefs;
  static const _kHistory = 'notifications_history';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'cargo_alerts',
          'Уведомления Numino',
          importance: Importance.high,
        ));
  }

  static Future<void> notify(String title, String body, {String? type}) async {
    _saveToHistory({
      'title': title,
      'body': body,
      'type': type ?? 'info',
      'time': DateTime.now().toIso8601String(),
    });
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cargo_alerts',
          'Уведомления Numino',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static void _saveToHistory(Map<String, dynamic> item) {
    final list = history;
    item['read'] = false;
    list.add(item);
    if (list.length > 50) list.removeRange(0, list.length - 50);
    _prefs?.setString(_kHistory, jsonEncode(list));
  }

  static List<Map<String, dynamic>> get history {
    try {
      final raw = _prefs?.getString(_kHistory);
      if (raw != null) {
        return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static List<Map<String, dynamic>> get all => history;

  static int get unreadCount =>
      history.where((n) => n['read'] != true).length;

  static void markAllRead() {
    final list = history;
    if (list.isEmpty) return;
    for (final n in list) {
      n['read'] = true;
    }
    _prefs?.setString(_kHistory, jsonEncode(list));
  }

  static void clear() {
    _prefs?.remove(_kHistory);
  }

  static void tripStarted(String driverName) =>
      notify('Рейс начат', 'Водитель $driverName начал рейс', type: 'trip');

  static void tripCompleted(double mileage, double? income) => notify(
        'Рейс завершён',
        'Пробег: ${mileage.toStringAsFixed(0)} км${income != null ? ', доход: ${income.toStringAsFixed(0)} ₽' : ''}',
        type: 'trip',
      );

  static void expenseAdded(String category, double amount) => notify(
        'Добавлен расход',
        '$category: ${amount.toStringAsFixed(0)} ₽',
        type: 'expense',
      );

  static void highExpense(String category, double amount) => notify(
        'Крупный расход',
        '$category: ${amount.toStringAsFixed(0)} ₽',
        type: 'warning',
      );

  static void movementDetected() => notify(
        'Обнаружено движение',
        'Не забудьте начать рейс',
        type: 'reminder',
      );

  static void carFreed(String plate) =>
      notify('Машина освобождена', 'Госномер: $plate', type: 'info');

  static void medExamReminder(String date) =>
      notify('Медосмотр', 'Срок медосмотра: $date', type: 'warning');
}
