import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../cloud_interfaces.dart';
import '../cloud_config.dart';
import '../../../models/trip.dart';
import '../../../models/expense.dart';
import '../../../models/salary_rule.dart';

class YandexAuthService implements ICloudAuth {
  Map<String, dynamic>? _currentUser;
  final _authController = StreamController<Map<String, dynamic>?>.broadcast()..add(null);

  @override
  Map<String, dynamic>? get currentUser => _currentUser;

  @override
  Stream<Map<String, dynamic>?> get authStateChanges => _authController.stream;

  @override
  Future<Map<String, dynamic>?> register(String email, String password, String name) async {
    final resp = await http.post(
      Uri.parse('${CloudConfig.yandexFunctionUrl}?endpoint=register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'name': name}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      _currentUser = data['user'];
      _authController.add(_currentUser);
      return _currentUser;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final resp = await http.post(
      Uri.parse('${CloudConfig.yandexFunctionUrl}?endpoint=login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      _currentUser = data['user'];
      _authController.add(_currentUser);
      return _currentUser;
    }
    return null;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authController.add(null);
  }
}
