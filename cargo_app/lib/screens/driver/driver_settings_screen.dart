import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class DriverSettingsScreen extends StatelessWidget {
  const DriverSettingsScreen({super.key});

  static const _intervals = [30, 60, 120];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Тёмная тема'),
            value: settings.darkMode,
            onChanged: (v) => settings.setDarkMode(v),
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Интервал GPS',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ),
          ..._intervals.map(
            (interval) => RadioListTile<int>(
              title: Text('$interval сек'),
              value: interval,
              groupValue: settings.gpsInterval,
              onChanged: (v) {
                if (v != null) settings.setGpsInterval(v);
              },
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.language),
            title: Text('Язык'),
            subtitle: Text('Русский'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
