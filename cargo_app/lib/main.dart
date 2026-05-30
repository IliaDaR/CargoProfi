import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';
import 'screens/owner/superadmin_screen.dart';
import 'services/local_storage.dart';
import 'providers/vehicle_provider.dart';

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
        home: AuthGate(storage: storage),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final LocalStorage storage;
  const AuthGate({super.key, required this.storage});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;
  Map<String, String>? _session;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Пробуем получить сессию из URL hash (передана с лендинга)
    _session = _parseSession();
    if (_session != null) {
      // Авто-вход через сессию с сайта
      final role = _session!['role'] ?? 'owner';
      widget.storage.setCurrentUser({
        'uid': _session!['email'] ?? 'user',
        'email': _session!['email'] ?? '',
        'displayName': _session!['name'] ?? 'Пользователь',
        'role': role,
      });
    }
    if (mounted) setState(() => _ready = true);
  }

  Map<String, String>? _parseSession() {
    final params = Uri.base.queryParameters;
    if (params['role'] == null || params['email'] == null) return null;
    return {'role': params['role']!, 'email': params['email']!, 'name': params['name'] ?? params['email']!.split('@').first};
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final user = widget.storage.currentUser;
    if (user != null) {
      final role = user['role'] ?? 'owner';
      if (role == 'admin') return SuperadminScreen(storage: widget.storage);
      return const OwnerDashboardScreen();
    }

    // Нет сессии: экран выбора роли (только на Android, не на вебе)
    return RoleScreen(storage: widget.storage);
  }
}
