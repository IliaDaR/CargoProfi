import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

/// Провайдер аутентификации. Управляет состоянием входа/регистрации,
/// хранит текущий профиль пользователя и его роль.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _profile != null;
  bool get isOwner => _profile?.role == UserRole.owner;
  bool get isDriver => _profile?.role == UserRole.driver;

  /// Инициализация: проверяет, есть ли активная сессия Firebase.
  Future<void> initialize() async {
    final user = _authService.currentUser;
    if (user != null) {
      _isLoading = true;
      notifyListeners();
      try {
        _profile = await _authService.fetchProfile(user.uid);
      } catch (e) {
        _error = e.toString();
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Регистрация.
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phone,
    String? ownerId,
    String? companyName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        phone: phone,
        ownerId: ownerId,
        companyName: companyName,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Вход.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _authService.login(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _formatError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Выход.
  Future<void> signOut() async {
    await _authService.signOut();
    _profile = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _formatError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) {
      return 'Этот email уже зарегистрирован';
    }
    if (msg.contains('invalid-email')) {
      return 'Неверный формат email';
    }
    if (msg.contains('weak-password')) {
      return 'Пароль слишком простой (минимум 6 символов)';
    }
    if (msg.contains('wrong-password') || msg.contains('user-not-found')) {
      return 'Неверный email или пароль';
    }
    return msg.replaceFirst('Exception: ', '');
  }
}
