import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationService.all;
    final df = DateFormat('dd.MM HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (NotificationService.unreadCount > 0)
            TextButton(onPressed: () { NotificationService.markAllRead(); }, child: const Text('Прочитать всё')),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(child: Text('Нет уведомлений'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notifications.length,
              itemBuilder: (ctx, i) {
                final n = notifications[i];
                final time = DateTime.tryParse(n['time'] ?? '') ?? DateTime.now();
                final unread = n['read'] != true;
                return Card(
                  color: unread ? Colors.blue.shade50 : null,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: unread ? Colors.blue.shade100 : Colors.grey.shade100,
                      child: Text(_icon(n['type']), style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(n['title'] ?? '', style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('${n['body'] ?? ''}\n${df.format(time)}', maxLines: 3),
                  ),
                );
              },
            ),
    );
  }

  String _icon(String? type) {
    switch (type) {
      case 'trip_start': return '🚛';
      case 'trip_end': return '✅';
      case 'warning': return '⚠️';
      case 'maintenance': return '🔧';
      default: return '📢';
    }
  }
}
