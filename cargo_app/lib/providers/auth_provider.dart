import 'package:flutter/material.dart';
import '../services/local_storage.dart';

class AuthProvider extends ChangeNotifier {
  final LocalStorage _storage;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._storage);

  bool get isLoggedIn => _user != null;
  bool get isOwner => _user?['role'] == 'owner';
  String? get displayName => _user?['displayName'];
  String? get email => _user?['email'];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Map<String, dynamic>? get profile => _user;

  void checkSavedSession() {
    _user = _storage.loadCurrentUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true; _error = null; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    final u = _storage.findUser(email, password);
    if (u != null) {
      _user = u;
      _storage.setCurrentUser(u);
      _isLoading = false; notifyListeners();
      return true;
    }
    _error = 'Неверный email или пароль';
    _isLoading = false; notifyListeners();
    return false;
  }

  Future<bool> register(String email, String password, String name, String role) async {
    _isLoading = true; _error = null; notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    final u = _storage.registerUser(email, password, name, role);
    if (u != null) {
      _user = u;
      _storage.setCurrentUser(u);
      _isLoading = false; notifyListeners();
      return true;
    }
    _error = 'Пользователь с таким email уже существует';
    _isLoading = false; notifyListeners();
    return false;
  }

  void logout() {
    _storage.setCurrentUser(null);
    _user = null;
    notifyListeners();
  }

  void loginDemo() {
    _user = {'uid': 'admin', 'email': 'admin@numino.ru', 'displayName': 'Администратор', 'role': 'owner', 'phone': '+79183951315'};
    _storage.setCurrentUser(_user);
    notifyListeners();
  }

  void clearError() { _error = null; notifyListeners(); }
}
