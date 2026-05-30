import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/salary_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';

// Генерируется командой: flutterfire configure
// Затем раскомментируй import и DefaultFirebaseOptions
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase будет инициализирован лениво при первом обращении.
  // Для полноценной работы выполни: flutterfire configure
  // и раскомментируй строки ниже.
  //
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(const CargoApp());
}

class CargoApp extends StatelessWidget {
  const CargoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => VehicleProvider()),
        ChangeNotifierProvider(create: (_) => SalaryProvider()),
      ],
      child: MaterialApp(
        title: 'Numino',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Экран ошибки при невозможности подключиться к Firebase.
class FirebaseErrorScreen extends StatelessWidget {
  final String error;
  const FirebaseErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                'Firebase не настроен',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Выполните команду:\nflutterfire configure\n\nи пересоберите приложение.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error.length > 200 ? '${error.substring(0, 200)}...' : error,
                  style: const TextStyle(fontSize: 12, color: Colors.red, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    await auth.initialize();
    // Демо-режим: если нет профиля — создаём и переходим сразу в дашборд
    if (!auth.isLoggedIn) {
      auth.loginDemo();
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (auth.isOwner) {
      return const OwnerDashboardScreen();
    }

    return const DriverHomeScreen();
  }
}
