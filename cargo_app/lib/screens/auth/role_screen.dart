import 'package:flutter/material.dart';
import '../../services/local_storage.dart';

class RoleScreen extends StatelessWidget {
  final LocalStorage storage;
  const RoleScreen({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_shipping, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Numino', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Рабочий кабинет перевозчика', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 40),
          const Text('Войдите через сайт', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(width: 280, height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('numino.ru/login.html'),
            ),
          ),
        ]),
      ),
    );
  }
}
