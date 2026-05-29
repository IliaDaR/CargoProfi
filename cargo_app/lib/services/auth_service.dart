import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';

/// Сервис аутентификации и управления профилем пользователя.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Регистрация пользователя с указанием роли.
  Future<UserProfile> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phone,
    String? ownerId,
    String? companyName,
    String? assignedVehicleId,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    final profile = UserProfile(
      uid: uid,
      role: role,
      displayName: displayName,
      email: email,
      phone: phone,
      ownerId: ownerId,
      assignedVehicleId: assignedVehicleId,
      companyName: companyName,
      driverIds: role == UserRole.owner ? [] : [],
    );

    if (role == UserRole.owner) {
      await _firestore.collection('owners').doc(uid).set({
        ...profile.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('drivers').doc(uid).set({
        ...profile.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Добавляем driverId владельцу
      if (ownerId != null) {
        await _firestore.collection('owners').doc(ownerId).update({
          'driverIds': FieldValue.arrayUnion([uid]),
        });
      }
    }

    return profile;
  }

  /// Вход по email/паролю.
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return fetchProfile(credential.user!.uid);
  }

  /// Выход.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Загружает профиль пользователя из Firestore.
  Future<UserProfile> fetchProfile(String uid) async {
    // Пробуем найти в owners
    final ownerDoc = await _firestore.collection('owners').doc(uid).get();
    if (ownerDoc.exists) {
      return UserProfile.fromMap(uid, ownerDoc.data()!);
    }

    // Пробуем найти в drivers
    final driverDoc = await _firestore.collection('drivers').doc(uid).get();
    if (driverDoc.exists) {
      return UserProfile.fromMap(uid, driverDoc.data()!);
    }

    throw Exception('Профиль не найден. Обратитесь к администратору.');
  }
}
