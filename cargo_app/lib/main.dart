import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'screens/auth/role_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';
import 'screens/owner/superadmin_screen.dart';
import 'services/local_storage.dart';
import 'services/notification_service.dart';
import 'services/yandex_bridge.dart';
import 'providers/vehicle_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugPrint('FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('${details.stack}');
  };

  final local = LocalStorage();
  await local.init();
  await NotificationService.init();

  // Yandex Cloud — асинхронно, не блокирует запуск
  YandexBridge.instance.healthCheck().then((ok) {
    debugPrint('Yandex Cloud: ${ok ? "OK" : "unreachable"}');
  });

  runApp(CargoApp(local: local));
}

class CargoApp extends StatelessWidget {
  final LocalStorage local;
  const CargoApp({super.key, required this.local});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStorage>.value(value: local),
        ChangeNotifierProvider(create: (_) => VehicleProvider(local)),
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
        home: AuthGate(local: local),
        routes: {'/': (_) => AuthGate(local: local)},
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final LocalStorage local;
  const AuthGate({super.key, required this.local});

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
    final saved = widget.local.loadCurrentUser();
    if (saved != null) widget.local.setCurrentUser(saved);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final user = widget.local.currentUser;
    if (user != null) {
      final role = user['role'] ?? 'owner';
      if (role == 'admin' || role == 'superadmin') return SuperadminScreen(storage: widget.local);
      return const OwnerDashboardScreen();
    }

    return RoleScreen(storage: widget.local);
  }
}
