import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Сервис аутентификации через Firebase Auth.
/// Используется как основной метод входа.
/// LocalStorage остаётся как fallback при недоступности Firebase.
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Регистрация через Firebase Auth + создание профиля в Firestore.
  Future<Map<String, String>> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;

    final profile = {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (role == 'owner' || role == 'admin' || role == 'superadmin') {
      await _firestore.collection('owners').doc(uid).set(profile);
    } else {
      await _firestore.collection('drivers').doc(uid).set(profile);
    }

    return {'uid': uid, 'role': role, 'displayName': displayName, 'email': email};
  }

  /// Вход через Firebase Auth + загрузка профиля из Firestore.
  Future<Map<String, String>> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = _auth.currentUser!.uid;

    // Пробуем найти профиль в owners
    var doc = await _firestore.collection('owners').doc(uid).get();
    if (doc.exists) {
      final d = doc.data()!;
      return {
        'uid': uid, 'role': d['role'] ?? 'owner',
        'displayName': d['displayName'] ?? email.split('@').first,
        'email': email,
      };
    }

    // Пробуем найти в drivers
    doc = await _firestore.collection('drivers').doc(uid).get();
    if (doc.exists) {
      final d = doc.data()!;
      return {
        'uid': uid, 'role': d['role'] ?? 'driver',
        'displayName': d['displayName'] ?? email.split('@').first,
        'email': email,
      };
    }

    // Если профиля нет — создаём базовый
    return {
      'uid': uid, 'role': 'owner',
      'displayName': email.split('@').first, 'email': email,
    };
  }

  /// Загружает профиль пользователя из Firestore по uid.
  Future<Map<String, String>> fetchProfile(String uid) async {
    // Пробуем найти профиль в owners
    var doc = await _firestore.collection('owners').doc(uid).get();
    if (doc.exists) {
      final d = doc.data()!;
      return {
        'uid': uid, 'role': d['role'] ?? 'owner',
        'displayName': d['displayName'] ?? '',
        'email': d['email'] ?? '',
      };
    }
    // Пробуем найти в drivers
    doc = await _firestore.collection('drivers').doc(uid).get();
    if (doc.exists) {
      final d = doc.data()!;
      return {
        'uid': uid, 'role': d['role'] ?? 'driver',
        'displayName': d['displayName'] ?? '',
        'email': d['email'] ?? '',
      };
    }
    return {'uid': uid, 'role': 'owner', 'displayName': '', 'email': ''};
  }

  /// Выход из Firebase Auth.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
