import 'package:flutter/material.dart';
import 'services/local_storage.dart';
import 'services/cloud_functions_service.dart';
import 'screens/driver/driver_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = LocalStorage();
  await storage.init();
  final cloudFn = CloudFunctionsService(storage);

  runApp(MaterialApp(
    title: 'Numino Driver',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0), brightness: Brightness.light),
      useMaterial3: true,
    ),
    home: DriverLoginScreen(storage: storage, cloudFn: cloudFn),
  ));
}