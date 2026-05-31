import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        routes: {'/': (_) => AuthGate(storage: storage)},
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Пробуем восстановить сохранённую сессию (после обновления страницы)
    final saved = widget.storage.loadCurrentUser();
    if (saved != null) {
      widget.storage.setCurrentUser(saved);
    }

    // Парсим URL параметры (переданы с лендинга: admin/index.html?role=...&email=...&name=...)
    if (saved == null) {
      final params = _parseQueryParams();
      if (params['role'] != null && params['email'] != null) {
        final email = params['email']!;
        final existingUser = widget.storage.findUserByEmail(email);
        final role = existingUser?['role'] ?? params['role'] ?? 'owner';
        final name = existingUser?['displayName'] ?? params['name'] ?? email.split('@').first;
        widget.storage.setCurrentUser({
          'uid': email, 'email': email, 'displayName': name, 'role': role,
        });
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  /// Надёжный парсинг параметров: на вебе через dart:html, нативно через Uri.
  Map<String, String> _parseQueryParams() {
    try {
      // Попытка через dart:html (работает на Flutter Web)
      // ignore: avoid_web_libraries_in_flutter
      final search = Uri.base.query;
      if (search.isNotEmpty) return Uri.splitQueryString(search);
    } catch (_) {}
    // Fallback: Uri.base.queryParameters
    try {
      final p = Uri.base.queryParameters;
      if (p.isNotEmpty) return Map<String, String>.from(p);
    } catch (_) {}
    return {};
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final user = widget.storage.currentUser;
    if (user != null) {
      final role = user['role'] ?? 'owner';
      if (role == 'admin' || role == 'superadmin') return SuperadminScreen(storage: widget.storage);
      return const OwnerDashboardScreen();
    }

    // Нет сессии:
    // Android — показываем RoleScreen (Владелец / Водитель)
    // Web — редирект на лендинг (админ заходит только через сайт)
    return RoleScreen(storage: widget.storage);
  }
}
