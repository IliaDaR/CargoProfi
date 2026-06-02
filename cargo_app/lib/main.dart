import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/role_screen.dart';
import 'screens/owner/owner_dashboard_screen.dart';
import 'screens/owner/superadmin_screen.dart';
import 'services/local_storage.dart';
import 'services/data_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/cloud_functions_service.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';
import 'providers/vehicle_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (_) {
    // Firebase недоступен — работаем офлайн через LocalStorage
  }

  final local = LocalStorage();
  await local.init();
  final data = DataService(local);
  final fireAuth = FirebaseAuthService();
  final cloudFn = CloudFunctionsService(local);
  await NotificationService.init();

  runApp(CargoApp(local: local, data: data, fireAuth: fireAuth, cloudFn: cloudFn));
}

class CargoApp extends StatelessWidget {
  final LocalStorage local;
  final DataService data;
  final FirebaseAuthService fireAuth;
  final CloudFunctionsService cloudFn;
  const CargoApp({super.key, required this.local, required this.data, required this.fireAuth, required this.cloudFn});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStorage>.value(value: local),
        Provider<DataService>.value(value: data),
        Provider<FirebaseAuthService>.value(value: fireAuth),
        Provider<CloudFunctionsService>.value(value: cloudFn),
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
    // Слушаем Firebase Auth — если пользователь уже залогинен, получаем его профиль
    widget.fireAuth.authStateChanges.listen((user) async {
      if (user != null) {
        // Пользователь залогинен в Firebase — получаем его роль из Firestore
        try {
          final profile = await widget.fireAuth.fetchProfile(user.uid);
          widget.local.setCurrentUser(profile);
        } catch (_) {
          // Firestore недоступен — используем базовый профиль
          widget.local.setCurrentUser({
            'uid': user.uid,
            'email': user.email ?? '',
            'displayName': user.displayName ?? user.email?.split('@').first ?? '',
            'role': 'owner',
          });
        }
        if (mounted) setState(() => _ready = true);
      } else {
        // Не залогинен — пробуем восстановить локальную сессию (офлайн-режим)
        final saved = widget.local.loadCurrentUser();
        if (saved != null) {
          widget.local.setCurrentUser(saved);
        }
        if (mounted) setState(() => _ready = true);
      }
    });

    // Таймаут: если Firebase не ответил за 3 секунды — используем локальную сессию
    Future.delayed(const Duration(seconds: 3), () {
      if (!_ready && mounted) {
        final saved = widget.local.loadCurrentUser();
        if (saved != null) widget.local.setCurrentUser(saved);
        setState(() => _ready = true);
      }
    });
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
