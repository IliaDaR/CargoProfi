import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/role_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';
import 'screens/owner/superadmin_screen.dart';
import 'services/local_storage.dart';
import 'services/data_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/notification_service.dart';
import 'providers/vehicle_provider.dart';

// Генерируется командой: flutterfire configure
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase
  try {
    await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (_) {
    // Firebase недоступен — работаем офлайн через LocalStorage
  }

  final local = LocalStorage();
  await local.init();
  await NotificationService.init();
  final data = DataService(local);
  final fireAuth = FirebaseAuthService();

  runApp(CargoApp(local: local, data: data, fireAuth: fireAuth));
}

class CargoApp extends StatelessWidget {
  final LocalStorage local;
  final DataService data;
  final FirebaseAuthService fireAuth;
  const CargoApp({super.key, required this.local, required this.data, required this.fireAuth});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStorage>.value(value: local),
        Provider<DataService>.value(value: data),
        Provider<FirebaseAuthService>.value(value: fireAuth),
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
        home: AuthGate(local: local, data: data, fireAuth: fireAuth),
        routes: {'/': (_) => AuthGate(local: local, data: data, fireAuth: fireAuth)},
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final LocalStorage local;
  final DataService data;
  final FirebaseAuthService fireAuth;
  const AuthGate({super.key, required this.local, required this.data, required this.fireAuth});

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
    // Сначала пробуем восстановить сохранённую сессию
    final saved = widget.local.loadCurrentUser();
    if (saved != null) {
      widget.local.setCurrentUser(saved);
    }

    // Затем пробуем спарсить URL-параметры (переданы с лендинга)
    if (saved == null) {
      final params = _parseQueryParams();
      if (params['role'] != null && params['email'] != null) {
        final email = params['email']!;
        final existing = widget.local.findUserByEmail(email);
        final role = existing?['role'] ?? params['role'] ?? 'owner';
        final name = existing?['displayName'] ?? params['name'] ?? email.split('@').first;
        widget.local.setCurrentUser({
          'uid': email, 'email': email, 'displayName': name, 'role': role,
        });
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  Map<String, String> _parseQueryParams() {
    try {
      final search = Uri.base.query;
      if (search.isNotEmpty) return Uri.splitQueryString(search);
    } catch (_) {}
    try {
      final p = Uri.base.queryParameters;
      if (p.isNotEmpty) return Map<String, String>.from(p);
    } catch (_) {}
    return {};
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

    return RoleScreen(storage: widget.local, fireAuth: widget.fireAuth);
  }
}
