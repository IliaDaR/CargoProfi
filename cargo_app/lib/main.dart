import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/local_storage.dart';
import 'providers/auth_provider.dart';
import 'providers/vehicle_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';
import 'screens/owner/superadmin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = LocalStorage();
  await storage.init();
  runApp(CargoApp(storage: storage));
}

class CargoApp extends StatelessWidget {
  final LocalStorage storage;
  const CargoApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStorage>.value(value: storage),
        ChangeNotifierProvider(create: (_) => AuthProvider(storage)),
        ChangeNotifierProvider(create: (_) => VehicleProvider(storage)),
      ],
      child: MaterialApp(
        title: 'Numino',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0), brightness: Brightness.light),
          useMaterial3: true,
          cardTheme: CardThemeData(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    auth.checkSavedSession();
    // Демо-режим: если нет сессии — авто-вход
    if (!auth.isLoggedIn) {
      await Future.delayed(const Duration(milliseconds: 200));
      auth.loginDemo();
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final auth = context.watch<AuthProvider>();
    final storage = context.read<LocalStorage>();
    if (!auth.isLoggedIn) return const LoginScreen();
    if (auth.isSuperadmin) return SuperadminScreen(storage: storage);
    if (auth.isOwner) return const OwnerDashboardScreen();
    return const LoginScreen();
  }
}
