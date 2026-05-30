import 'package:flutter/material.dart';
import 'services/local_storage.dart';

/// Точка входа для приложения водителя (отдельная APK-сборка).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = LocalStorage();
  await storage.init();

  runApp(MaterialApp(
    title: 'Numino Driver',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0), brightness: Brightness.light),
      useMaterial3: true,
    ),
    home: DriverMainScreen(storage: storage),
  ));
}

class DriverMainScreen extends StatefulWidget {
  final LocalStorage storage;
  const DriverMainScreen({super.key, required this.storage});
  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Numino Driver')),
      body: const Center(
        child: Text('Приложение водителя\nв разработке', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: Colors.grey)),
      ),
    );
  }
}
